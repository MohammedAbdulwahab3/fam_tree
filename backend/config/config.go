// Package config reads the handful of settings this server takes from its
// environment, in one place so that no two callers can disagree about a
// default. Registration once filed new members under "default-tree-id" while
// the seeder and the app both used "main-family-tree", which meant every
// account joined a family tree that did not exist.
package config

import (
	"log"
	"os"
	"strings"
)

// DefaultFamilyTreeID is the tree new members join and the seeder populates.
const DefaultFamilyTreeID = "main-family-tree"

// FamilyTreeID is the tree this deployment serves. One tree per deployment:
// the app has no tree picker, so there is nothing to switch between.
func FamilyTreeID() string {
	if id := strings.TrimSpace(os.Getenv("FAMILY_TREE_ID")); id != "" {
		return id
	}
	return DefaultFamilyTreeID
}

// Port is the port to listen on.
func Port() string {
	if port := strings.TrimSpace(os.Getenv("PORT")); port != "" {
		return port
	}
	return "8080"
}

// IsRelease reports whether this process is running as a deployment rather
// than on a developer's machine.
func IsRelease() bool {
	return strings.EqualFold(strings.TrimSpace(os.Getenv("GIN_MODE")), "release")
}

// RequireSecret returns the value of an environment variable that must be set
// in a release build, and falls back to devFallback outside one.
//
// The old behaviour was to log a warning and carry on with a hardcoded signing
// key. Nobody reads a warning in a container log, so a deployment missing
// JWT_SECRET would sign every session with a key that is public in this
// repository — and appear to work perfectly.
func RequireSecret(name, devFallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	if IsRelease() {
		log.Fatalf("%s is not set. Refusing to start in release mode with an "+
			"insecure default — generate one with: openssl rand -base64 48", name)
	}
	log.Printf("WARNING: %s is not set — using an insecure development default. "+
		"Set it before deploying.", name)
	return devFallback
}
