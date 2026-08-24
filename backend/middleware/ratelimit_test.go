package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func init() { gin.SetMode(gin.TestMode) }

func newLimitedRouter(cfg RateLimitConfig) *gin.Engine {
	r := gin.New()
	r.POST("/login", RateLimit(cfg), func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})
	return r
}

func attempt(r *gin.Engine, ip string) int {
	req := httptest.NewRequest(http.MethodPost, "/login", nil)
	req.RemoteAddr = ip + ":54321"
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	return rec.Code
}

func TestAllowsUpToTheLimitThenRefuses(t *testing.T) {
	r := newLimitedRouter(RateLimitConfig{Requests: 3, Window: time.Minute})

	for i := 1; i <= 3; i++ {
		if code := attempt(r, "10.0.0.1"); code != http.StatusOK {
			t.Fatalf("attempt %d should have been allowed, got %d", i, code)
		}
	}

	if code := attempt(r, "10.0.0.1"); code != http.StatusTooManyRequests {
		t.Fatalf("the fourth attempt should have been refused, got %d", code)
	}
}

// One member fumbling their password must not lock out the rest of the family.
func TestLimitsEachClientSeparately(t *testing.T) {
	r := newLimitedRouter(RateLimitConfig{Requests: 1, Window: time.Minute})

	attempt(r, "10.0.0.1")
	if code := attempt(r, "10.0.0.1"); code != http.StatusTooManyRequests {
		t.Fatalf("the first client should be limited, got %d", code)
	}
	if code := attempt(r, "10.0.0.2"); code != http.StatusOK {
		t.Fatalf("a different client should be unaffected, got %d", code)
	}
}

func TestTheWindowExpires(t *testing.T) {
	r := newLimitedRouter(RateLimitConfig{Requests: 1, Window: 40 * time.Millisecond})

	attempt(r, "10.0.0.1")
	if code := attempt(r, "10.0.0.1"); code != http.StatusTooManyRequests {
		t.Fatalf("expected to be limited, got %d", code)
	}

	time.Sleep(60 * time.Millisecond)

	if code := attempt(r, "10.0.0.1"); code != http.StatusOK {
		t.Fatalf("the window should have expired, got %d", code)
	}
}

func TestRefusalCarriesRetryAfter(t *testing.T) {
	r := newLimitedRouter(RateLimitConfig{Requests: 1, Window: time.Minute})

	attempt(r, "10.0.0.1")

	req := httptest.NewRequest(http.MethodPost, "/login", nil)
	req.RemoteAddr = "10.0.0.1:54321"
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if got := rec.Header().Get("Retry-After"); got == "" {
		t.Fatal("a refusal should say when to try again")
	}
}
