package migrate

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"sort"
	"strings"
)

//go:embed sql/*.sql
var files embed.FS

// Run runs embedded SQL migrations in lexical order once.
// It creates a schema_migrations table to track applied filenames.
func Run(db *sql.DB) error {
	ctx := context.Background()

	// ensure tracking table
	if _, err := db.ExecContext(ctx, `
	  CREATE TABLE IF NOT EXISTS schema_migrations (
	    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    filename VARCHAR(255) NOT NULL UNIQUE,
	    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
	  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;`); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	// list embedded files
	entries, err := files.ReadDir("sql")
	if err != nil {
		return fmt.Errorf("read migrations: %w", err)
	}

	// read applied set
	applied := map[string]bool{}
	rows, err := db.QueryContext(ctx, `SELECT filename FROM schema_migrations`)
	if err != nil {
		return fmt.Errorf("select schema_migrations: %w", err)
	}
	for rows.Next() {
		var f string
		_ = rows.Scan(&f)
		applied[f] = true
	}
	_ = rows.Close()

	// sort names lexically (0001_, 0002_...)
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if strings.HasSuffix(strings.ToLower(name), ".sql") {
			names = append(names, name)
		}
	}
	sort.Strings(names)

	// execute each not-applied file in a tx
	for _, name := range names {
		if applied[name] {
			continue
		}
		b, err := files.ReadFile("sql/" + name)
		if err != nil {
			return fmt.Errorf("read %s: %w", name, err)
		}
		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			return fmt.Errorf("begin tx for %s: %w", name, err)
		}
		if _, err := tx.ExecContext(ctx, string(b)); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("apply %s: %w", name, err)
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO schema_migrations (filename) VALUES (?)`, name); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("track %s: %w", name, err)
		}
		if err := tx.Commit(); err != nil {
			return fmt.Errorf("commit %s: %w", name, err)
		}
	}
	return nil
}
