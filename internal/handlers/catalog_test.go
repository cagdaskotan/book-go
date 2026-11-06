package handlers

import "testing"

func TestTransliterateCyrillicAuthor(t *testing.T) {
	t.Parallel()

	got := transliterateCyrillic("Лев Толстой")
	want := "Lev Tolstoy"
	if got != want {
		t.Fatalf("transliterateCyrillic() = %q, want %q", got, want)
	}
}

func TestLatinizeAuthorsKeepsLatinNames(t *testing.T) {
	t.Parallel()

	got := latinizeAuthors([]string{"José Saramago", "Фёдор Достоевский"})
	if got[0] != "José Saramago" {
		t.Fatalf("latin author changed: %q", got[0])
	}
	if got[1] != "Fyodor Dostoevskiy" {
		t.Fatalf("cyrillic author = %q", got[1])
	}
}
