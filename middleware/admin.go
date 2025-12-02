package middleware

import (
	"net/http"

	"family-tree-backend/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// AdminMiddleware checks if the authenticated user has admin role
func AdminMiddleware(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, exists := c.Get("userID")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			c.Abort()
			return
		}

		var user models.User
		if err := db.First(&user, "id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			c.Abort()
			return
		}

		if !user.IsAdmin() {
			c.JSON(http.StatusForbidden, gin.H{"error": "Admin access required"})
			c.Abort()
			return
		}

		c.Set("user", user)
		c.Next()
	}
}

// OwnerOrAdminMiddleware checks if user owns the resource or is admin
// Pass the resource owner's auth user ID to check
func OwnerOrAdminMiddleware(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, exists := c.Get("userID")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			c.Abort()
			return
		}

		var user models.User
		if err := db.First(&user, "id = ?", userID).Error; err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
			c.Abort()
			return
		}

		// Set user and role info for handlers to use
		c.Set("user", user)
		c.Set("isAdmin", user.IsAdmin())
		c.Next()
	}
}
