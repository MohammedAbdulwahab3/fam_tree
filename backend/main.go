package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"family-tree-backend/handlers"
	"family-tree-backend/middleware"
	"family-tree-backend/models"
	"family-tree-backend/seed"
	"family-tree-backend/services"

	firebase "firebase.google.com/go/v4"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"google.golang.org/api/option"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var db *gorm.DB

func main() {
	// Initialize Database
	var err error

	// Get database URL from environment, default to localhost PostgreSQL
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "host=127.0.0.1 user=postgres password=postgres dbname=family_tree port=5432 sslmode=disable"
	}

	db, err = gorm.Open(postgres.Open(dbURL), &gorm.Config{})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	log.Println("Connected to PostgreSQL database")

	// Check for seed flag
	if len(os.Args) > 1 && os.Args[1] == "--seed" {
		seed.SeedDatabase(db)
		return
	}

	// Auto Migrate
	db.AutoMigrate(
		&models.User{},
		&models.Person{},
		&models.Post{},
		&models.Message{},
		&models.Event{},
		&models.Comment{},
		&models.Reaction{},
		&models.Notification{},
		&models.DeviceToken{},
		&models.NotificationPreference{},
		&models.Reminder{},
		&models.LinkRequest{},
		&models.PasswordReset{},
	)

	// Create uploads directory
	if _, err := os.Stat("uploads"); os.IsNotExist(err) {
		os.Mkdir("uploads", 0755)
	}

	// Initialize Redis
	middleware.InitRedis()

	// Notifications. The in-app list is written straight to the database and
	// needs nothing external, so it works on every deployment. Push delivery is
	// an optional layer on top: set FIREBASE_CREDENTIALS to turn it on.
	notificationService := services.NewNotificationService(db)
	enablePushIfConfigured(notificationService)

	// Reminders are only useful if something actually delivers them.
	go notificationService.ProcessScheduledReminders(time.Minute)

	// Initialize Handlers
	authHandler := &handlers.AuthHandler{DB: db}
	personHandler := &handlers.PersonHandler{DB: db}
	uploadHandler := &handlers.UploadHandler{}
	postHandler := &handlers.PostHandler{DB: db, NotificationService: notificationService}
	messageHandler := &handlers.MessageHandler{DB: db, NotificationService: notificationService}
	eventHandler := &handlers.EventHandler{DB: db, NotificationService: notificationService}
	notificationHandler := &handlers.NotificationHandler{DB: db}
	reminderHandler := &handlers.ReminderHandler{DB: db}
	linkHandler := &handlers.LinkHandler{DB: db, NotificationService: notificationService}
	passwordHandler := &handlers.PasswordHandler{DB: db}

	// Setup Router
	r := gin.Default()

	// CORS Middleware
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Public Routes
	r.POST("/register", authHandler.Register)
	r.POST("/login", authHandler.Login)
	// Public by necessity: someone who cannot sign in cannot authenticate to
	// ask for a password reset. The admin-issued code is what proves identity.
	r.POST("/reset-password", passwordHandler.ResetPassword)
	r.Static("/uploads", "./uploads")
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "pong"})
	})

	// Secret admin promotion endpoint (for initial setup only)
	r.POST("/init-admin", func(c *gin.Context) {
		var req struct {
			Email     string `json:"email"`
			SecretKey string `json:"secret_key"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Secret key for initial admin setup
		if req.SecretKey != "FamilyTree2026AdminSecret" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid secret key"})
			return
		}

		var user models.User
		if result := db.First(&user, "email = ?", req.Email); result.Error != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		user.Role = models.RoleAdmin
		if result := db.Save(&user); result.Error != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "User promoted to admin", "user": user})
	})

	// Public read-only access to persons (for demo mode)
	r.GET("/public/persons", personHandler.GetPersons)

	// Protected Routes (authenticated users)
	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware(db))
	{
		// User info endpoint - get current user with role
		api.GET("/me", func(c *gin.Context) {
			user, exists := c.Get("user")
			if !exists {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
				return
			}
			c.JSON(http.StatusOK, user)
		})

		// Update the signed-in user's own profile. The user ID comes from the
		// verified token, never from the request body, so a caller can only
		// ever edit themselves. Role is deliberately not updatable here.
		api.PUT("/me", func(c *gin.Context) {
			userID := c.GetString("userID")

			// Pointers so an omitted field is left untouched.
			var req struct {
				Name            *string `json:"name"`
				ProfilePhotoURL *string `json:"profilePhotoUrl"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			var user models.User
			if err := db.First(&user, "id = ?", userID).Error; err != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
				return
			}

			if req.Name != nil {
				name := strings.TrimSpace(*req.Name)
				if name == "" {
					c.JSON(http.StatusBadRequest, gin.H{"error": "Name cannot be empty"})
					return
				}
				user.Name = name
			}
			if req.ProfilePhotoURL != nil {
				user.ProfilePhotoURL = *req.ProfilePhotoURL
			}
			if err := db.Save(&user).Error; err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not update profile"})
				return
			}

			c.JSON(http.StatusOK, user)
		})

		// Person Routes - READ for all authenticated users

		// Users endpoint - get all registered users
		api.GET("/users", func(c *gin.Context) {
			var users []models.User
			if result := db.Find(&users); result.Error != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
				return
			}
			c.JSON(http.StatusOK, users)
		})
		api.GET("/persons", personHandler.GetPersons)
		api.GET("/persons/:id", personHandler.GetPerson)

		// Person UPDATE - users can update their own profile
		api.PUT("/persons/:id", personHandler.UpdatePersonWithPermission)

		// Upload Routes - all authenticated users can upload (for profile photos)
		api.POST("/upload", uploadHandler.UploadFile)

		// Post Routes. Members write to the feed here; the handlers take the
		// author from the token and enforce "your own only" on delete, so the
		// admin group below differs by privilege, not by capability.
		api.GET("/posts", postHandler.GetPosts)
		api.POST("/posts", postHandler.CreatePost)
		api.DELETE("/posts/:id", postHandler.DeletePost)
		api.GET("/posts/:id/comments", postHandler.GetComments)
		api.POST("/posts/:id/reactions", postHandler.ToggleReaction)

		// Comments - all users can comment
		api.POST("/posts/:id/comments", postHandler.CreateComment)
		api.PUT("/comments/:id", postHandler.UpdateComment)
		api.DELETE("/comments/:id", postHandler.DeleteComment)

		// Message Routes - all users can chat
		api.GET("/messages", messageHandler.GetMessages)
		api.POST("/messages", messageHandler.SendMessage)
		api.PUT("/messages/:id", messageHandler.UpdateMessage)
		api.DELETE("/messages/:id", messageHandler.DeleteMessage)

		// Event Routes. Anyone signed in can propose a family event; only the
		// organiser or an admin can then change or cancel it.
		api.GET("/events", eventHandler.GetEvents)
		api.POST("/events", eventHandler.CreateEvent)
		api.PUT("/events/:id", eventHandler.UpdateEvent)
		api.DELETE("/events/:id", eventHandler.DeleteEvent)
		api.POST("/events/:id/rsvp", eventHandler.ToggleRSVP)

		// Notification Routes
		api.POST("/devices/register", notificationHandler.RegisterDeviceToken)
		api.GET("/notifications", notificationHandler.GetNotifications)
		api.GET("/notifications/unread-count", notificationHandler.GetUnreadCount)
		api.PUT("/notifications/:id/read", notificationHandler.MarkAsRead)
		api.PUT("/notifications/read-all", notificationHandler.MarkAllAsRead)
		api.DELETE("/notifications/:id", notificationHandler.DeleteNotification)
		api.DELETE("/notifications", notificationHandler.DeleteAllNotifications)
		api.GET("/notifications/preferences", notificationHandler.GetPreferences)
		api.PUT("/notifications/preferences", notificationHandler.UpdatePreferences)

		// Reminder Routes
		api.GET("/reminders", reminderHandler.GetReminders)
		api.POST("/reminders", reminderHandler.CreateReminder)
		api.PUT("/reminders/:id", reminderHandler.UpdateReminder)
		api.PUT("/reminders/:id/snooze", reminderHandler.SnoozeReminder)
		api.DELETE("/reminders/:id", reminderHandler.DeleteReminder)

		// Account routes
		api.PUT("/me/password", passwordHandler.ChangePassword)
		api.DELETE("/me", passwordHandler.DeleteOwnAccount)

		// Link Request Routes
		api.POST("/link-requests", linkHandler.RequestLink)
		api.GET("/link-requests/my-status", linkHandler.GetMyLinkStatus)
		api.DELETE("/link-requests/mine", linkHandler.CancelMyLinkRequest)
	}

	// Admin-only Routes
	admin := r.Group("/api/admin")
	admin.Use(middleware.AuthMiddleware(db), middleware.AdminMiddleware(db))
	{
		// Link Request Admin Routes
		admin.GET("/link-requests", linkHandler.GetLinkRequests)
		admin.PUT("/link-requests/:id", linkHandler.UpdateLinkStatus)

		// Person management - CREATE, DELETE (admin only)
		admin.POST("/persons", personHandler.CreatePerson)
		admin.PUT("/persons/:id", personHandler.UpdatePerson)
		admin.DELETE("/persons/:id", personHandler.DeletePerson)

		// Post management - CREATE, UPDATE, DELETE (admin only)
		admin.POST("/posts", postHandler.CreatePost)
		admin.PUT("/posts/:id", postHandler.UpdatePost)
		admin.DELETE("/posts/:id", postHandler.DeletePost)

		// Event management - CREATE, UPDATE, DELETE (admin only)
		admin.POST("/events", eventHandler.CreateEvent)
		admin.PUT("/events/:id", eventHandler.UpdateEvent)
		admin.DELETE("/events/:id", eventHandler.DeleteEvent)

		// User management — returns a plain array, which is the shape the
		// Flutter admin repository already parses.
		admin.GET("/users", func(c *gin.Context) {
			var users []models.User
			if result := db.Find(&users); result.Error != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
				return
			}
			c.JSON(http.StatusOK, users)
		})

		// Issue a one-time code for a member who is locked out.
		admin.POST("/users/:id/reset-code", passwordHandler.IssueResetCode)

		admin.PUT("/users/:id/role", func(c *gin.Context) {
			id := c.Param("id")
			var req struct {
				Role string `json:"role"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			var user models.User
			if result := db.First(&user, "id = ?", id); result.Error != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
				return
			}

			role := models.UserRole(req.Role)
			if role != models.RoleAdmin && role != models.RoleMember {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Role must be 'admin' or 'member'"})
				return
			}

			// Never let the last admin demote themselves out of existence.
			if user.Role == models.RoleAdmin && role != models.RoleAdmin {
				var admins int64
				db.Model(&models.User{}).Where("role = ?", models.RoleAdmin).Count(&admins)
				if admins <= 1 {
					c.JSON(http.StatusConflict, gin.H{
						"error": "Cannot demote the last remaining admin",
					})
					return
				}
			}

			user.Role = role
			if result := db.Save(&user); result.Error != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
				return
			}

			c.JSON(http.StatusOK, user)
		})

		// Suspend or restore an account. A ban takes effect on the next
		// request because AuthMiddleware re-reads the user every time.
		admin.PUT("/users/:id/ban", func(c *gin.Context) {
			id := c.Param("id")
			var req struct {
				Banned bool   `json:"banned"`
				Reason string `json:"reason"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			if id == c.GetString("userID") {
				c.JSON(http.StatusConflict, gin.H{"error": "You cannot ban yourself"})
				return
			}

			var user models.User
			if err := db.First(&user, "id = ?", id).Error; err != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
				return
			}

			if req.Banned && user.Role == models.RoleAdmin {
				c.JSON(http.StatusConflict, gin.H{"error": "Cannot ban another admin"})
				return
			}

			user.IsBanned = req.Banned
			if req.Banned {
				now := time.Now()
				user.BannedAt = &now
				user.BanReason = strings.TrimSpace(req.Reason)
			} else {
				user.BannedAt = nil
				user.BanReason = ""
			}

			if err := db.Save(&user).Error; err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not update account"})
				return
			}
			c.JSON(http.StatusOK, user)
		})

		// Permanently remove an account.
		admin.DELETE("/users/:id", func(c *gin.Context) {
			id := c.Param("id")

			if id == c.GetString("userID") {
				c.JSON(http.StatusConflict, gin.H{"error": "You cannot delete your own account"})
				return
			}

			var user models.User
			if err := db.First(&user, "id = ?", id).Error; err != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
				return
			}

			if user.Role == models.RoleAdmin {
				var admins int64
				db.Model(&models.User{}).Where("role = ?", models.RoleAdmin).Count(&admins)
				if admins <= 1 {
					c.JSON(http.StatusConflict, gin.H{
						"error": "Cannot delete the last remaining admin",
					})
					return
				}
			}

			// Unscoped: a soft delete would leave the row occupying the unique
			// email index, so the address could never be registered again.
			if err := db.Unscoped().Delete(&user).Error; err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not delete user"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"message": "User deleted", "id": id})
		})

		// Broadcast an announcement as one in-app notification per user, which
		// the existing notifications screen already renders.
		admin.POST("/announcements", func(c *gin.Context) {
			var req struct {
				Title   string `json:"title"`
				Message string `json:"message"`
			}
			if err := c.ShouldBindJSON(&req); err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			title := strings.TrimSpace(req.Title)
			message := strings.TrimSpace(req.Message)
			if title == "" || message == "" {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Title and message are required"})
				return
			}

			var users []models.User
			if err := db.Find(&users).Error; err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not load recipients"})
				return
			}

			announcementID := uuid.New().String()
			now := time.Now()
			notifications := make([]models.Notification, 0, len(users))
			for _, u := range users {
				notifications = append(notifications, models.Notification{
					ID:         uuid.New().String(),
					UserID:     u.ID,
					Type:       models.NotificationAnnouncement,
					EntityType: "announcement",
					EntityID:   announcementID,
					Title:      title,
					Body:       message,
					SentAt:     now,
					CreatedAt:  now,
				})
			}

			if len(notifications) > 0 {
				if err := db.Create(&notifications).Error; err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not send announcement"})
					return
				}
			}

			c.JSON(http.StatusCreated, gin.H{
				"message":    "Announcement sent",
				"id":         announcementID,
				"recipients": len(notifications),
			})
		})

		// Full JSON export of a family tree.
		admin.GET("/export/:familyTreeId", func(c *gin.Context) {
			treeID := c.Param("familyTreeId")

			var people []models.Person
			if err := db.Where("family_tree_id = ?", treeID).
				Order("display_order asc").Find(&people).Error; err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not load people"})
				return
			}

			var posts []models.Post
			db.Where("family_tree_id = ?", treeID).Find(&posts)
			var events []models.Event
			db.Find(&events)

			c.JSON(http.StatusOK, gin.H{
				"familyTreeId": treeID,
				"exportedAt":   time.Now(),
				"counts": gin.H{
					"people": len(people),
					"posts":  len(posts),
					"events": len(events),
				},
				"people": people,
				"posts":  posts,
				"events": events,
			})
		})
	}

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server starting on :%s", port)
	r.Run(":" + port)
}

// enablePushIfConfigured turns on device push when Firebase credentials are
// present. Its absence is a normal configuration, not a failure: notifications
// still appear in the app, they just do not reach the lock screen.
func enablePushIfConfigured(notifications *services.NotificationService) {
	credentials := os.Getenv("FIREBASE_CREDENTIALS")
	if credentials == "" {
		log.Println("Push notifications disabled (FIREBASE_CREDENTIALS not set); " +
			"in-app notifications are unaffected")
		return
	}

	app, err := firebase.NewApp(
		context.Background(),
		nil,
		option.WithCredentialsJSON([]byte(credentials)),
	)
	if err != nil {
		log.Printf("Push notifications disabled: could not read FIREBASE_CREDENTIALS: %v", err)
		return
	}

	if err := notifications.EnableFCM(app); err != nil {
		log.Printf("Push notifications disabled: %v", err)
		return
	}

	log.Println("Push notifications enabled")
}
