package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// AdminMiddleware refuses anyone who is not an admin.
//
// It reads the flag AuthMiddleware already set rather than loading the user a
// second time: AuthMiddleware re-reads role and ban state from the database on
// every request, so the value in the context is as fresh as a new query would
// be, and every admin route was paying for two lookups of the same row.
func AdminMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if _, authenticated := c.Get("user"); !authenticated {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "User not authenticated",
			})
			return
		}

		if !c.GetBool("isAdmin") {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error": "Admin access required",
			})
			return
		}

		c.Next()
	}
}
