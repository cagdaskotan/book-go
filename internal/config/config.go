package config

import (
	"log"
	"os"
)

type Config struct {
	AppPort   string
	DBHost    string
	DBPort    string
	DBUser    string
	DBPass    string
	DBName    string
	JWTSecret string
	JWTTTL    string // "24h" gibi
}

func Load() *Config {
	cfg := &Config{
		AppPort:   getenv("APP_PORT", "8080"),
		DBHost:    getenv("DB_HOST", "127.0.0.1"),
		DBPort:    getenv("DB_PORT", "3306"),
		DBUser:    getenv("DB_USER", "root"),
		DBPass:    getenv("DB_PASS", ""),
		DBName:    getenv("DB_NAME", "bookdb"),
		JWTSecret: getenv("JWT_SECRET", "dev-secret-change-me"),
		JWTTTL:    getenv("JWT_TTL", "24h"),
	}
	log.Printf("[config] port=%s db=%s@%s:%s/%s", cfg.AppPort, cfg.DBUser, cfg.DBHost, cfg.DBPort, cfg.DBName)
	return cfg
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
