package auth

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestRoundTrip(t *testing.T) {
	token, err := GenerateToken("user-123")
	if err != nil {
		t.Fatalf("generate: %v", err)
	}

	claims, err := ValidateToken(token)
	if err != nil {
		t.Fatalf("validate: %v", err)
	}
	if claims.UserID != "user-123" {
		t.Fatalf("got %q, want user-123", claims.UserID)
	}
}

func TestRejectsAnExpiredToken(t *testing.T) {
	expired := jwt.NewWithClaims(jwt.SigningMethodHS256, &Claims{
		UserID: "user-123",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-2 * time.Hour)),
		},
	})
	signed, err := expired.SignedString(SecretKey)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}

	if _, err := ValidateToken(signed); err == nil {
		t.Fatal("an expired token was accepted")
	}
}

// A token that asks to be verified with "none" must be refused outright,
// whatever it claims.
func TestRejectsTheNoneAlgorithm(t *testing.T) {
	unsigned := jwt.NewWithClaims(jwt.SigningMethodNone, &Claims{
		UserID: "attacker",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
		},
	})
	signed, err := unsigned.SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}

	if _, err := ValidateToken(signed); err == nil {
		t.Fatal("an unsigned token was accepted")
	}
}

func TestRejectsAnotherKeysSignature(t *testing.T) {
	forged := jwt.NewWithClaims(jwt.SigningMethodHS256, &Claims{
		UserID: "attacker",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
		},
	})
	signed, err := forged.SignedString([]byte("not-the-server-key"))
	if err != nil {
		t.Fatalf("sign: %v", err)
	}

	if _, err := ValidateToken(signed); err == nil {
		t.Fatal("a token signed with another key was accepted")
	}
}

func TestRejectsGarbage(t *testing.T) {
	for _, input := range []string{"", "not-a-token", "a.b.c"} {
		if _, err := ValidateToken(input); err == nil {
			t.Errorf("ValidateToken(%q) should have failed", input)
		}
	}
}
