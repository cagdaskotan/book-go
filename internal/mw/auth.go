package mw

import (
	"context"
	"net/http"
	"strings"

	"book/internal/auth"
)

type ctxKey string

const userKey ctxKey = "uid"

func WithAuth(secret string) Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h := r.Header.Get("Authorization")
			if h == "" || !strings.HasPrefix(h, "Bearer ") {
				http.Error(w, "missing token", http.StatusUnauthorized)
				return
			}
			token := strings.TrimPrefix(h, "Bearer ")
			claims, err := auth.ParseToken(secret, token)
			if err != nil {
				http.Error(w, "invalid token", http.StatusUnauthorized)
				return
			}
			ctx := context.WithValue(r.Context(), userKey, claims.UserID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func GetUserID(r *http.Request) (uint, bool) {
	v := r.Context().Value(userKey)
	if v == nil {
		return 0, false
	}
	id, ok := v.(uint)
	return id, ok
}
