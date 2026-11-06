package handlers

import (
	"testing"
	"time"
)

func TestCalculateStreaks(t *testing.T) {
	today := time.Date(2026, time.June, 12, 0, 0, 0, 0, time.UTC)
	dates := []time.Time{
		today.AddDate(0, 0, -6),
		today.AddDate(0, 0, -5),
		today.AddDate(0, 0, -2),
		today.AddDate(0, 0, -1),
		today,
	}

	current, longest := calculateStreaks(dates, today)
	if current != 3 {
		t.Fatalf("current streak = %d, want 3", current)
	}
	if longest != 3 {
		t.Fatalf("longest streak = %d, want 3", longest)
	}
}

func TestCalculateStreaksAllowsYesterday(t *testing.T) {
	today := time.Date(2026, time.June, 12, 0, 0, 0, 0, time.UTC)
	dates := []time.Time{
		today.AddDate(0, 0, -2),
		today.AddDate(0, 0, -1),
	}

	current, longest := calculateStreaks(dates, today)
	if current != 2 || longest != 2 {
		t.Fatalf("got current=%d longest=%d, want 2 and 2", current, longest)
	}
}
