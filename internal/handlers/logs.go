// internal/handlers/logs.go

package handlers

import (
	"database/sql"

	"encoding/json"

	"errors"

	"net/http"

	"strconv"

	"strings"

	"time"

	"book/internal/mw"
)

// Request/Response modelleri

type ReadingLog struct {
	ID uint `json:"id"`

	UserID uint `json:"user_id"`

	BookID uint `json:"book_id"`

	LogDate string `json:"log_date"` // YYYY-MM-DD

	PagesRead       uint `json:"pages_read"` // may be 0 when only note is recorded
	DurationMinutes uint `json:"duration_minutes"`

	Note *string `json:"note,omitempty"`

	Finished bool `json:"finished"`

	CreatedAt time.Time `json:"created_at"`

	UpdatedAt time.Time `json:"updated_at"`
}

// GET /api/logs?book_id=123&from=YYYY-MM-DD&to=YYYY-MM-DD

func LogsList(db *sql.DB) http.Handler {

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		uid, ok := mw.GetUserID(r)

		if !ok {

			http.Error(w, "unauthorized", http.StatusUnauthorized)

			return

		}

		q := r.URL.Query()

		bookID, _ := strconv.Atoi(q.Get("book_id"))

		if bookID <= 0 {

			http.Error(w, "book_id required", http.StatusBadRequest)

			return

		}

		from := strings.TrimSpace(q.Get("from"))

		to := strings.TrimSpace(q.Get("to"))

		args := []any{uid, bookID}

		where := "WHERE user_id=? AND book_id=?"

		if from != "" {

			where += " AND log_date>=?"

			args = append(args, from)

		}

		if to != "" {

			where += " AND log_date<=?"

			args = append(args, to)

		}

		rows, err := db.Query(`



			SELECT id, user_id, book_id, DATE_FORMAT(log_date,'%Y-%m-%d'),



			       pages_read, duration_minutes, note, finished, created_at, updated_at



			FROM reading_logs



			`+where+`



			ORDER BY log_date DESC, id DESC



		`, args...)

		if err != nil {

			writeErr(w, err)

			return

		}

		defer rows.Close()

		var out []ReadingLog

		for rows.Next() {

			var rl ReadingLog

			var note sql.NullString

			var finInt int

			if err := rows.Scan(&rl.ID, &rl.UserID, &rl.BookID, &rl.LogDate, &rl.PagesRead, &rl.DurationMinutes, &note, &finInt, &rl.CreatedAt, &rl.UpdatedAt); err != nil {

				writeErr(w, err)

				return

			}

			if note.Valid {

				s := note.String

				rl.Note = &s

			}

			rl.Finished = finInt == 1

			out = append(out, rl)

		}

		if err := rows.Err(); err != nil {

			writeErr(w, err)

			return

		}

		writeJSON(w, http.StatusOK, out)

	})

}

// POST /api/logs

// Body: {book_id, log_date(YYYY-MM-DD), pages_read?, note?, finished?}

func LogCreate(db *sql.DB) http.Handler {

	type req struct {
		BookID int `json:"book_id"`

		LogDate string `json:"log_date"`

		PagesRead       *uint `json:"pages_read"`
		DurationMinutes *uint `json:"duration_minutes"`

		Note *string `json:"note"`

		Finished *bool `json:"finished"`
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

		if in.BookID <= 0 || strings.TrimSpace(in.LogDate) == "" {

			http.Error(w, "book_id and log_date required", http.StatusBadRequest)

			return

		}

		ld, err := time.Parse("2006-01-02", in.LogDate)

		if err != nil {

			http.Error(w, "invalid log_date (YYYY-MM-DD)", http.StatusBadRequest)

			return

		}

		logDate := ld.Format("2006-01-02")

		var pages uint

		if in.PagesRead != nil && *in.PagesRead > 0 {

			pages = *in.PagesRead

		}
		var duration uint
		if in.DurationMinutes != nil {
			duration = *in.DurationMinutes
		}

		var notePtr *string

		if in.Note != nil {

			notePtr = ptrOrNil(strings.TrimSpace(*in.Note))

		}

		if pages == 0 && notePtr == nil && duration == 0 {

			http.Error(w, "pages_read, duration_minutes or note required", http.StatusBadRequest)

			return

		}

		finished := false

		if in.Finished != nil {

			finished = *in.Finished

		}

		if finished && pages == 0 {

			http.Error(w, "finished logs must include pages_read", http.StatusBadRequest)

			return

		}

		// kitap kullanıcıya mı ait?

		var cnt int

		if err := db.QueryRow(`SELECT COUNT(1) FROM books WHERE id=? AND user_id=?`, in.BookID, uid).Scan(&cnt); err != nil || cnt == 0 {

			http.Error(w, "book not found", http.StatusNotFound)

			return

		}

		res, err := db.Exec(`



			INSERT INTO reading_logs (user_id, book_id, log_date, pages_read, duration_minutes, note, finished)



			VALUES (?,?,?,?,?,?,?)



		`, uid, in.BookID, logDate, pages, duration, notePtr, b2i(finished))

		if err != nil {

			writeErr(w, err)

			return

		}

		id, _ := res.LastInsertId()

		// Progress & bitiş güncelle

		if err := recomputeProgress(db, uint(uid), uint(in.BookID)); err != nil {

			writeErr(w, err)

			return

		}

		writeJSON(w, http.StatusCreated, map[string]any{"id": id})

	})

}

// PUT /api/logs/{id}

// Body: {log_date?, pages_read?, note?, finished?}

func LogUpdate(db *sql.DB) http.Handler {

	type req struct {
		LogDate *string `json:"log_date"`

		PagesRead       *uint `json:"pages_read"`
		DurationMinutes *uint `json:"duration_minutes"`

		Note *string `json:"note"`

		Finished *bool `json:"finished"`
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		uid, ok := mw.GetUserID(r)

		if !ok {

			http.Error(w, "unauthorized", http.StatusUnauthorized)

			return

		}

		id, err := pathID(r.URL.Path, "/api/logs/")

		if err != nil || id <= 0 {

			http.Error(w, "invalid id", http.StatusBadRequest)

			return

		}

		// mevcut kayıt

		var cur struct {
			UserID uint

			BookID uint

			LogDate string

			PagesRead       uint
			DurationMinutes uint

			Note *string

			Finished bool
		}

		var note sql.NullString

		var finInt int

		err = db.QueryRow(`



			SELECT user_id, book_id, DATE_FORMAT(log_date,'%Y-%m-%d'), pages_read, duration_minutes, note, finished



			FROM reading_logs WHERE id=?



		`, id).Scan(&cur.UserID, &cur.BookID, &cur.LogDate, &cur.PagesRead, &cur.DurationMinutes, &note, &finInt)

		if errors.Is(err, sql.ErrNoRows) {

			http.Error(w, "not found", http.StatusNotFound)

			return

		}

		if err != nil {

			writeErr(w, err)

			return

		}

		if cur.UserID != uint(uid) {

			http.Error(w, "forbidden", http.StatusForbidden)

			return

		}

		if note.Valid {

			s := note.String

			cur.Note = &s

		}

		cur.Finished = finInt == 1

		var in req

		if err := json.NewDecoder(r.Body).Decode(&in); err != nil {

			http.Error(w, "bad json", http.StatusBadRequest)

			return

		}

		logDate := cur.LogDate

		if in.LogDate != nil {

			ld, err := time.Parse("2006-01-02", strings.TrimSpace(*in.LogDate))

			if err != nil {

				http.Error(w, "invalid log_date (YYYY-MM-DD)", http.StatusBadRequest)

				return

			}

			logDate = ld.Format("2006-01-02")

		}

		pages := cur.PagesRead

		if in.PagesRead != nil {

			if *in.PagesRead > 0 {

				pages = *in.PagesRead

			} else {

				pages = 0

			}

		}
		duration := cur.DurationMinutes
		if in.DurationMinutes != nil {
			duration = *in.DurationMinutes
		}

		noteOut := cur.Note

		if in.Note != nil {

			noteOut = ptrOrNil(strings.TrimSpace(*in.Note))

		}

		if pages == 0 && duration == 0 && (noteOut == nil || strings.TrimSpace(*noteOut) == "") {

			http.Error(w, "pages_read, duration_minutes or note required", http.StatusBadRequest)

			return

		}

		finished := cur.Finished

		if in.Finished != nil {

			finished = *in.Finished

		}

		if finished && pages == 0 {

			http.Error(w, "finished logs must include pages_read", http.StatusBadRequest)

			return

		}

		_, err = db.Exec(`



			UPDATE reading_logs



			SET log_date=?, pages_read=?, duration_minutes=?, note=?, finished=?



			WHERE id=? AND user_id=?



		`, logDate, pages, duration, noteOut, b2i(finished), id, uid)

		if err != nil {

			writeErr(w, err)

			return

		}

		// Progress & bitiş güncelle

		if err := recomputeProgress(db, uint(uid), cur.BookID); err != nil {

			writeErr(w, err)

			return

		}

		writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})

	})

}

// DELETE /api/logs/{id}

func LogDelete(db *sql.DB) http.Handler {

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		uid, ok := mw.GetUserID(r)

		if !ok {

			http.Error(w, "unauthorized", http.StatusUnauthorized)

			return

		}

		id, err := pathID(r.URL.Path, "/api/logs/")

		if err != nil || id <= 0 {

			http.Error(w, "invalid id", http.StatusBadRequest)

			return

		}

		// book_id almak için önce oku

		var bookID uint

		var userID uint

		err = db.QueryRow(`SELECT book_id, user_id FROM reading_logs WHERE id=?`, id).Scan(&bookID, &userID)

		if errors.Is(err, sql.ErrNoRows) {

			http.Error(w, "not found", http.StatusNotFound)

			return

		}

		if err != nil {

			writeErr(w, err)

			return

		}

		if userID != uint(uid) {

			http.Error(w, "forbidden", http.StatusForbidden)

			return

		}

		if _, err := db.Exec(`DELETE FROM reading_logs WHERE id=? AND user_id=?`, id, uid); err != nil {

			writeErr(w, err)

			return

		}

		// Progress & bitiş güncelle

		if err := recomputeProgress(db, uint(uid), bookID); err != nil {

			writeErr(w, err)

			return

		}

		writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})

	})

}

// Progress & bitiş durumunu yeniden hesapla

func recomputeProgress(db *sql.DB, uid, bookID uint) error {

	// toplam okunan sayfa

	var sum uint

	if err := db.QueryRow(`



		SELECT COALESCE(SUM(pages_read),0)



		FROM reading_logs WHERE user_id=? AND book_id=?



	`, uid, bookID).Scan(&sum); err != nil {

		return err

	}

	// kitap total_pages ve mevcut finished_at

	var total uint

	var finishedAt sql.NullTime

	if err := db.QueryRow(`



		SELECT total_pages, finished_at



		FROM books WHERE id=? AND user_id=?



	`, bookID, uid).Scan(&total, &finishedAt); err != nil {

		return err

	}

	// finished log’larının en son tarihi

	var finDate sql.NullString

	if err := db.QueryRow(`



		SELECT DATE_FORMAT(MAX(log_date),'%Y-%m-%d')



		FROM reading_logs WHERE user_id=? AND book_id=? AND finished=1



	`, uid, bookID).Scan(&finDate); err != nil {

		return err

	}

	// clamp current_page

	progress := sum

	if total > 0 && progress > total {

		progress = total

	}

	// Bitmişlik durumunu SADECE loglar ve ilerlemeye göre belirle

	isFinished := false

	var finishedTime *time.Time = nil

	if finDate.Valid {

		// Bitirme kaydı var -> o tarihle bitti

		t, _ := time.Parse("2006-01-02", finDate.String)

		isFinished = true

		finishedTime = &t

	} else if total > 0 && progress >= total {

		// Bitirme kaydı olmasa da ilerleme tamam

		isFinished = true

		// Eğer önceden bir finished_at varsa onu koru; yoksa bugün koy

		if finishedAt.Valid {

			t := finishedAt.Time

			finishedTime = &t

		} else {

			t := time.Now().Truncate(24 * time.Hour)

			finishedTime = &t

		}

	} else {

		// Bitmemiş -> finished_at NULL olmalı

		finishedTime = nil

	}

	// sql.NullTime paramı hazırla

	var finNT sql.NullTime

	if finishedTime != nil {

		finNT = sql.NullTime{Time: *finishedTime, Valid: true}

	} else {

		finNT = sql.NullTime{Valid: false}

	}

	// Güncelle: finished_at=? (NULL gönderince sütun NULL olur)

	_, err := db.Exec(`



		UPDATE books



		SET current_page=?, is_finished=?, finished_at=?,
		    reading_status=CASE
		      WHEN ?=1 THEN 'finished'
		      WHEN ?>0 AND reading_status<>'paused' THEN 'reading'
		      ELSE reading_status
		    END



		WHERE id=? AND user_id=?



	`, progress, b2i(isFinished), finNT, b2i(isFinished), progress, bookID, uid)

	return err

}
