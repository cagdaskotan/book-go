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

	mux.Handle("GET /api/books", withAuthLog(handlers.BooksList(sqlDB)))
	mux.Handle("POST /api/books", withAuthLog(handlers.BookCreate(sqlDB)))
	mux.Handle("PUT /api/books/", withAuthLog(handlers.BookUpdate(sqlDB))) // <-- EKLENDİ ( /api/books/{id} )
	mux.Handle("DELETE /api/books/", withAuthLog(handlers.BookDelete(sqlDB)))

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
