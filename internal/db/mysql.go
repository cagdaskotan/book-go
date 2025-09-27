package db

import (
	"database/sql"
	"fmt"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

type Opts struct {
	User, Pass, Host, Port, Name string
}

func Connect(o Opts) (*sql.DB, error) {
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&charset=utf8mb4&loc=Local&multiStatements=true",
		o.User, o.Pass, o.Host, o.Port, o.Name)
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(25)
	db.SetConnMaxLifetime(30 * time.Minute)

	if err := db.Ping(); err != nil {
		return nil, err
	}
	return db, nil
}

// EnsureDatabase: Sunucuya (DB seçmeden) bağlanır ve DB yoksa oluşturur.
func EnsureDatabase(o Opts) error {
	dsnNoDB := fmt.Sprintf("%s:%s@tcp(%s:%s)/?parseTime=true&charset=utf8mb4&loc=Local",
		o.User, o.Pass, o.Host, o.Port)

	srv, err := sql.Open("mysql", dsnNoDB)
	if err != nil {
		return err
	}
	defer srv.Close()

	_, err = srv.Exec(fmt.Sprintf(
		"CREATE DATABASE IF NOT EXISTS %s CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
		o.Name,
	))
	return err
}
