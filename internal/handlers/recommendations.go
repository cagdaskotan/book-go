package handlers

import (
	"database/sql"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"

	"book/internal/mw"
)

// Recommendation: kullanıcıya gerekçesiyle sunulan öneri.
type Recommendation struct {
	Title      string  `json:"title"`
	Author     *string `json:"author,omitempty"`
	CoverURL   *string `json:"cover_url,omitempty"`
	TotalPages int     `json:"total_pages"`
	Reason     string  `json:"reason"`
}

type recProfileBook struct {
	title    string
	author   string
	category string
	rating   *int
	finished bool
}

// ---- Basit, kullanıcı-bazlı önbellek (ücretsiz API'leri yormamak için) ----
type cachedRecs struct {
	recs []Recommendation
	at   time.Time
}

var (
	recMu    sync.Mutex
	recStore = map[uint]cachedRecs{}
)

const recTTL = 12 * time.Hour

// Türkçe kategori -> Open Library/Google Books konu eşlemesi.
var subjectMap = map[string]string{
	"Roman":           "fiction",
	"Öykü":            "short stories",
	"Şiir":            "poetry",
	"Polisiye":        "mystery",
	"Bilim Kurgu":     "science fiction",
	"Fantastik":       "fantasy",
	"Tarih":           "history",
	"Felsefe":         "philosophy",
	"Psikoloji":       "psychology",
	"Bilim":           "science",
	"Kişisel Gelişim": "self-help",
	"Biyografi":       "biography",
	"Çocuk":           "juvenile fiction",
	"Çizgi Roman":     "comics",
	"Deneme":          "essays",
}

func Recommendations(db *sql.DB) http.Handler {
	client := &http.Client{Timeout: 10 * time.Second}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		refresh := r.URL.Query().Get("refresh") == "1"
		if !refresh {
			if c, ok := recCacheGet(uid); ok {
				writeJSON(w, http.StatusOK, c)
				return
			}
		}

		books, err := loadProfileBooks(db, uid)
		if err != nil {
			writeErr(w, err)
			return
		}

		recs := buildRecommendations(client, books)
		recCacheSet(uid, recs)
		writeJSON(w, http.StatusOK, recs)
	})
}

func loadProfileBooks(db *sql.DB, uid uint) ([]recProfileBook, error) {
	rows, err := db.Query(
		`SELECT title, author, category, rating, is_finished FROM books WHERE user_id=?`,
		uid,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]recProfileBook, 0)
	for rows.Next() {
		var title string
		var author, category sql.NullString
		var rating sql.NullInt64
		var finished bool
		if err := rows.Scan(&title, &author, &category, &rating, &finished); err != nil {
			return nil, err
		}
		b := recProfileBook{title: title, finished: finished}
		if author.Valid {
			b.author = strings.TrimSpace(author.String)
		}
		if category.Valid {
			b.category = strings.TrimSpace(category.String)
		}
		if rating.Valid {
			rv := int(rating.Int64)
			b.rating = &rv
		}
		out = append(out, b)
	}
	return out, nil
}

func buildRecommendations(client *http.Client, books []recProfileBook) []Recommendation {
	owned := map[string]bool{}
	authorW := map[string]float64{}
	catW := map[string]float64{}

	for _, b := range books {
		owned[normTitle(b.title)] = true
		// ağırlık: bitenler ve yüksek puanlılar daha çok sayar
		weight := 1.0
		if b.finished {
			weight = 2.5
		}
		if b.rating != nil {
			weight = float64(*b.rating) / 20.0 // 0..5
			if *b.rating >= 80 {
				weight += 2.5
			}
		}
		if b.author != "" {
			authorW[b.author] += weight
		}
		if b.category != "" {
			catW[b.category] += weight
		}
	}

	topAuthors := topKeys(authorW, 4)
	topCats := topKeys(catW, 2)

	recs := make([]Recommendation, 0, 24)
	seen := map[string]bool{}

	add := func(books []CatalogBook, reason string, limit int) {
		count := 0
		for _, b := range books {
			key := normTitle(b.Title)
			if key == "" || owned[key] || seen[key] {
				continue
			}
			seen[key] = true
			recs = append(recs, Recommendation{
				Title:      b.Title,
				Author:     b.Author,
				CoverURL:   b.CoverURL,
				TotalPages: b.TotalPages,
				Reason:     reason,
			})
			count++
			if count >= limit {
				break
			}
		}
	}

	// 1) Sevilen yazarlardan yeni kitaplar ("X okuduğun için")
	for _, a := range topAuthors {
		add(fetchByAuthor(client, a), a+" okuduğun için", 4)
	}

	// 2) Sevilen türlerden popüler kitaplar ("Y sevdiğin için")
	for _, c := range topCats {
		subject, ok := subjectMap[c]
		if !ok {
			continue
		}
		add(fetchBySubject(client, subject), c+" sevdiğin için", 4)
	}

	if len(recs) > 24 {
		recs = recs[:24]
	}
	return recs
}

func fetchByAuthor(client *http.Client, author string) []CatalogBook {
	res := searchGoogleBooks(client, `inauthor:"`+author+`"`)
	if len(res) == 0 {
		res = searchOpenLibrary(client, author)
	}
	return res
}

func fetchBySubject(client *http.Client, subject string) []CatalogBook {
	res := searchGoogleBooks(client, `subject:"`+subject+`"`)
	if len(res) == 0 {
		res = searchOpenLibrary(client, subject)
	}
	return res
}

func topKeys(m map[string]float64, n int) []string {
	type kv struct {
		k string
		v float64
	}
	arr := make([]kv, 0, len(m))
	for k, v := range m {
		arr = append(arr, kv{k, v})
	}
	sort.Slice(arr, func(i, j int) bool { return arr[i].v > arr[j].v })
	out := make([]string, 0, n)
	for i := 0; i < len(arr) && i < n; i++ {
		out = append(out, arr[i].k)
	}
	return out
}

func normTitle(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	return strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			return r
		}
		return -1
	}, s)
}

func recCacheGet(uid uint) ([]Recommendation, bool) {
	recMu.Lock()
	defer recMu.Unlock()
	c, ok := recStore[uid]
	if !ok || time.Since(c.at) > recTTL {
		return nil, false
	}
	return c.recs, true
}

func recCacheSet(uid uint, recs []Recommendation) {
	recMu.Lock()
	defer recMu.Unlock()
	recStore[uid] = cachedRecs{recs: recs, at: time.Now()}
}
