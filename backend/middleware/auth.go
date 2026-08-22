package middleware

import (
	"log"
	"net/http"
	"strings"

	"family-tree-backend/auth"
	"family-tree-backend/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// AuthMiddleware validates the JWT issued by /login or /register and loads the
// matching user. Requests without a valid token are rejected — the token is the
// only accepted proof of identity.
func AuthMiddleware(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Authorization header required",
			})
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Authorization header must be 'Bearer <token>'",
			})
			return
		}

		claims, err := auth.ValidateToken(strings.TrimSpace(parts[1]))
		if err != nil {
			log.Printf("Auth: rejected token: %v", err)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid or expired token",
			})
			return
		}

		// The token only carries a user ID; the role always comes from the
		// database so a stale token can never carry stale privileges.
		var user models.User
		if err := db.First(&user, "id = ?", claims.UserID).Error; err != nil {
			if err == gorm.ErrRecordNotFound {
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
					"error": "User no longer exists",
				})
				return
			}
			log.Printf("Auth: database error loading user %s: %v", claims.UserID, err)
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
				"error": "Could not load user",
			})
			return
		}

		// A ban must take effect immediately, including for tokens issued
		// before it — the role and ban state are re-read on every request.
		if user.IsBanned {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error":  "This account has been suspended",
				"reason": user.BanReason,
			})
			return
		}

		c.Set("userID", user.ID)
		c.Set("user", user)
		c.Set("isAdmin", user.IsAdmin())
		c.Next()
	}
}
