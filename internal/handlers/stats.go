package handlers

import (
	"database/sql"
	"net/http"
	"strconv"
	"time"

	"book/internal/mw"
)

type DailyActivity struct {
	Date  string `json:"date"` // YYYY-MM-DD
	Pages int    `json:"pages"`
}

// StatsDaily: GET /api/stats/daily?year=YYYY
// Verilen yıl için gün-bazlı okunan sayfa toplamı (ısı haritası verisi).
func StatsDaily(db *sql.DB) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		year := time.Now().Year()
		if raw := r.URL.Query().Get("year"); raw != "" {
			if y, err := strconv.Atoi(raw); err == nil && y > 1970 && y < 3000 {
				year = y
			}
		}

		rows, err := db.Query(`
			SELECT DATE_FORMAT(log_date, '%Y-%m-%d') AS d, SUM(pages_read) AS p
			FROM reading_logs
			WHERE user_id = ? AND YEAR(log_date) = ?
			GROUP BY log_date
			ORDER BY log_date ASC
		`, uid, year)
		if err != nil {
			writeErr(w, err)
			return
		}
		defer rows.Close()

		out := make([]DailyActivity, 0)
		for rows.Next() {
			var d string
			var p sql.NullInt64
			if err := rows.Scan(&d, &p); err != nil {
				writeErr(w, err)
				return
			}
			out = append(out, DailyActivity{Date: d, Pages: int(p.Int64)})
		}
		writeJSON(w, http.StatusOK, out)
	})
}
