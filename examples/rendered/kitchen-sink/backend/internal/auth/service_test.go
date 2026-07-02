package auth_test

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"

	"github.com/example/kitchen-sink-app/backend/internal/testsupport"
)

func decode(t *testing.T, b []byte) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatalf("decode: %v (%s)", err, string(b))
	}
	return m
}

func TestSignup(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		setupTest(t)

		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/signup",
			`{"email":"a@b.com","password":"Password123!","name":"A"}`)
		if w.Code != http.StatusCreated {
			t.Fatalf("status = %d, want 201 (%s)", w.Code, w.Body.String())
		}
		body := decode(t, w.Body.Bytes())
		if body["token"] == "" || body["token"] == nil {
			t.Fatal("expected a session token")
		}

		// Password must be stored hashed, never in plaintext.
		var hash string
		if err := testDB.Pool.QueryRow(context.Background(),
			`SELECT password_hash FROM users WHERE email = $1`, "a@b.com").Scan(&hash); err != nil {
			t.Fatalf("query: %v", err)
		}
		if hash == "" || hash == "Password123!" {
			t.Fatalf("password not hashed: %q", hash)
		}
		if body["refresh_token"] == "" || body["refresh_token"] == nil {
			t.Fatal("expected a refresh token")
		}
		// The verification credential is emailed, never returned in the response.
		if body["code"] != nil || body["verify_token"] != nil {
			t.Fatal("credential must not be returned in the response")
		}
		if mailer.verifications["a@b.com"] == "" {
			t.Fatal("expected a verification credential to be emailed")
		}
	})

	t.Run("conflict", func(t *testing.T) {
		setupTest(t)

		testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/signup",
			`{"email":"dup@b.com","password":"Password123!"}`)
		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/signup",
			`{"email":"dup@b.com","password":"Password123!"}`)
		if w.Code != http.StatusConflict {
			t.Fatalf("status = %d, want 409", w.Code)
		}
	})

	t.Run("validation", func(t *testing.T) {
		setupTest(t)

		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/signup",
			`{"email":"a@b.com","password":"short"}`)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want 400", w.Code)
		}
	})
}

func TestLogin(t *testing.T) {
	signup := func() {
		testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/signup",
			`{"email":"u@b.com","password":"Password123!"}`)
	}

	t.Run("success", func(t *testing.T) {
		setupTest(t)
		signup()

		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/login",
			`{"email":"u@b.com","password":"Password123!"}`)
		if w.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200 (%s)", w.Code, w.Body.String())
		}
		if decode(t, w.Body.Bytes())["token"] == nil {
			t.Fatal("expected a token")
		}
	})

	t.Run("authorization", func(t *testing.T) {
		setupTest(t)
		signup()

		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/login",
			`{"email":"u@b.com","password":"wrongpass"}`)
		if w.Code != http.StatusUnauthorized {
			t.Fatalf("status = %d, want 401", w.Code)
		}
	})

	t.Run("validation", func(t *testing.T) {
		setupTest(t)

		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/login", `{}`)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want 400", w.Code)
		}
	})
}

// signupSession signs up and returns the (access, refresh) pair.
func signupSession(t *testing.T, email string) (string, string) {
	t.Helper()
	w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/signup",
		`{"email":"`+email+`","password":"Password123!"}`)
	if w.Code != http.StatusCreated {
		t.Fatalf("signup status = %d (%s)", w.Code, w.Body.String())
	}
	b := decode(t, w.Body.Bytes())
	return b["token"].(string), b["refresh_token"].(string)
}

func TestGetCurrentUser(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		setupTest(t)
		access, _ := signupSession(t, "me@b.com")

		w := testsupport.DoJSONAuth(router, http.MethodGet, "/api/v1/auth/me", "", access)
		if w.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200 (%s)", w.Code, w.Body.String())
		}
		if decode(t, w.Body.Bytes())["email"] != "me@b.com" {
			t.Fatalf("unexpected user: %s", w.Body.String())
		}
	})

	t.Run("authorization", func(t *testing.T) {
		setupTest(t)

		w := testsupport.DoJSON(router, http.MethodGet, "/api/v1/auth/me", "")
		if w.Code != http.StatusUnauthorized {
			t.Fatalf("status = %d, want 401", w.Code)
		}
	})
}

func TestRefreshToken(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		setupTest(t)
		_, refresh := signupSession(t, "rt@b.com")

		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/refresh",
			`{"refresh_token":"`+refresh+`"}`)
		if w.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200 (%s)", w.Code, w.Body.String())
		}
		if decode(t, w.Body.Bytes())["token"] == nil {
			t.Fatal("expected a new access token")
		}

		// Rotation: the old refresh token is revoked and cannot be reused.
		reuse := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/refresh",
			`{"refresh_token":"`+refresh+`"}`)
		if reuse.Code != http.StatusUnauthorized {
			t.Fatalf("reused refresh status = %d, want 401", reuse.Code)
		}
	})

	t.Run("authorization", func(t *testing.T) {
		setupTest(t)

		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/refresh",
			`{"refresh_token":"nope"}`)
		if w.Code != http.StatusUnauthorized {
			t.Fatalf("status = %d, want 401", w.Code)
		}
	})
}

func TestLogout(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		setupTest(t)
		_, refresh := signupSession(t, "lo@b.com")

		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/logout",
			`{"refresh_token":"`+refresh+`"}`)
		if w.Code != http.StatusNoContent {
			t.Fatalf("status = %d, want 204 (%s)", w.Code, w.Body.String())
		}

		// The refresh token is revoked after logout.
		after := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/refresh",
			`{"refresh_token":"`+refresh+`"}`)
		if after.Code != http.StatusUnauthorized {
			t.Fatalf("refresh after logout = %d, want 401", after.Code)
		}
	})
}

func TestVerifyEmail(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		setupTest(t)

		signupResp := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/signup",
			`{"email":"v@b.com","password":"Password123!"}`)
		credential := mailer.verifications["v@b.com"]
		if credential == "" {
			t.Fatal("no verification credential captured")
		}
		_ = signupResp
		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/verify",
			`{"token":"`+credential+`"}`)
		if w.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200 (%s)", w.Code, w.Body.String())
		}

		var verified bool
		if err := testDB.Pool.QueryRow(context.Background(),
			`SELECT verified FROM users WHERE email = $1`, "v@b.com").Scan(&verified); err != nil {
			t.Fatalf("query: %v", err)
		}
		if !verified {
			t.Fatal("user should be verified")
		}
	})

	t.Run("validation", func(t *testing.T) {
		setupTest(t)
		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/verify",
			`{"token":"not-a-real-token"}`)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want 400", w.Code)
		}
	})
}

func TestConfirmPasswordReset(t *testing.T) {
	t.Run("success", func(t *testing.T) {
		setupTest(t)

		testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/signup",
			`{"email":"r@b.com","password":"Password123!"}`)
		req := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/password-reset/request",
			`{"email":"r@b.com"}`)
		if req.Code != http.StatusOK {
			t.Fatalf("request status = %d, want 200", req.Code)
		}
		credential := mailer.resets["r@b.com"]
		if credential == "" {
			t.Fatal("no reset credential captured")
		}
		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/password-reset/confirm",
			`{"token":"`+credential+`","password":"NewPassword123!"}`)
		if w.Code != http.StatusOK {
			t.Fatalf("confirm status = %d, want 200 (%s)", w.Code, w.Body.String())
		}

		// New password works.
		login := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/login",
			`{"email":"r@b.com","password":"NewPassword123!"}`)
		if login.Code != http.StatusOK {
			t.Fatalf("login with new password = %d, want 200", login.Code)
		}
	})

	t.Run("validation", func(t *testing.T) {
		setupTest(t)
		w := testsupport.DoJSON(router, http.MethodPost, "/api/v1/auth/password-reset/confirm",
			`{"token":"bad","password":"NewPassword123!"}`)
		if w.Code != http.StatusBadRequest {
			t.Fatalf("status = %d, want 400", w.Code)
		}
	})
}
