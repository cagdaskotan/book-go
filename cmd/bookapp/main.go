package main

import (
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"book/internal/config"
	"book/internal/db"
	"book/internal/handlers"
	"book/internal/migrate"
	"book/internal/mw"
)

func main() {
	// 1) Konfig
	cfg := config.Load()

	// 2) DB yoksa oluştur
	opts := db.Opts{
		User: cfg.DBUser,
		Pass: cfg.DBPass,
		Host: cfg.DBHost,
		Port: cfg.DBPort,
		Name: cfg.DBName,
	}
	if err := db.EnsureDatabase(opts); err != nil {
		log.Fatal("[ensure db] ", err)
	}

	// 3) Bağlan
	sqlDB, err := db.Connect(opts)
	if err != nil {
		log.Fatal(err)
	}
	defer sqlDB.Close()

	// 4) Migrasyon
	if err := migrate.Run(sqlDB); err != nil {
		log.Fatal("[migrate] ", err)
	}
	log.Println("[migrate] ok")

	// 5) Router
	mux := http.NewServeMux()

	// ---- PUBLIC AUTH
	mux.Handle("POST /api/auth/register", handlers.AuthRegister(sqlDB, cfg.JWTSecret, cfg.JWTTTL))
	mux.Handle("POST /api/auth/login", handlers.AuthLogin(sqlDB, cfg.JWTSecret, cfg.JWTTTL))

	// ---- PROTECTED API (endpoint bazında sarıyoruz; alt-mux mount YOK)
	withAuthLog := func(h http.Handler) http.Handler {
		return mw.Chain(h, mw.WithAuth(cfg.JWTSecret), mw.RequestLogger())
	}
	mux.Handle("GET /api/auth/me", withAuthLog(handlers.AuthMe(sqlDB)))
	mux.Handle("PUT /api/auth/me", withAuthLog(handlers.AuthUpdateProfile(sqlDB)))
	mux.Handle("POST /api/auth/change-password", withAuthLog(handlers.AuthChangePassword(sqlDB)))
	mux.Handle("GET /api/books/", withAuthLog(handlers.BookGet(sqlDB))) // /api/books/{id}

	mux.Handle("GET /api/books", withAuthLog(handlers.BooksList(sqlDB)))
	mux.Handle("POST /api/books", withAuthLog(handlers.BookCreate(sqlDB)))
	mux.Handle("PUT /api/books/", withAuthLog(handlers.BookUpdate(sqlDB))) // <-- ( /api/books/{id} )
	mux.Handle("DELETE /api/books/", withAuthLog(handlers.BookDelete(sqlDB)))
	// LOGS (hepsi korumalı)
	mux.Handle("GET /api/logs", withAuthLog(handlers.LogsList(sqlDB))) // ?book_id=&from=&to=
	mux.Handle("POST /api/logs", withAuthLog(handlers.LogCreate(sqlDB)))
	mux.Handle("PUT /api/logs/", withAuthLog(handlers.LogUpdate(sqlDB)))    // /api/logs/{id}
	mux.Handle("DELETE /api/logs/", withAuthLog(handlers.LogDelete(sqlDB))) // /api/logs/{id}
	mux.Handle("GET /api/gamification", withAuthLog(handlers.GamificationGet(sqlDB)))
	mux.Handle("PUT /api/gamification", withAuthLog(handlers.GamificationUpdate(sqlDB)))
	mux.Handle("GET /api/catalog/isbn/", withAuthLog(handlers.CatalogISBN()))
	mux.Handle("GET /api/catalog/search", withAuthLog(handlers.CatalogSearch()))
	mux.Handle("GET /api/stats/daily", withAuthLog(handlers.StatsDaily(sqlDB)))
	mux.Handle("GET /api/recommendations", withAuthLog(handlers.Recommendations(sqlDB)))
	mux.Handle("GET /api/quotes", withAuthLog(handlers.QuotesList(sqlDB)))
	mux.Handle("POST /api/quotes", withAuthLog(handlers.QuoteCreate(sqlDB)))
	mux.Handle("DELETE /api/quotes/", withAuthLog(handlers.QuoteDelete(sqlDB)))
	mux.Handle("GET /api/collections", withAuthLog(handlers.CollectionsList(sqlDB)))
	mux.Handle("POST /api/collections", withAuthLog(handlers.CollectionCreate(sqlDB)))
	mux.Handle("POST /api/collections/", withAuthLog(handlers.CollectionAction(sqlDB)))
	mux.Handle("PUT /api/collections/", withAuthLog(handlers.CollectionAction(sqlDB)))
	mux.Handle("PATCH /api/collections/", withAuthLog(handlers.CollectionAction(sqlDB)))
	mux.Handle("DELETE /api/collections/", withAuthLog(handlers.CollectionAction(sqlDB)))

	// ---- Statik
	staticDir := findStatic()
	log.Println("[static] dir =", staticDir)

	// /static/*
	mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServer(http.Dir(staticDir))))

	// favicon
	mux.HandleFunc("GET /favicon.ico", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, filepath.Join(staticDir, "admin", "images", "1.png"))
	})

	// kök sayfa
	mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		http.ServeFile(w, r, filepath.Join(staticDir, "admin", "index.html"))
	})

	// 6) Server
	srv := &http.Server{
		Addr:              ":" + cfg.AppPort,
		Handler:           mux,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Println("listening on http://localhost:" + cfg.AppPort)
	log.Fatal(srv.ListenAndServe())
}

// findStatic: ./static varsa onu, yoksa exe yanındaki static'i dener.
func findStatic() string {
	if _, err := os.Stat("./static"); err == nil {
		return "./static"
	}
	exe, _ := os.Executable()
	dir := filepath.Dir(exe)
	cand := filepath.Join(dir, "static")
	if _, err := os.Stat(cand); err == nil {
		return cand
	}
	return "./static"
}
