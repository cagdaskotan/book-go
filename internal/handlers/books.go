// internal/handlers/books.go
package handlers

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"book/internal/mw"
)

type Book struct {
	ID         uint      `json:"id"`
	UserID     uint      `json:"user_id"`
	Title      string    `json:"title"`
	Author     *string   `json:"author,omitempty"`
	TotalPages uint      `json:"total_pages"`
	CoverURL   *string   `json:"cover_url,omitempty"`
	Category   *string   `json:"category,omitempty"`
	CreatedAt  time.Time `json:"created_at"`

	// Zengin alanlar
	StartedAt     *string `json:"started_at,omitempty"`  // "YYYY-MM-DD"
	FinishedAt    *string `json:"finished_at,omitempty"` // "YYYY-MM-DD"
	IsFinished    bool    `json:"is_finished"`
	ReadingStatus string  `json:"reading_status"`
	CurrentPage   uint    `json:"current_page"`
	Notes         *string `json:"notes,omitempty"`
	Favorite      bool    `json:"favorite"`
	Rating        *uint8  `json:"rating"`
	Tags          *string `json:"tags,omitempty"`
}

type optionalInt struct {
	Present bool
	Value   *int
}

func (o *optionalInt) UnmarshalJSON(data []byte) error {
	o.Present = true
	data = bytes.TrimSpace(data)
	if len(data) == 0 || bytes.Equal(data, []byte("null")) {
		o.Value = nil
		return nil
	}
	var v int
	if err := json.Unmarshal(data, &v); err != nil {
		return err
	}
	o.Value = &v
	return nil
}

func BooksList(db *sql.DB) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		rows, err := db.Query(`
			SELECT
			  id, user_id, title, author, total_pages, cover_url, category, created_at,
			  started_at, finished_at, is_finished, reading_status, current_page, notes, favorite, rating, tags
			FROM books
			WHERE user_id=?
			ORDER BY id DESC
		`, uid)
		if err != nil {
			writeErr(w, err)
			return
		}
		defer rows.Close()

		out := make([]Book, 0)
		for rows.Next() {
			var b Book
			var tp, cp int64
			var isfInt, favInt int
			var startNT, finishNT sql.NullTime
			var rating sql.NullInt64
			if err := rows.Scan(
				&b.ID, &b.UserID, &b.Title, &b.Author, &tp, &b.CoverURL, &b.Category, &b.CreatedAt,
				&startNT, &finishNT, &isfInt, &b.ReadingStatus, &cp, &b.Notes, &favInt, &rating, &b.Tags,
			); err != nil {
				writeErr(w, err)
				return
			}
			b.TotalPages = uint(tp)
			b.CurrentPage = uint(cp)
			b.IsFinished = isfInt == 1
			b.Favorite = favInt == 1
			b.Rating = nullIntToUint8(rating)
			b.StartedAt = nt2date(startNT)
			b.FinishedAt = nt2date(finishNT)
			out = append(out, b)
		}
		if err := rows.Err(); err != nil {
			writeErr(w, err)
			return
		}
		writeJSON(w, http.StatusOK, out)
	})
}

// GET /api/books/{id}
// GET /api/books/{id}
func BookGet(db *sql.DB) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		id, err := pathID(r.URL.Path, "/api/books/")
		if err != nil || id <= 0 {
			http.Error(w, "invalid id", http.StatusBadRequest)
			return
		}

		var b Book
		var started, finished sql.NullTime
		var author, cover, cat, notes, tags sql.NullString
		var favInt, isfInt int
		var current, total uint
		var rating sql.NullInt64

		row := db.QueryRow(`
			SELECT id, user_id, title, author, total_pages, cover_url, category,
			       started_at, finished_at, is_finished, reading_status, current_page, notes, favorite, rating, tags, created_at
			FROM books
			WHERE id=? AND user_id=?
		`, id, uid)

		if err := row.Scan(
			&b.ID, &b.UserID, &b.Title, &author, &total, &cover, &cat,
			&started, &finished, &isfInt, &b.ReadingStatus, &current, &notes, &favInt, &rating, &tags, &b.CreatedAt,
		); err != nil {
			if errors.Is(err, sql.ErrNoRows) {
				http.NotFound(w, r)
				return
			}
			writeErr(w, err)
			return
		}

		b.TotalPages = total
		b.CurrentPage = current
		b.IsFinished = isfInt == 1
		b.Favorite = favInt == 1
		b.Rating = nullIntToUint8(rating)
		if author.Valid {
			s := author.String
			b.Author = &s
		}
		if cover.Valid {
			s := cover.String
			b.CoverURL = &s
		}
		if cat.Valid {
			s := cat.String
			b.Category = &s
		}

		type out struct {
			Book
			StartedAt   *string `json:"started_at,omitempty"`
			FinishedAt  *string `json:"finished_at,omitempty"`
			IsFinished  bool    `json:"is_finished"`
			CurrentPage uint    `json:"current_page"`
			Notes       *string `json:"notes,omitempty"`
			Favorite    bool    `json:"favorite"`
			Tags        *string `json:"tags,omitempty"`
		}

		var startedStr, finishedStr *string
		if started.Valid {
			s := started.Time.Format("2006-01-02")
			startedStr = &s
		}
		if finished.Valid {
			s := finished.Time.Format("2006-01-02")
			finishedStr = &s
		}

		var notesStr, tagsStr *string
		if notes.Valid {
			s := notes.String
			notesStr = &s
		}
		if tags.Valid {
			s := tags.String
			tagsStr = &s
		}

		resp := out{
			Book:        b,
			StartedAt:   startedStr,
			FinishedAt:  finishedStr,
			IsFinished:  b.IsFinished,
			CurrentPage: b.CurrentPage,
			Notes:       notesStr,
			Favorite:    b.Favorite,
			Tags:        tagsStr,
		}
		writeJSON(w, http.StatusOK, resp)
	})
}

// BookCreate: POST /api/books
func BookCreate(db *sql.DB) http.Handler {
	type req struct {
		Title         string  `json:"title"`
		Author        *string `json:"author"`
		TotalPages    uint    `json:"total_pages"`
		CoverURL      *string `json:"cover_url"`
		Category      *string `json:"category"`
		StartedAt     *string `json:"started_at"`   // YYYY-MM-DD
		FinishedAt    *string `json:"finished_at"`  // YYYY-MM-DD
		IsFinished    *bool   `json:"is_finished"`  // opsiyonel
		CurrentPage   *uint   `json:"current_page"` // opsiyonel
		ReadingStatus *string `json:"reading_status"`
		Notes         *string `json:"notes"`
		Favorite      *bool   `json:"favorite"`
		Tags          *string `json:"tags"`
		Rating        *int    `json:"rating"`
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
		in.Title = strings.TrimSpace(in.Title)
		if in.Title == "" {
			http.Error(w, "title required", http.StatusBadRequest)
			return
		}
		if in.TotalPages == 0 {
			http.Error(w, "total_pages must be > 0", http.StatusBadRequest)
			return
		}

		// varsayÄ±lanlar
		isFinished := false
		if in.IsFinished != nil {
			isFinished = *in.IsFinished
		}
		currentPage := uint(0)
		if in.CurrentPage != nil {
			currentPage = *in.CurrentPage
		}
		readingStatus := normalizeReadingStatus(in.ReadingStatus, isFinished, currentPage)
		favorite := false
		if in.Favorite != nil {
			favorite = *in.Favorite
		}

		var ratingPtr *uint8
		if in.Rating != nil {
			v := *in.Rating
			if v < 0 || v > 100 {
				http.Error(w, "rating must be between 0 and 100", http.StatusBadRequest)
				return
			}
			vr := uint8(v)
			ratingPtr = &vr
		}

		// tarihleri parse et
		startTime, err := parseDate(in.StartedAt)
		if err != nil {
			http.Error(w, "invalid started_at (YYYY-MM-DD)", http.StatusBadRequest)
			return
		}
		finishTime, err := parseDate(in.FinishedAt)
		if err != nil {
			http.Error(w, "invalid finished_at (YYYY-MM-DD)", http.StatusBadRequest)
			return
		}

		// --- Bitirme kurallarÄ± ---
		if isFinished {
			// finished_at yoksa bugÃ¼n
			if finishTime == nil {
				today := time.Now().Truncate(24 * time.Hour)
				finishTime = &today
			}
			// bitmiÅŸ kitapta current_page = total_pages
			currentPage = in.TotalPages
		}

		// tarih iliÅŸki kuralÄ±
		if startTime != nil && finishTime != nil && finishTime.Before(*startTime) {
			http.Error(w, "finished_at must be >= started_at", http.StatusBadRequest)
			return
		}

		// bitmemiÅŸte "current_page <= total" kontrolÃ¼
		if !isFinished && currentPage > in.TotalPages {
			http.Error(w, "current_page cannot exceed total_pages", http.StatusBadRequest)
			return
		}

		if ratingPtr != nil && !isFinished {
			http.Error(w, "rating allowed only when book is finished", http.StatusBadRequest)
			return
		}

		res, err := db.Exec(`
			INSERT INTO books (
				user_id, title, author, total_pages, cover_url, category,
				started_at, finished_at, is_finished, reading_status, current_page, notes, favorite, rating, tags
			) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
		`,
			uid, in.Title, in.Author, in.TotalPages, in.CoverURL, in.Category,
			startTime, finishTime, b2i(isFinished), readingStatus, currentPage, in.Notes, b2i(favorite), ratingPtr, in.Tags,
		)
		if err != nil {
			writeErr(w, err)
			return
		}
		id, _ := res.LastInsertId()
		writeJSON(w, http.StatusCreated, map[string]any{"id": id})
	})
}

// BookUpdate: PUT /api/books/{id}
func BookUpdate(db *sql.DB) http.Handler {
	type req struct {
		Title         *string     `json:"title"`
		Author        *string     `json:"author"`
		TotalPages    *uint       `json:"total_pages"`
		CoverURL      *string     `json:"cover_url"`
		Category      *string     `json:"category"`
		StartedAt     *string     `json:"started_at"`  // YYYY-MM-DD
		FinishedAt    *string     `json:"finished_at"` // YYYY-MM-DD
		IsFinished    *bool       `json:"is_finished"`
		CurrentPage   *uint       `json:"current_page"`
		ReadingStatus *string     `json:"reading_status"`
		Notes         *string     `json:"notes"`
		Favorite      *bool       `json:"favorite"`
		Tags          *string     `json:"tags"`
		Rating        optionalInt `json:"rating"`
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		id, err := pathID(r.URL.Path, "/api/books/")
		if err != nil || id <= 0 {
			http.Error(w, "invalid id", http.StatusBadRequest)
			return
		}

		// mevcut kaydÄ± al
		var cur struct {
			Title         string
			Author        *string
			TotalPages    uint
			CoverURL      *string
			Category      *string
			StartedAt     sql.NullTime
			FinishedAt    sql.NullTime
			IsFinished    bool
			CurrentPage   uint
			ReadingStatus string
			Notes         *string
			Favorite      bool
			Rating        sql.NullInt64
			Tags          *string
		}
		err = db.QueryRow(`
			SELECT title, author, total_pages, cover_url, category,
			       started_at, finished_at, is_finished, reading_status, current_page, notes, favorite, rating, tags
			FROM books WHERE id=? AND user_id=?
		`, id, uid).Scan(
			&cur.Title, &cur.Author, &cur.TotalPages, &cur.CoverURL, &cur.Category,
			&cur.StartedAt, &cur.FinishedAt, &cur.IsFinished, &cur.ReadingStatus, &cur.CurrentPage, &cur.Notes, &cur.Favorite, &cur.Rating, &cur.Tags,
		)
		if errors.Is(err, sql.ErrNoRows) {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		if err != nil {
			writeErr(w, err)
			return
		}

		var in req
		if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
			http.Error(w, "bad json", http.StatusBadRequest)
			return
		}

		// --- Merge alanlar ---
		rating := nullIntToUint8(cur.Rating)
		title := cur.Title
		if in.Title != nil {
			title = strings.TrimSpace(*in.Title)
		}
		author := cur.Author
		if in.Author != nil {
			author = ptrOrNil(strings.TrimSpace(*in.Author))
		}
		totalPages := cur.TotalPages
		if in.TotalPages != nil {
			totalPages = *in.TotalPages
		}
		cover := cur.CoverURL
		if in.CoverURL != nil {
			cover = ptrOrNil(strings.TrimSpace(*in.CoverURL))
		}
		category := cur.Category
		if in.Category != nil {
			category = ptrOrNil(strings.TrimSpace(*in.Category))
		}
		notes := cur.Notes
		if in.Notes != nil {
			notes = ptrOrNil(strings.TrimSpace(*in.Notes))
		}
		tags := cur.Tags
		if in.Tags != nil {
			tags = ptrOrNil(strings.TrimSpace(*in.Tags))
		}

		isFinished := cur.IsFinished
		if in.IsFinished != nil {
			isFinished = *in.IsFinished
		}
		favorite := cur.Favorite
		if in.Favorite != nil {
			favorite = *in.Favorite
		}
		if in.Rating.Present {
			if in.Rating.Value == nil {
				rating = nil
			} else {
				v := *in.Rating.Value
				if v < 0 || v > 100 {
					http.Error(w, "rating must be between 0 and 100", http.StatusBadRequest)
					return
				}
				vr := uint8(v)
				rating = &vr
			}
		}
		currentPage := cur.CurrentPage
		if in.CurrentPage != nil {
			currentPage = *in.CurrentPage
		}
		readingStatus := cur.ReadingStatus
		if in.ReadingStatus != nil {
			readingStatus = normalizeReadingStatus(in.ReadingStatus, isFinished, currentPage)
		}

		// Tarihler: mevcut + istek
		startTime := nullTimeToPtr(cur.StartedAt)
		if in.StartedAt != nil {
			t, err := parseDate(in.StartedAt)
			if err != nil {
				http.Error(w, "invalid started_at (YYYY-MM-DD)", http.StatusBadRequest)
				return
			}
			startTime = t
		}
		finishTime := nullTimeToPtr(cur.FinishedAt)
		if in.FinishedAt != nil {
			t, err := parseDate(in.FinishedAt)
			if err != nil {
				http.Error(w, "invalid finished_at (YYYY-MM-DD)", http.StatusBadRequest)
				return
			}
			finishTime = t
		}

		// --- Bitirme kuralları ---
		if isFinished {
			// finished_at yoksa bugün
			if finishTime == nil {
				t := time.Now().Truncate(24 * time.Hour)
				finishTime = &t
			}
			// bitmiş kitapta current_page = total_pages
			currentPage = totalPages
			readingStatus = "finished"
		} else {
			// bitmemişte current > total olamaz
			if currentPage > totalPages {
				http.Error(w, "current_page cannot exceed total_pages", http.StatusBadRequest)
				return
			}
			if in.Rating.Present && in.Rating.Value != nil {
				http.Error(w, "rating allowed only when book is finished", http.StatusBadRequest)
				return
			}
			rating = nil
			if readingStatus == "finished" {
				readingStatus = normalizeReadingStatus(nil, false, currentPage)
			}
		}

		// --- DoÄŸrulamalar ---
		if strings.TrimSpace(title) == "" {
			http.Error(w, "title required", http.StatusBadRequest)
			return
		}
		if totalPages == 0 {
			http.Error(w, "total_pages must be > 0", http.StatusBadRequest)
			return
		}
		if startTime != nil && finishTime != nil && finishTime.Before(*startTime) {
			http.Error(w, "finished_at must be >= started_at", http.StatusBadRequest)
			return
		}

		_, err = db.Exec(`
			UPDATE books SET
				title=?, author=?, total_pages=?, cover_url=?, category=?,
				started_at=?, finished_at=?, is_finished=?, reading_status=?, current_page=?, notes=?, favorite=?, rating=?, tags=?
			WHERE id=? AND user_id=?
		`,
			title, author, totalPages, cover, category,
			startTime, finishTime, b2i(isFinished), readingStatus, currentPage, notes, b2i(favorite), rating, tags,
			id, uid,
		)
		if err != nil {
			writeErr(w, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
	})
}

func BookDelete(db *sql.DB) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		id, err := pathID(r.URL.Path, "/api/books/")
		if err != nil || id <= 0 {
			http.Error(w, "invalid id", http.StatusBadRequest)
			return
		}
		if _, err := db.Exec(`DELETE FROM books WHERE id=? AND user_id=?`, id, uid); err != nil {
			writeErr(w, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
	})
}

// --- helpers ---

func nt2date(nt sql.NullTime) *string {
	if !nt.Valid {
		return nil
	}
	s := nt.Time.Format("2006-01-02")
	return &s
}
func parseDate(s *string) (*time.Time, error) {
	if s == nil {
		return nil, nil
	}
	st := strings.TrimSpace(*s)
	if st == "" {
		return nil, nil
	}
	t, err := time.Parse("2006-01-02", st)
	if err != nil {
		return nil, err
	}
	tt := t // kopya
	return &tt, nil
}
func nullIntToUint8(ni sql.NullInt64) *uint8 {
	if !ni.Valid {
		return nil
	}
	if ni.Int64 < 0 {
		return nil
	}
	u := uint8(ni.Int64)
	return &u
}
func nullTimeToPtr(nt sql.NullTime) *time.Time {
	if !nt.Valid {
		return nil
	}
	t := nt.Time
	return &t
}
func ptrOrNil(s string) *string {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return &s
}
func b2i(b bool) int {
	if b {
		return 1
	}
	return 0
}

func normalizeReadingStatus(raw *string, finished bool, currentPage uint) string {
	if finished {
		return "finished"
	}
	if raw != nil {
		switch strings.TrimSpace(*raw) {
		case "want_to_read", "reading", "paused":
			return strings.TrimSpace(*raw)
		}
	}
	if currentPage > 0 {
		return "reading"
	}
	return "want_to_read"
}
func pathID(path, prefix string) (int, error) {
	if !strings.HasPrefix(path, prefix) {
		return 0, errors.New("prefix mismatch")
	}
	s := strings.Trim(strings.TrimPrefix(path, prefix), "/")
	return strconv.Atoi(s)
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
func writeErr(w http.ResponseWriter, err error) {
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
}
