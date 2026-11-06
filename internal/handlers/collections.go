package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"book/internal/mw"
)

type Collection struct {
	ID      uint64 `json:"id"`
	Name    string `json:"name"`
	Color   string `json:"color"`
	BookIDs []uint `json:"book_ids"`
	// Kitap kimliği (string) -> görünüm biçimi: "spine" | "face" | "stack".
	DisplayModes map[string]string `json:"display_modes"`
}

// validDisplayMode, rafa eklenen kitabın görünüm biçimini doğrular.
func validDisplayMode(m string) bool {
	switch m {
	case "spine", "face", "stack":
		return true
	}
	return false
}

func CollectionsList(db *sql.DB) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		rows, err := db.Query(`
			SELECT c.id, c.name, c.color, cb.book_id, cb.display_mode
			FROM collections c
			LEFT JOIN collection_books cb ON cb.collection_id=c.id
			WHERE c.user_id=?
			ORDER BY c.id DESC, cb.position ASC, cb.added_at DESC
		`, uid)
		if err != nil {
			writeErr(w, err)
			return
		}
		defer rows.Close()

		order := make([]uint64, 0)
		byID := make(map[uint64]*Collection)
		for rows.Next() {
			var id uint64
			var name, color string
			var bookID sql.NullInt64
			var mode sql.NullString
			if err := rows.Scan(&id, &name, &color, &bookID, &mode); err != nil {
				writeErr(w, err)
				return
			}
			collection, exists := byID[id]
			if !exists {
				collection = &Collection{
					ID:           id,
					Name:         name,
					Color:        color,
					BookIDs:      []uint{},
					DisplayModes: map[string]string{},
				}
				byID[id] = collection
				order = append(order, id)
			}
			if bookID.Valid {
				collection.BookIDs = append(collection.BookIDs, uint(bookID.Int64))
				m := mode.String
				if !validDisplayMode(m) {
					m = "spine"
				}
				collection.DisplayModes[strconv.FormatInt(bookID.Int64, 10)] = m
			}
		}

		out := make([]Collection, 0, len(order))
		for _, id := range order {
			out = append(out, *byID[id])
		}
		writeJSON(w, http.StatusOK, out)
	})
}

func CollectionCreate(db *sql.DB) http.Handler {
	type req struct {
		Name  string `json:"name"`
		Color string `json:"color"`
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
		in.Name = strings.TrimSpace(in.Name)
		if in.Name == "" || len([]rune(in.Name)) > 80 {
			http.Error(w, "name required and must be at most 80 characters", http.StatusBadRequest)
			return
		}
		if !validHexColor(in.Color) {
			in.Color = "#6750E8"
		}
		result, err := db.Exec(
			`INSERT INTO collections (user_id, name, color) VALUES (?,?,?)`,
			uid, in.Name, in.Color,
		)
		if err != nil {
			writeErr(w, err)
			return
		}
		id, _ := result.LastInsertId()
		writeJSON(w, http.StatusCreated, Collection{
			ID:      uint64(id),
			Name:    in.Name,
			Color:   in.Color,
			BookIDs: []uint{},
		})
	})
}

func CollectionAction(db *sql.DB) http.Handler {
	type req struct {
		BookID uint `json:"book_id"`
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid, ok := mw.GetUserID(r)
		if !ok {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		parts := strings.Split(strings.Trim(strings.TrimPrefix(r.URL.Path, "/api/collections/"), "/"), "/")
		if len(parts) == 0 {
			http.Error(w, "invalid collection id", http.StatusBadRequest)
			return
		}
		collectionID, err := strconv.ParseUint(parts[0], 10, 64)
		if err != nil {
			http.Error(w, "invalid collection id", http.StatusBadRequest)
			return
		}
		if !ownsCollection(db, uid, collectionID) {
			http.Error(w, "collection not found", http.StatusNotFound)
			return
		}

		if r.Method == http.MethodDelete && len(parts) == 1 {
			if _, err := db.Exec(`DELETE FROM collections WHERE id=? AND user_id=?`, collectionID, uid); err != nil {
				writeErr(w, err)
				return
			}
			writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
			return
		}

		// Rafın adını ve/veya rengini güncelle: PUT /api/collections/{id}
		if (r.Method == http.MethodPut || r.Method == http.MethodPatch) && len(parts) == 1 {
			var body struct {
				Name  string `json:"name"`
				Color string `json:"color"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				http.Error(w, "bad json", http.StatusBadRequest)
				return
			}
			name := strings.TrimSpace(body.Name)
			if name == "" || len([]rune(name)) > 80 {
				http.Error(w, "name required and must be at most 80 characters", http.StatusBadRequest)
				return
			}
			color := body.Color
			if !validHexColor(color) {
				color = "#6750E8"
			}
			if _, err := db.Exec(
				`UPDATE collections SET name=?, color=? WHERE id=? AND user_id=?`,
				name, color, collectionID, uid,
			); err != nil {
				writeErr(w, err)
				return
			}
			writeJSON(w, http.StatusOK, map[string]string{
				"status": "updated",
				"name":   name,
				"color":  color,
			})
			return
		}

		if r.Method == http.MethodDelete && len(parts) == 3 && parts[1] == "books" {
			bookID, err := strconv.ParseUint(parts[2], 10, 64)
			if err != nil || bookID == 0 {
				http.Error(w, "invalid book id", http.StatusBadRequest)
				return
			}
			if _, err := db.Exec(`
				DELETE cb
				FROM collection_books cb
				JOIN books b ON b.id=cb.book_id
				WHERE cb.collection_id=? AND cb.book_id=? AND b.user_id=?
			`, collectionID, bookID, uid); err != nil {
				writeErr(w, err)
				return
			}
			writeJSON(w, http.StatusOK, map[string]string{"status": "removed"})
			return
		}

		// Raftaki kitapların sırasını güncelle: PUT /api/collections/{id}/order
		if (r.Method == http.MethodPut || r.Method == http.MethodPatch) && len(parts) == 2 && parts[1] == "order" {
			var body struct {
				BookIDs []uint64 `json:"book_ids"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				http.Error(w, "book_ids required", http.StatusBadRequest)
				return
			}
			tx, err := db.Begin()
			if err != nil {
				writeErr(w, err)
				return
			}
			for i, bid := range body.BookIDs {
				if _, err := tx.Exec(`
					UPDATE collection_books cb
					JOIN books b ON b.id=cb.book_id
					SET cb.position=?
					WHERE cb.collection_id=? AND cb.book_id=? AND b.user_id=?
				`, i, collectionID, bid, uid); err != nil {
					_ = tx.Rollback()
					writeErr(w, err)
					return
				}
			}
			if err := tx.Commit(); err != nil {
				writeErr(w, err)
				return
			}
			writeJSON(w, http.StatusOK, map[string]string{"status": "reordered"})
			return
		}

		// Bir kitabın bu raftaki görünüm biçimini güncelle.
		if (r.Method == http.MethodPut || r.Method == http.MethodPatch) && len(parts) == 3 && parts[1] == "books" {
			bookID, err := strconv.ParseUint(parts[2], 10, 64)
			if err != nil || bookID == 0 {
				http.Error(w, "invalid book id", http.StatusBadRequest)
				return
			}
			var body struct {
				DisplayMode string `json:"display_mode"`
			}
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil || !validDisplayMode(body.DisplayMode) {
				http.Error(w, "display_mode must be one of spine, face, stack", http.StatusBadRequest)
				return
			}
			res, err := db.Exec(`
				UPDATE collection_books cb
				JOIN books b ON b.id=cb.book_id
				SET cb.display_mode=?
				WHERE cb.collection_id=? AND cb.book_id=? AND b.user_id=?
			`, body.DisplayMode, collectionID, bookID, uid)
			if err != nil {
				writeErr(w, err)
				return
			}
			if n, _ := res.RowsAffected(); n == 0 {
				http.Error(w, "book not in collection", http.StatusNotFound)
				return
			}
			writeJSON(w, http.StatusOK, map[string]string{"status": "updated", "display_mode": body.DisplayMode})
			return
		}

		if len(parts) != 2 || parts[1] != "books" || r.Method != http.MethodPost {
			http.NotFound(w, r)
			return
		}
		var in req
		if err := json.NewDecoder(r.Body).Decode(&in); err != nil || in.BookID == 0 {
			http.Error(w, "book_id required", http.StatusBadRequest)
			return
		}
		var ownsBook int
		_ = db.QueryRow(`SELECT COUNT(1) FROM books WHERE id=? AND user_id=?`, in.BookID, uid).Scan(&ownsBook)
		if ownsBook == 0 {
			http.Error(w, "book not found", http.StatusNotFound)
			return
		}
		if _, err := db.Exec(`
			INSERT IGNORE INTO collection_books (collection_id, book_id) VALUES (?,?)
		`, collectionID, in.BookID); err != nil {
			writeErr(w, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "added"})
	})
}

func ownsCollection(db *sql.DB, uid uint, collectionID uint64) bool {
	var count int
	_ = db.QueryRow(
		`SELECT COUNT(1) FROM collections WHERE id=? AND user_id=?`,
		collectionID, uid,
	).Scan(&count)
	return count > 0
}

func validHexColor(value string) bool {
	if len(value) != 7 || value[0] != '#' {
		return false
	}
	_, err := strconv.ParseUint(value[1:], 16, 24)
	return err == nil
}
