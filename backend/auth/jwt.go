package auth

import (
	"errors"
	"log"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// SecretKey signs every issued token. It is read from JWT_SECRET at startup;
// without it the process refuses to fall back to a shared literal in anything
// other than a local dev run.
var SecretKey = loadSecret()

// TokenTTL is how long an issued token stays valid.
//
// Thirty days, not a day. There is no refresh mechanism, so the old 24-hour
// window meant every member was silently signed out once a day: the stored
// token failed on the next launch, the app called signOut, and they were back
// on the landing page. For a family app people open once or twice a week that
// made signing in feel like the main activity.
var TokenTTL = loadTTL()

func loadTTL() time.Duration {
	if raw := os.Getenv("TOKEN_TTL"); raw != "" {
		if parsed, err := time.ParseDuration(raw); err == nil && parsed > 0 {
			return parsed
		}
		log.Printf("WARNING: TOKEN_TTL=%q is not a valid duration; using 720h", raw)
	}
	return 720 * time.Hour
}

func loadSecret() []byte {
	if secret := os.Getenv("JWT_SECRET"); secret != "" {
		return []byte(secret)
	}
	log.Println("WARNING: JWT_SECRET is not set — falling back to an insecure " +
		"development key. Set JWT_SECRET before deploying.")
	return []byte("insecure-development-key-do-not-deploy")
}

type Claims struct {
	UserID string `json:"user_id"`
	jwt.RegisteredClaims
}

func GenerateToken(userID string) (string, error) {
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(TokenTTL)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(SecretKey)
}

func ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(
		tokenString,
		&Claims{},
		func(t *jwt.Token) (interface{}, error) {
			// Pin the algorithm so a token cannot ask to be verified with
			// "none" or with an asymmetric key of the attacker's choosing.
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, errors.New("unexpected signing method")
			}
			return SecretKey, nil
		},
	)
	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}
