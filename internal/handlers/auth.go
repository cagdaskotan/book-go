package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"book/internal/auth"
	"book/internal/mw"
)

type User struct {
	ID           uint      `json:"id"`
	Email        string    `json:"email"`
	DisplayName  *string   `json:"display_name,omitempty"`
	PasswordHash *string   `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

func AuthRegister(db *sql.DB, jwtSecret string, jwtTTL string) http.Handler {
	type req struct {
		Email       string `json:"email"`
		Password    string `json:"password"`
		DisplayName string `json:"display_name"`
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var in req
		if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
			http.Error(w, "bad json", http.StatusBadRequest)
			return
		}
		in.Email = strings.TrimSpace(strings.ToLower(in.Email))
		if in.Email == "" || in.Password == "" {
			http.Error(w, "email/password required", http.StatusBadRequest)
			return
		}

		var exists int
		_ = db.QueryRow(`SELECT COUNT(1) FROM users WHERE email=?`, in.Email).Scan(&exists)
		if exists > 0 {
			http.Error(w, "email already used", http.StatusConflict)
			return
		}

		hash, err := auth.HashPassword(in.Password)
		if err != nil {
			http.Error(w, "hash error", http.StatusInternalServerError)
			return
		}

		res, err := db.Exec(`INSERT INTO users (email, display_name, password_hash) VALUES (?,?,?)`,
			in.Email, nullableStr(in.DisplayName), hash)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		id64, _ := res.LastInsertId()

		token, _ := auth.GenerateToken(jwtSecret, uint(id64), auth.ParseTTL(jwtTTL))
		writeJSON(w, http.StatusCreated, map[string]any{"token": token})
	})
}

func AuthLogin(db *sql.DB, jwtSecret string, jwtTTL string) http.Handler {
	type req struct{ Email, Password string }
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var in req
		if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
			http.Error(w, "bad json", http.StatusBadRequest)
			return
		}
		in.Email = strings.TrimSpace(strings.ToLower(in.Email))
		if in.Email == "" || in.Password == "" {
			http.Error(w, "email/password required", http.StatusBadRequest)
			return
		}

		var u User
		var ph string
		err := db.QueryRow(`SELECT id,email,display_name,password_hash,created_at FROM users WHERE email=?`, in.Email).
			Scan(&u.ID, &u.Email, &u.DisplayName, &ph, &u.CreatedAt)
		if err == sql.ErrNoRows {
			http.Error(w, "invalid credentials", http.StatusUnauthorized)
			return
		}
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		if !auth.CheckPassword(ph, in.Password) {
			http.Error(w, "invalid credentials", http.StatusUnauthorized)
			return
		}

		token, _ := auth.GenerateToken(jwtSecret, u.ID, auth.ParseTTL(jwtTTL))
		writeJSON(w, http.StatusOK, map[string]any{"token": token})
	})
}

func AuthMe(db *sql.DB) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		u, err := fetchUserByID(db, uid)
		if err == sql.ErrNoRows {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, u)
	})
}

func AuthUpdateProfile(db *sql.DB) http.Handler {
	type req struct {
		DisplayName *string `json:"display_name"`
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

		var name interface{}
		if in.DisplayName != nil {
			trimmed := strings.TrimSpace(*in.DisplayName)
			if trimmed != "" {
				if utf8.RuneCountInString(trimmed) > 120 {
					http.Error(w, "display_name too long", http.StatusBadRequest)
					return
				}
				name = trimmed
			}
		}

		res, err := db.Exec(`UPDATE users SET display_name=? WHERE id=?`, name, uid)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		if rows, _ := res.RowsAffected(); rows == 0 {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}

		u, err := fetchUserByID(db, uid)
		if err != nil {
			if err == sql.ErrNoRows {
				http.Error(w, "not found", http.StatusNotFound)
				return
			}
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, u)
	})
}

func AuthChangePassword(db *sql.DB) http.Handler {
	type req struct {
		Current string `json:"current_password"`
		New     string `json:"new_password"`
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
		if in.Current == "" || in.New == "" {
			http.Error(w, "current and new password required", http.StatusBadRequest)
			return
		}
		if len(in.New) < 6 {
			http.Error(w, "new password must be at least 6 characters", http.StatusBadRequest)
			return
		}

		var hash sql.NullString
		if err := db.QueryRow(`SELECT password_hash FROM users WHERE id=?`, uid).Scan(&hash); err != nil {
			if err == sql.ErrNoRows {
				http.Error(w, "not found", http.StatusNotFound)
				return
			}
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		if !auth.CheckPassword(hash.String, in.Current) {
			http.Error(w, "current password incorrect", http.StatusBadRequest)
			return
		}
		if in.Current == in.New {
			http.Error(w, "new password must be different", http.StatusBadRequest)
			return
		}

		newHash, err := auth.HashPassword(in.New)
		if err != nil {
			http.Error(w, "password hash error", http.StatusInternalServerError)
			return
		}

		_, err = db.Exec(`UPDATE users SET password_hash=? WHERE id=?`, newHash, uid)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusNoContent)
	})
}

func nullableStr(s string) *string {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return &s
}

func fetchUserByID(db *sql.DB, id uint) (*User, error) {
	var u User
	err := db.QueryRow(`SELECT id,email,display_name,created_at FROM users WHERE id=?`, id).
		Scan(&u.ID, &u.Email, &u.DisplayName, &u.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}
