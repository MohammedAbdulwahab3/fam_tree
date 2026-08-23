package middleware

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// RateLimitConfig describes one limiter: at most Requests per Window, per
// client IP.
type RateLimitConfig struct {
	Requests int
	Window   time.Duration
	// Message is what the caller is told. Written for a person, since these
	// limits sit on sign-in and password reset where a real member can
	// plausibly hit one after a few bad attempts.
	Message string
}

// RateLimit limits requests per client IP.
//
// In-memory and per-process, which is the right size for this server: it runs
// as a single instance for one family. Its purpose is to make an eight-
// character reset code and a six-character password unguessable by brute force,
// not to survive a distributed attack.
func RateLimit(cfg RateLimitConfig) gin.HandlerFunc {
	if cfg.Requests <= 0 {
		cfg.Requests = 10
	}
	if cfg.Window <= 0 {
		cfg.Window = time.Minute
	}
	if cfg.Message == "" {
		cfg.Message = "Too many requests. Try again shortly."
	}

	var (
		mu      sync.Mutex
		hits    = make(map[string][]time.Time)
		swept   time.Time
		sweepIn = 5 * time.Minute
	)

	return func(c *gin.Context) {
		key := c.ClientIP()
		now := time.Now()
		cutoff := now.Add(-cfg.Window)

		mu.Lock()

		// Drop clients that have gone quiet, so an open endpoint cannot grow
		// this map without bound.
		if now.Sub(swept) > sweepIn {
			for ip, times := range hits {
				if len(times) == 0 || times[len(times)-1].Before(cutoff) {
					delete(hits, ip)
				}
			}
			swept = now
		}

		recent := hits[key][:0]
		for _, t := range hits[key] {
			if t.After(cutoff) {
				recent = append(recent, t)
			}
		}

		if len(recent) >= cfg.Requests {
			retryAfter := cfg.Window - now.Sub(recent[0])
			hits[key] = recent
			mu.Unlock()

			c.Header("Retry-After", strconv.Itoa(max(1, int(retryAfter.Seconds()))))
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": cfg.Message,
			})
			return
		}

		hits[key] = append(recent, now)
		mu.Unlock()

		c.Next()
	}
}
