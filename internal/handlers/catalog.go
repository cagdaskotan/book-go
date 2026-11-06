package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"time"
)

// googleBooksKeyParam, GOOGLE_BOOKS_KEY ortam değişkeni ayarlıysa
// "&key=..." döndürür; yoksa boş döner (anahtarsız çağrı).
func googleBooksKeyParam() string {
	if key := strings.TrimSpace(os.Getenv("GOOGLE_BOOKS_KEY")); key != "" {
		return "&key=" + url.QueryEscape(key)
	}
	return ""
}

var isbnPattern = regexp.MustCompile(`^(?:\d{9}[\dXx]|\d{13})$`)

type CatalogBook struct {
	ISBN       string  `json:"isbn"`
	Title      string  `json:"title"`
	Author     *string `json:"author,omitempty"`
	TotalPages int     `json:"total_pages"`
	CoverURL   *string `json:"cover_url,omitempty"`
	Category   *string `json:"category,omitempty"`
	Publisher  *string `json:"publisher,omitempty"`
	Source     string  `json:"source"`
}

func CatalogISBN() http.Handler {
	client := &http.Client{Timeout: 8 * time.Second}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		isbn := normalizeISBN(strings.TrimPrefix(r.URL.Path, "/api/catalog/isbn/"))
		if !isbnPattern.MatchString(isbn) {
			http.Error(w, "invalid isbn", http.StatusBadRequest)
			return
		}

		book, googleBooksErr := lookupGoogleBooks(client, isbn)
		if googleBooksErr == nil {
			writeJSON(w, http.StatusOK, book)
			return
		}

		book, openLibraryErr := lookupOpenLibrary(client, isbn)
		if openLibraryErr == nil {
			writeJSON(w, http.StatusOK, book)
			return
		}

		if errors.Is(openLibraryErr, errCatalogNotFound) &&
			errors.Is(googleBooksErr, errCatalogNotFound) {
			http.Error(w, "book not found", http.StatusNotFound)
			return
		}

		writeErr(w, fmt.Errorf(
			"catalog lookup failed: open library: %v; google books: %v",
			openLibraryErr,
			googleBooksErr,
		))
	})
}

var errCatalogNotFound = errors.New("catalog book not found")

// CatalogSearch: başlığa göre arama. Google Books (sunucu tarafı, Türkçe
// öncelikli) + Open Library sonuçlarını birleştirip tekilleştirir.
// Barkod ile aynı kaynağı kullandığı için İş Bankası gibi Türkçe baskılar gelir.
func CatalogSearch() http.Handler {
	client := &http.Client{Timeout: 8 * time.Second}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := strings.TrimSpace(r.URL.Query().Get("q"))
		if len([]rune(q)) < 2 {
			writeJSON(w, http.StatusOK, []CatalogBook{})
			return
		}

		seen := map[string]bool{}
		out := make([]CatalogBook, 0, 40)
		add := func(books []CatalogBook) {
			for _, b := range books {
				if strings.TrimSpace(b.Title) == "" {
					continue
				}
				key := catalogDedupKey(b)
				if seen[key] {
					continue
				}
				seen[key] = true
				out = append(out, b)
			}
		}

		// Google önce (Türkçe başlık + yayınevi), sonra Open Library doldurur.
		add(searchGoogleBooks(client, q))
		add(searchOpenLibrary(client, q))

		writeJSON(w, http.StatusOK, out)
	})
}

func catalogDedupKey(b CatalogBook) string {
	title := strings.ToLower(strings.TrimSpace(b.Title))
	title = strings.Map(func(r rune) rune {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			return r
		}
		return -1
	}, title)
	author := ""
	if b.Author != nil {
		parts := strings.Fields(strings.ToLower(*b.Author))
		if len(parts) > 0 {
			author = parts[0]
		}
	}
	return title + "|" + author
}

func searchGoogleBooks(client *http.Client, q string) []CatalogBook {
	endpoint := "https://www.googleapis.com/books/v1/volumes?q=" +
		url.QueryEscape(q) +
		"&maxResults=20&printType=books&country=TR" + googleBooksKeyParam()
	res, err := client.Get(endpoint)
	if err != nil {
		return nil
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil
	}

	var payload struct {
		Items []struct {
			VolumeInfo struct {
				Title               string              `json:"title"`
				Authors             []string            `json:"authors"`
				PageCount           int                 `json:"pageCount"`
				Categories          []string            `json:"categories"`
				Publisher           string              `json:"publisher"`
				ImageLinks          map[string]string   `json:"imageLinks"`
				IndustryIdentifiers []map[string]string `json:"industryIdentifiers"`
			} `json:"volumeInfo"`
		} `json:"items"`
	}
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		return nil
	}

	out := make([]CatalogBook, 0, len(payload.Items))
	for _, item := range payload.Items {
		info := item.VolumeInfo
		if strings.TrimSpace(info.Title) == "" {
			continue
		}
		cover := info.ImageLinks["thumbnail"]
		if larger := info.ImageLinks["large"]; larger != "" {
			cover = larger
		}
		cover = strings.Replace(cover, "http://", "https://", 1)
		isbn := ""
		for _, id := range info.IndustryIdentifiers {
			if id["type"] == "ISBN_13" || id["type"] == "ISBN_10" {
				isbn = id["identifier"]
				break
			}
		}
		out = append(out, CatalogBook{
			ISBN:       isbn,
			Title:      info.Title,
			Author:     firstString(latinizeAuthors(info.Authors)),
			TotalPages: info.PageCount,
			CoverURL:   stringPtr(cover),
			Category:   firstString(info.Categories),
			Publisher:  stringPtr(info.Publisher),
			Source:     "google_books",
		})
	}
	return out
}

func searchOpenLibrary(client *http.Client, q string) []CatalogBook {
	endpoint := "https://openlibrary.org/search.json?q=" + url.QueryEscape(q) +
		"&limit=30&fields=" + url.QueryEscape(
		"title,author_name,cover_i,number_of_pages_median,publisher,isbn")
	res, err := client.Get(endpoint)
	if err != nil {
		return nil
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil
	}

	var payload struct {
		Docs []struct {
			Title       string   `json:"title"`
			AuthorName  []string `json:"author_name"`
			CoverI      *int64   `json:"cover_i"`
			Pages       *int     `json:"number_of_pages_median"`
			Publisher   []string `json:"publisher"`
			ISBN        []string `json:"isbn"`
		} `json:"docs"`
	}
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		return nil
	}

	out := make([]CatalogBook, 0, len(payload.Docs))
	for _, doc := range payload.Docs {
		if strings.TrimSpace(doc.Title) == "" {
			continue
		}
		var cover *string
		if doc.CoverI != nil {
			c := fmt.Sprintf("https://covers.openlibrary.org/b/id/%d-M.jpg", *doc.CoverI)
			cover = &c
		}
		pages := 0
		if doc.Pages != nil {
			pages = *doc.Pages
		}
		isbn := ""
		if len(doc.ISBN) > 0 {
			isbn = doc.ISBN[0]
		}
		out = append(out, CatalogBook{
			ISBN:       isbn,
			Title:      doc.Title,
			Author:     firstString(latinizeAuthors(doc.AuthorName)),
			TotalPages: pages,
			CoverURL:   cover,
			Publisher:  firstString(doc.Publisher),
			Source:     "open_library",
		})
	}
	return out
}

func lookupGoogleBooks(client *http.Client, isbn string) (CatalogBook, error) {
	endpoint := "https://www.googleapis.com/books/v1/volumes?q=" +
		url.QueryEscape("isbn:"+isbn) + "&maxResults=5&langRestrict=tr" +
		googleBooksKeyParam()
	res, err := client.Get(endpoint)
	if err != nil {
		return CatalogBook{}, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return CatalogBook{}, fmt.Errorf("google books returned %s", res.Status)
	}

	var payload struct {
		Items []struct {
			VolumeInfo struct {
				Title               string              `json:"title"`
				Authors             []string            `json:"authors"`
				PageCount           int                 `json:"pageCount"`
				Categories          []string            `json:"categories"`
				Publisher           string              `json:"publisher"`
				ImageLinks          map[string]string   `json:"imageLinks"`
				IndustryIdentifiers []map[string]string `json:"industryIdentifiers"`
			} `json:"volumeInfo"`
		} `json:"items"`
	}
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		return CatalogBook{}, err
	}
	if len(payload.Items) == 0 || strings.TrimSpace(payload.Items[0].VolumeInfo.Title) == "" {
		return CatalogBook{}, errCatalogNotFound
	}

	info := payload.Items[0].VolumeInfo
	cover := info.ImageLinks["thumbnail"]
	if larger := info.ImageLinks["large"]; larger != "" {
		cover = larger
	}
	cover = strings.Replace(cover, "http://", "https://", 1)

	return CatalogBook{
		ISBN:       isbn,
		Title:      info.Title,
		Author:     firstString(latinizeAuthors(info.Authors)),
		TotalPages: info.PageCount,
		CoverURL:   stringPtr(cover),
		Category:   firstString(info.Categories),
		Publisher:  stringPtr(info.Publisher),
		Source:     "google_books",
	}, nil
}

func lookupOpenLibrary(client *http.Client, isbn string) (CatalogBook, error) {
	key := "ISBN:" + isbn
	endpoint := "https://openlibrary.org/api/books?bibkeys=" +
		url.QueryEscape(key) + "&jscmd=data&format=json"
	res, err := client.Get(endpoint)
	if err != nil {
		return CatalogBook{}, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return CatalogBook{}, fmt.Errorf("open library returned %s", res.Status)
	}

	var payload map[string]struct {
		Title   string `json:"title"`
		Pages   int    `json:"number_of_pages"`
		Authors []struct {
			Name string `json:"name"`
		} `json:"authors"`
		Publishers []struct {
			Name string `json:"name"`
		} `json:"publishers"`
		Subjects []struct {
			Name string `json:"name"`
		} `json:"subjects"`
		Cover map[string]string `json:"cover"`
	}
	if err := json.NewDecoder(res.Body).Decode(&payload); err != nil {
		return CatalogBook{}, err
	}
	info, ok := payload[key]
	if !ok || strings.TrimSpace(info.Title) == "" {
		return CatalogBook{}, errCatalogNotFound
	}

	var authors []string
	for _, author := range info.Authors {
		authors = append(authors, author.Name)
	}
	var categories []string
	for _, subject := range info.Subjects {
		categories = append(categories, subject.Name)
	}
	var publishers []string
	for _, publisher := range info.Publishers {
		publishers = append(publishers, publisher.Name)
	}

	cover := info.Cover["large"]
	if cover == "" {
		cover = "https://covers.openlibrary.org/b/isbn/" + isbn + "-L.jpg"
	}
	return CatalogBook{
		ISBN:       isbn,
		Title:      info.Title,
		Author:     stringPtr(strings.Join(latinizeAuthors(authors), ", ")),
		TotalPages: info.Pages,
		CoverURL:   stringPtr(cover),
		Category:   firstString(categories),
		Publisher:  firstString(publishers),
		Source:     "open_library",
	}, nil
}

func normalizeISBN(raw string) string {
	replacer := strings.NewReplacer("-", "", " ", "")
	return replacer.Replace(strings.TrimSpace(raw))
}

func firstString(values []string) *string {
	if len(values) == 0 {
		return nil
	}
	return stringPtr(values[0])
}

func stringPtr(value string) *string {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	return &value
}

func latinizeAuthors(authors []string) []string {
	result := make([]string, 0, len(authors))
	for _, author := range authors {
		result = append(result, transliterateCyrillic(author))
	}
	return result
}

func transliterateCyrillic(value string) string {
	replacer := strings.NewReplacer(
		"А", "A", "Б", "B", "В", "V", "Г", "G", "Д", "D", "Е", "E",
		"Ё", "Yo", "Ж", "Zh", "З", "Z", "И", "I", "Й", "Y", "К", "K",
		"Л", "L", "М", "M", "Н", "N", "О", "O", "П", "P", "Р", "R",
		"С", "S", "Т", "T", "У", "U", "Ф", "F", "Х", "Kh", "Ц", "Ts",
		"Ч", "Ch", "Ш", "Sh", "Щ", "Shch", "Ъ", "", "Ы", "Y", "Ь", "",
		"Э", "E", "Ю", "Yu", "Я", "Ya",
		"а", "a", "б", "b", "в", "v", "г", "g", "д", "d", "е", "e",
		"ё", "yo", "ж", "zh", "з", "z", "и", "i", "й", "y", "к", "k",
		"л", "l", "м", "m", "н", "n", "о", "o", "п", "p", "р", "r",
		"с", "s", "т", "t", "у", "u", "ф", "f", "х", "kh", "ц", "ts",
		"ч", "ch", "ш", "sh", "щ", "shch", "ъ", "", "ы", "y", "ь", "",
		"э", "e", "ю", "yu", "я", "ya",
	)
	return replacer.Replace(value)
}
