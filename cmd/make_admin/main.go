package main

import (
	"fmt"
	"log"
	"os"

	"family-tree-backend/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	// Get database URL from environment or use default
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "host=127.0.0.1 user=postgres password=postgres dbname=family_tree port=5432 sslmode=disable"
	}

	// Connect to database
	db, err := gorm.Open(postgres.Open(dbURL), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	// Check if user email/ID is provided as argument
	if len(os.Args) < 2 {
		// No argument provided, make the most recently created user an admin
		var user models.User
		if result := db.Order("created_at DESC").First(&user); result.Error != nil {
			log.Fatal("Failed to find any users:", result.Error)
		}

		fmt.Printf("Found most recent user: %s (%s)\n", user.Email, user.Name)
		fmt.Printf("Current role: %s\n", user.Role)

		// Update to admin
		user.Role = models.RoleAdmin
		if result := db.Save(&user); result.Error != nil {
			log.Fatal("Failed to update user role:", result.Error)
		}

		fmt.Printf("✅ Successfully updated %s to admin role!\n", user.Email)
		return
	}

	// User provided email or ID as argument
	userIdentifier := os.Args[1]

	var user models.User
	// Try to find by email first, then by ID
	if result := db.Where("email = ?", userIdentifier).Or("id = ?", userIdentifier).First(&user); result.Error != nil {
		log.Fatal("Failed to find user:", result.Error)
	}

	fmt.Printf("Found user: %s (%s)\n", user.Email, user.Name)
	fmt.Printf("Current role: %s\n", user.Role)

	// Update to admin
	user.Role = models.RoleAdmin
	if result := db.Save(&user); result.Error != nil {
		log.Fatal("Failed to update user role:", result.Error)
	}

	fmt.Printf("✅ Successfully updated %s to admin role!\n", user.Email)
}
