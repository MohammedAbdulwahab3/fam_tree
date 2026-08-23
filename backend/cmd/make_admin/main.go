// Command make_admin promotes an account to admin.
//
// This is the only way to create the first admin. It has to run against the
// database directly, which is the point: an HTTP route that grants admin is a
// route anyone can call, and the one that used to exist here accepted a shared
// secret hardcoded in this repository.
//
//	go run ./cmd/make_admin you@example.com   # by email or id
//	go run ./cmd/make_admin                   # the most recently registered
package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"family-tree-backend/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "host=127.0.0.1 user=postgres password=postgres dbname=family_tree port=5432 sslmode=disable"
	}

	db, err := gorm.Open(postgres.Open(dbURL), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database: ", err)
	}

	var user models.User

	if len(os.Args) < 2 {
		if result := db.Order("created_at DESC").First(&user); result.Error != nil {
			log.Fatal("No users exist yet. Register in the app first.")
		}
	} else {
		identifier := strings.ToLower(strings.TrimSpace(os.Args[1]))
		if result := db.Where("email = ?", identifier).
			Or("id = ?", os.Args[1]).First(&user); result.Error != nil {
			log.Fatalf("No user matches %q.", os.Args[1])
		}
	}

	if user.IsAdmin() {
		fmt.Printf("%s (%s) is already an admin.\n", user.Email, user.Name)
		return
	}

	fmt.Printf("Found %s (%s), currently %s.\n", user.Email, user.Name, user.Role)

	if err := db.Model(&models.User{}).Where("id = ?", user.ID).
		Update("role", models.RoleAdmin).Error; err != nil {
		log.Fatal("Failed to update role: ", err)
	}

	fmt.Printf("%s is now an admin.\n", user.Email)
}
