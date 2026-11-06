package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"book/internal/mw"
)

type Quote struct {
	ID        uint64  `json:"id"`
	BookID    uint64  `json:"book_id"`
	Page      *int    `json:"page,omitempty"`
	Text      string  `json:"text"`
	Favorite  bool    `json:"favorite"`
	CreatedAt string  `json:"created_at"`
	// Listeleme için kitap bilgisi (opsiyonel doldurulur)
	BookTitle  *string `json:"book_title,omitempty"`
	BookAuthor *string `json:"book_author,omitempty"`
	CoverURL   *string `json:"cover_url,omitempty"`
}

// QuotesList: GET /api/quotes?book_id=  (book_id verilmezse tüm alıntılar)
func QuotesList(db *sql.DB) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		var (
			rows *sql.Rows
			err  error
		)
		base := `
			SELECT q.id, q.book_id, q.page, q.text, q.favorite, q.created_at,
			       b.title, b.author, b.cover_url
			FROM quotes q
			JOIN books b ON b.id = q.book_id
			WHERE q.user_id = ?`
		if raw := strings.TrimSpace(r.URL.Query().Get("book_id")); raw != "" {
			bookID, convErr := strconv.ParseUint(raw, 10, 64)
			if convErr != nil {
				http.Error(w, "invalid book_id", http.StatusBadRequest)
				return
			}
			rows, err = db.Query(base+` AND q.book_id = ? ORDER BY q.id DESC`, uid, bookID)
		} else {
			rows, err = db.Query(base+` ORDER BY q.id DESC`, uid)
		}
		if err != nil {
			writeErr(w, err)
			return
		}
		defer rows.Close()

		out := make([]Quote, 0)
		for rows.Next() {
			var q Quote
			var page sql.NullInt64
			var fav int
			var author, cover sql.NullString
			var title string
			if err := rows.Scan(&q.ID, &q.BookID, &page, &q.Text, &fav, &q.CreatedAt,
				&title, &author, &cover); err != nil {
				writeErr(w, err)
				return
			}
			if page.Valid {
				p := int(page.Int64)
				q.Page = &p
			}
			q.Favorite = fav == 1
			q.BookTitle = &title
			if author.Valid {
				q.BookAuthor = &author.String
			}
			if cover.Valid {
				q.CoverURL = &cover.String
			}
			out = append(out, q)
		}
		writeJSON(w, http.StatusOK, out)
	})
}

// QuoteCreate: POST /api/quotes  { book_id, page?, text, favorite? }
func QuoteCreate(db *sql.DB) http.Handler {
	type req struct {
		BookID   uint64 `json:"book_id"`
		Page     *int   `json:"page"`
		Text     string `json:"text"`
		Favorite bool   `json:"favorite"`
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		var in req
		if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
			http.Error(w, "bad json", http.StatusBadRequest)
			return
		}
		in.Text = strings.TrimSpace(in.Text)
		if in.BookID == 0 || in.Text == "" {
			http.Error(w, "book_id and text required", http.StatusBadRequest)
			return
		}
		if len([]rune(in.Text)) > 2000 {
			http.Error(w, "text too long", http.StatusBadRequest)
			return
		}
		// kitap kullanıcıya mı ait?
		var owns int
		_ = db.QueryRow(`SELECT COUNT(1) FROM books WHERE id=? AND user_id=?`, in.BookID, uid).Scan(&owns)
		if owns == 0 {
			http.Error(w, "book not found", http.StatusNotFound)
			return
		}
		var page interface{}
		if in.Page != nil && *in.Page > 0 {
			page = *in.Page
		}
		fav := 0
		if in.Favorite {
			fav = 1
		}
		result, err := db.Exec(
			`INSERT INTO quotes (user_id, book_id, page, text, favorite) VALUES (?,?,?,?,?)`,
			uid, in.BookID, page, in.Text, fav,
		)
		if err != nil {
			writeErr(w, err)
			return
		}
		id, _ := result.LastInsertId()
		writeJSON(w, http.StatusCreated, map[string]any{"id": id})
	})
}

// QuoteDelete: DELETE /api/quotes/{id}
func QuoteDelete(db *sql.DB) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		raw := strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/quotes/"), "/")
		id, err := strconv.ParseUint(raw, 10, 64)
		if err != nil || id == 0 {
			http.Error(w, "invalid quote id", http.StatusBadRequest)
			return
		}
		if _, err := db.Exec(`DELETE FROM quotes WHERE id=? AND user_id=?`, id, uid); err != nil {
			writeErr(w, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
	})
}
