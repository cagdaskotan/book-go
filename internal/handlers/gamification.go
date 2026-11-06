package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"book/internal/mw"
)

const defaultDailyPageGoal = 20

type GamificationSummary struct {
	DailyPageGoal int       `json:"daily_page_goal"`
	TodayPages    int       `json:"today_pages"`
	CurrentStreak int       `json:"current_streak"`
	LongestStreak int       `json:"longest_streak"`
	TotalPages    int       `json:"total_pages"`
	FinishedBooks int       `json:"finished_books"`
	ActiveDays    int       `json:"active_days"`
	XP            int       `json:"xp"`
	Level         int       `json:"level"`
	LevelProgress int       `json:"level_progress"`
	Week          []WeekDay `json:"week"`
}

type WeekDay struct {
	Date      string `json:"date"`
	PagesRead int    `json:"pages_read"`
	GoalMet   bool   `json:"goal_met"`
	IsToday   bool   `json:"is_today"`
}

func GamificationGet(db *sql.DB) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		summary, err := buildGamificationSummary(db, uid, time.Now())
		if err != nil {
			writeErr(w, err)
			return
		}
		writeJSON(w, http.StatusOK, summary)
	})
}

func GamificationUpdate(db *sql.DB) http.Handler {
	type req struct {
		DailyPageGoal int `json:"daily_page_goal"`
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
		if in.DailyPageGoal < 1 || in.DailyPageGoal > 500 {
			http.Error(w, "daily_page_goal must be between 1 and 500", http.StatusBadRequest)
			return
		}

		_, err := db.Exec(`
			INSERT INTO reading_preferences (user_id, daily_page_goal)
			VALUES (?, ?)
			ON DUPLICATE KEY UPDATE daily_page_goal=VALUES(daily_page_goal)
		`, uid, in.DailyPageGoal)
		if err != nil {
			writeErr(w, err)
			return
		}

		summary, err := buildGamificationSummary(db, uid, time.Now())
		if err != nil {
			writeErr(w, err)
			return
		}
		writeJSON(w, http.StatusOK, summary)
	})
}

func buildGamificationSummary(db *sql.DB, uid uint, now time.Time) (GamificationSummary, error) {
	today := dateOnly(now)
	goal := defaultDailyPageGoal
	err := db.QueryRow(`
		SELECT daily_page_goal
		FROM reading_preferences
		WHERE user_id=?
	`, uid).Scan(&goal)
	if err != nil && err != sql.ErrNoRows {
		return GamificationSummary{}, err
	}

	rows, err := db.Query(`
		SELECT DATE_FORMAT(log_date, '%Y-%m-%d'), SUM(pages_read)
		FROM reading_logs
		WHERE user_id=? AND pages_read > 0
		GROUP BY log_date
		ORDER BY log_date ASC
	`, uid)
	if err != nil {
		return GamificationSummary{}, err
	}
	defer rows.Close()

	pagesByDate := make(map[string]int)
	var dates []time.Time
	totalPages := 0
	for rows.Next() {
		var rawDate string
		var pages int
		if err := rows.Scan(&rawDate, &pages); err != nil {
			return GamificationSummary{}, err
		}
		parsed, err := time.Parse("2006-01-02", rawDate)
		if err != nil {
			return GamificationSummary{}, err
		}
		pagesByDate[rawDate] = pages
		dates = append(dates, parsed)
		totalPages += pages
	}
	if err := rows.Err(); err != nil {
		return GamificationSummary{}, err
	}

	var finishedBooks int
	if err := db.QueryRow(`
		SELECT COUNT(1) FROM books WHERE user_id=? AND is_finished=1
	`, uid).Scan(&finishedBooks); err != nil {
		return GamificationSummary{}, err
	}

	current, longest := calculateStreaks(dates, today)
	activeDays := len(dates)
	xp := totalPages + finishedBooks*100 + activeDays*10
	level := xp/500 + 1
	levelProgress := xp % 500

	weekStart := today.AddDate(0, 0, -weekdayOffset(today.Weekday()))
	week := make([]WeekDay, 0, 7)
	for i := 0; i < 7; i++ {
		day := weekStart.AddDate(0, 0, i)
		key := day.Format("2006-01-02")
		pages := pagesByDate[key]
		week = append(week, WeekDay{
			Date:      key,
			PagesRead: pages,
			GoalMet:   pages >= goal,
			IsToday:   day.Equal(today),
		})
	}

	return GamificationSummary{
		DailyPageGoal: goal,
		TodayPages:    pagesByDate[today.Format("2006-01-02")],
		CurrentStreak: current,
		LongestStreak: longest,
		TotalPages:    totalPages,
		FinishedBooks: finishedBooks,
		ActiveDays:    activeDays,
		XP:            xp,
		Level:         level,
		LevelProgress: levelProgress,
		Week:          week,
	}, nil
}

func calculateStreaks(dates []time.Time, today time.Time) (current, longest int) {
	if len(dates) == 0 {
		return 0, 0
	}

	run := 1
	longest = 1
	for i := 1; i < len(dates); i++ {
		if dates[i].Sub(dates[i-1]) == 24*time.Hour {
			run++
		} else if !dates[i].Equal(dates[i-1]) {
			run = 1
		}
		if run > longest {
			longest = run
		}
	}

	last := dates[len(dates)-1]
	if last.Equal(today) || last.Equal(today.AddDate(0, 0, -1)) {
		current = 1
		for i := len(dates) - 1; i > 0; i-- {
			if dates[i].Sub(dates[i-1]) != 24*time.Hour {
				break
			}
			current++
		}
	}
	return current, longest
}

func dateOnly(t time.Time) time.Time {
	y, m, d := t.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

func weekdayOffset(day time.Weekday) int {
	if day == time.Sunday {
		return 6
	}
	return int(day - time.Monday)
}
