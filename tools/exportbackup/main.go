// Command exportbackup, eski MySQL veritabanındaki kitaplığı mobil
// uygulamanın yedek biçimine (JSON) çevirir.
//
// Sunucu mimarisinden cihaz-içi mimariye geçerken bir kez çalıştırılır:
// oluşan dosya telefona kopyalanır ve uygulamadan "Profil > Yedekten geri
// yükle" ile içe alınır.
//
// Kullanım:
//
//	go run ./tools/exportbackup -out kutuphanem-yedek.json
//
// Bağlantı bilgileri ortam değişkenlerinden okunur (sunucunun kullandığı
// isimlerle aynı): DB_HOST, DB_PORT, DB_USER, DB_PASS, DB_NAME.
// Birden fazla kullanıcı varsa -user ile hangi hesabın aktarılacağı seçilir.
package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

const (
	appTag        = "Mobil Kütüphanem"
	formatVersion = 2
)

func main() {
	out := flag.String("out", "", "yazılacak JSON dosyası (varsayılan: kutuphanem-yedek-<tarih>.json)")
	userID := flag.Int("user", 0, "aktarılacak kullanıcı kimliği (0 = tek kullanıcıyı otomatik bul)")
	flag.Parse()

	db, err := connect()
	if err != nil {
		log.Fatalf("veritabanına bağlanılamadı: %v", err)
	}
	defer db.Close()

	uid, err := resolveUser(db, *userID)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("kullanıcı #%d aktarılıyor", uid)

	payload, err := buildBackup(db, uid)
	if err != nil {
		log.Fatalf("yedek hazırlanamadı: %v", err)
	}

	path := *out
	if path == "" {
		path = fmt.Sprintf("kutuphanem-yedek-%s.json", time.Now().Format("2006-01-02"))
	}
	data, err := json.MarshalIndent(payload, "", "  ")
	if err != nil {
		log.Fatalf("JSON üretilemedi: %v", err)
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		log.Fatalf("dosya yazılamadı: %v", err)
	}

	log.Printf("tamam: %s", path)
	log.Printf(
		"  %d kitap, %d günlük kaydı, %d raf, %d alıntı",
		len(payload.Books), len(payload.ReadingLogs),
		len(payload.Collections), len(payload.Quotes),
	)
	log.Print("dosyayı telefona kopyala, uygulamada Profil > Yedekten geri yükle ile aç")
}

func connect() (*sql.DB, error) {
	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s:%s)/%s?parseTime=true&charset=utf8mb4&loc=Local",
		getenv("DB_USER", "root"),
		getenv("DB_PASS", ""),
		getenv("DB_HOST", "127.0.0.1"),
		getenv("DB_PORT", "3306"),
		getenv("DB_NAME", "bookdb"),
	)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}
	return db, db.Ping()
}

// resolveUser: kimlik verilmediyse kitabı olan tek kullanıcıyı bulur.
func resolveUser(db *sql.DB, requested int) (int, error) {
	if requested > 0 {
		return requested, nil
	}
	rows, err := db.Query(`
		SELECT u.id, u.email, COUNT(b.id)
		FROM users u LEFT JOIN books b ON b.user_id = u.id
		GROUP BY u.id, u.email
		ORDER BY COUNT(b.id) DESC
	`)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	type candidate struct {
		id    int
		email string
		books int
	}
	var candidates []candidate
	for rows.Next() {
		var c candidate
		if err := rows.Scan(&c.id, &c.email, &c.books); err != nil {
			return 0, err
		}
		candidates = append(candidates, c)
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}

	withBooks := make([]candidate, 0, len(candidates))
	for _, c := range candidates {
		if c.books > 0 {
			withBooks = append(withBooks, c)
		}
	}
	switch len(withBooks) {
	case 0:
		return 0, fmt.Errorf("kitabı olan kullanıcı bulunamadı")
	case 1:
		return withBooks[0].id, nil
	default:
		fmt.Fprintln(os.Stderr, "birden fazla kullanıcı var, -user ile seç:")
		for _, c := range withBooks {
			fmt.Fprintf(os.Stderr, "  -user %d  (%s, %d kitap)\n", c.id, c.email, c.books)
		}
		return 0, fmt.Errorf("kullanıcı belirtilmedi")
	}
}

// ---------------------------------------------------------------------------
// Yedek biçimi — mobil uygulamanın BackupService'iyle birebir uyumlu.
// ---------------------------------------------------------------------------

type backup struct {
	App             string            `json:"app"`
	FormatVersion   int               `json:"format_version"`
	ExportedAt      string            `json:"exported_at"`
	Profile         profile           `json:"profile"`
	Books           []book            `json:"books"`
	ReadingLogs     []readingLog      `json:"reading_logs"`
	Collections     []collection      `json:"collections"`
	CollectionBooks []collectionBook  `json:"collection_books"`
	Quotes          []quote           `json:"quotes"`
	JournalPages    []struct{}        `json:"journal_pages"`
	Settings        map[string]string `json:"settings"`
}

type profile struct {
	DisplayName string `json:"display_name"`
}

type book struct {
	ID            int     `json:"id"`
	Title         string  `json:"title"`
	Author        *string `json:"author"`
	TotalPages    int     `json:"total_pages"`
	CoverURL      *string `json:"cover_url"`
	Category      *string `json:"category"`
	StartedAt     *string `json:"started_at"`
	FinishedAt    *string `json:"finished_at"`
	IsFinished    bool    `json:"is_finished"`
	ReadingStatus string  `json:"reading_status"`
	CurrentPage   int     `json:"current_page"`
	Notes         *string `json:"notes"`
	Favorite      bool    `json:"favorite"`
	Rating        *int    `json:"rating"`
	Tags          *string `json:"tags"`
	CreatedAt     string  `json:"created_at"`
}

type readingLog struct {
	ID              int     `json:"id"`
	BookID          int     `json:"book_id"`
	LogDate         string  `json:"log_date"`
	PagesRead       int     `json:"pages_read"`
	DurationMinutes int     `json:"duration_minutes"`
	Note            *string `json:"note"`
	Finished        bool    `json:"finished"`
	CreatedAt       string  `json:"created_at"`
	UpdatedAt       string  `json:"updated_at"`
}

type collection struct {
	ID        int    `json:"id"`
	Name      string `json:"name"`
	Color     string `json:"color"`
	CreatedAt string `json:"created_at"`
}

type collectionBook struct {
	CollectionID int    `json:"collection_id"`
	BookID       int    `json:"book_id"`
	DisplayMode  string `json:"display_mode"`
	Position     int    `json:"position"`
	AddedAt      string `json:"added_at"`
}

type quote struct {
	ID        int    `json:"id"`
	BookID    int    `json:"book_id"`
	Page      *int   `json:"page"`
	Text      string `json:"text"`
	Favorite  bool   `json:"favorite"`
	CreatedAt string `json:"created_at"`
}

func buildBackup(db *sql.DB, uid int) (*backup, error) {
	out := &backup{
		App:           appTag,
		FormatVersion: formatVersion,
		ExportedAt:    time.Now().Format(time.RFC3339),
		// Anı defteri sayfaları yalnızca telefonda tutuluyordu, sunucuda yok.
		JournalPages: []struct{}{},
		Settings:     map[string]string{},
	}

	var displayName sql.NullString
	if err := db.QueryRow(
		`SELECT display_name FROM users WHERE id = ?`, uid,
	).Scan(&displayName); err != nil && err != sql.ErrNoRows {
		return nil, err
	}
	out.Profile = profile{DisplayName: displayName.String}

	var err error
	if out.Books, err = loadBooks(db, uid); err != nil {
		return nil, fmt.Errorf("kitaplar: %w", err)
	}
	if out.ReadingLogs, err = loadLogs(db, uid); err != nil {
		return nil, fmt.Errorf("günlük: %w", err)
	}
	if out.Collections, out.CollectionBooks, err = loadCollections(db, uid); err != nil {
		return nil, fmt.Errorf("raflar: %w", err)
	}
	if out.Quotes, err = loadQuotes(db, uid); err != nil {
		return nil, fmt.Errorf("alıntılar: %w", err)
	}

	var dailyGoal int
	switch err := db.QueryRow(
		`SELECT daily_page_goal FROM reading_preferences WHERE user_id = ?`, uid,
	).Scan(&dailyGoal); {
	case err == nil:
		out.Settings["daily_page_goal"] = fmt.Sprint(dailyGoal)
	case err == sql.ErrNoRows:
		// hedef hiç belirlenmemiş; uygulama varsayılanı kullanır
	default:
		return nil, fmt.Errorf("hedef: %w", err)
	}

	return out, nil
}

func loadBooks(db *sql.DB, uid int) ([]book, error) {
	rows, err := db.Query(`
		SELECT id, title, author, total_pages, cover_url, category,
		       started_at, finished_at, is_finished, reading_status,
		       current_page, notes, favorite, rating, tags, created_at
		FROM books WHERE user_id = ? ORDER BY id ASC
	`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]book, 0)
	for rows.Next() {
		var (
			b                    book
			author, cover        sql.NullString
			category, notes      sql.NullString
			tags                 sql.NullString
			started, finished    sql.NullTime
			isFinished, favorite int
			rating               sql.NullInt64
			createdAt            time.Time
		)
		if err := rows.Scan(
			&b.ID, &b.Title, &author, &b.TotalPages, &cover, &category,
			&started, &finished, &isFinished, &b.ReadingStatus,
			&b.CurrentPage, &notes, &favorite, &rating, &tags, &createdAt,
		); err != nil {
			return nil, err
		}
		b.Author = nullString(author)
		b.CoverURL = nullString(cover)
		b.Category = nullString(category)
		b.Notes = nullString(notes)
		b.Tags = nullString(tags)
		b.StartedAt = nullDate(started)
		b.FinishedAt = nullDate(finished)
		b.IsFinished = isFinished == 1
		b.Favorite = favorite == 1
		if rating.Valid {
			v := int(rating.Int64)
			b.Rating = &v
		}
		b.CreatedAt = createdAt.Format(time.RFC3339)
		out = append(out, b)
	}
	return out, rows.Err()
}

func loadLogs(db *sql.DB, uid int) ([]readingLog, error) {
	rows, err := db.Query(`
		SELECT id, book_id, DATE_FORMAT(log_date, '%Y-%m-%d'), pages_read,
		       duration_minutes, note, finished, created_at, updated_at
		FROM reading_logs WHERE user_id = ? ORDER BY id ASC
	`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]readingLog, 0)
	for rows.Next() {
		var (
			l                    readingLog
			note                 sql.NullString
			finished             int
			createdAt, updatedAt time.Time
		)
		if err := rows.Scan(
			&l.ID, &l.BookID, &l.LogDate, &l.PagesRead,
			&l.DurationMinutes, &note, &finished, &createdAt, &updatedAt,
		); err != nil {
			return nil, err
		}
		l.Note = nullString(note)
		l.Finished = finished == 1
		l.CreatedAt = createdAt.Format(time.RFC3339)
		l.UpdatedAt = updatedAt.Format(time.RFC3339)
		out = append(out, l)
	}
	return out, rows.Err()
}

func loadCollections(db *sql.DB, uid int) ([]collection, []collectionBook, error) {
	rows, err := db.Query(`
		SELECT id, name, color, created_at
		FROM collections WHERE user_id = ? ORDER BY id ASC
	`, uid)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	shelves := make([]collection, 0)
	for rows.Next() {
		var (
			c         collection
			createdAt time.Time
		)
		if err := rows.Scan(&c.ID, &c.Name, &c.Color, &createdAt); err != nil {
			return nil, nil, err
		}
		c.CreatedAt = createdAt.Format(time.RFC3339)
		shelves = append(shelves, c)
	}
	if err := rows.Err(); err != nil {
		return nil, nil, err
	}

	linkRows, err := db.Query(`
		SELECT cb.collection_id, cb.book_id, cb.display_mode, cb.position, cb.added_at
		FROM collection_books cb
		JOIN collections c ON c.id = cb.collection_id
		WHERE c.user_id = ?
	`, uid)
	if err != nil {
		return nil, nil, err
	}
	defer linkRows.Close()

	links := make([]collectionBook, 0)
	for linkRows.Next() {
		var (
			l       collectionBook
			addedAt time.Time
		)
		if err := linkRows.Scan(
			&l.CollectionID, &l.BookID, &l.DisplayMode, &l.Position, &addedAt,
		); err != nil {
			return nil, nil, err
		}
		l.AddedAt = addedAt.Format(time.RFC3339)
		links = append(links, l)
	}
	return shelves, links, linkRows.Err()
}

func loadQuotes(db *sql.DB, uid int) ([]quote, error) {
	rows, err := db.Query(`
		SELECT id, book_id, page, text, favorite, created_at
		FROM quotes WHERE user_id = ? ORDER BY id ASC
	`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]quote, 0)
	for rows.Next() {
		var (
			q         quote
			page      sql.NullInt64
			favorite  int
			createdAt time.Time
		)
		if err := rows.Scan(
			&q.ID, &q.BookID, &page, &q.Text, &favorite, &createdAt,
		); err != nil {
			return nil, err
		}
		if page.Valid {
			v := int(page.Int64)
			q.Page = &v
		}
		q.Favorite = favorite == 1
		q.CreatedAt = createdAt.Format(time.RFC3339)
		out = append(out, q)
	}
	return out, rows.Err()
}

func nullString(v sql.NullString) *string {
	if !v.Valid || v.String == "" {
		return nil
	}
	s := v.String
	return &s
}

func nullDate(v sql.NullTime) *string {
	if !v.Valid {
		return nil
	}
	s := v.Time.Format("2006-01-02")
	return &s
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
