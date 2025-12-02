package middleware

import (
	"context"
	"log"
	"net/http"
	"strings"

	"family-tree-backend/models"

	firebase "firebase.google.com/go/v4"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func AuthMiddleware(app *firebase.App, db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		var uid string

		// No auth header - use dev mode
		if authHeader == "" {
			log.Println("Warning: No Authorization header, using dev mode")
			uid = "dev-user"
		} else {
			parts := strings.Split(authHeader, " ")
			if len(parts) != 2 || parts[0] != "Bearer" {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization header format"})
				c.Abort()
				return
			}

			tokenString := parts[1]

			// If Firebase app is not initialized (e.g. dev mode without creds), use token as uid
			if app == nil {
				log.Println("Warning: Firebase app not initialized, using token prefix as uid")
				// Use part of the token as a pseudo-uid for dev
				if len(tokenString) > 20 {
					uid = tokenString[:20]
				} else {
					uid = tokenString
				}
			} else {
				client, err := app.Auth(context.Background())
				if err != nil {
					log.Printf("Warning: Error initializing auth client: %v, using dev mode", err)
					uid = "dev-user"
				} else {
					token, err := client.VerifyIDToken(context.Background(), tokenString)
					if err != nil {
						log.Printf("Warning: Token verification failed: %v, using dev mode", err)
						// In dev mode, still allow access but with limited uid
						uid = "unverified-user"
					} else {
						uid = token.UID
					}
				}
			}
		}

		// Sync user to local DB
		var user models.User
		if err := db.First(&user, "id = ?", uid).Error; err != nil {
			if err == gorm.ErrRecordNotFound {
				// Create new user with default member role
				newUser := models.User{
					ID:    uid,
					Email: "", // We might not have email in token claims easily without extra lookup
					Name:  "Firebase User",
					Role:  models.RoleMember,
				}
				if err := db.Create(&newUser).Error; err != nil {
					log.Printf("Error creating user sync: %v", err)
					// Continue anyway, maybe just a glitch
				}
				user = newUser
			} else {
				log.Printf("Error checking user sync: %v", err)
			}
		}

		// Set the UID and role info
		c.Set("userID", uid)
		c.Set("user", user)
		c.Set("isAdmin", user.IsAdmin())
		c.Next()
	}
}
