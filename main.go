package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"family-tree-backend/handlers"
	"family-tree-backend/middleware"
	"family-tree-backend/models"
	"family-tree-backend/seed"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	firebase "firebase.google.com/go/v4"
	"google.golang.org/api/option"
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
	db.AutoMigrate(&models.User{}, &models.Person{}, &models.Post{}, &models.Message{}, &models.Event{}, &models.Comment{}, &models.Reaction{})

	// Create uploads directory
	if _, err := os.Stat("uploads"); os.IsNotExist(err) {
		os.Mkdir("uploads", 0755)
	}

	// Initialize Firebase App
	var app *firebase.App

	// Try to load Firebase credentials from environment variable first, then file
	firebaseCreds := os.Getenv("FIREBASE_CREDENTIALS")
	if firebaseCreds != "" {
		opt := option.WithCredentialsJSON([]byte(firebaseCreds))
		app, err = firebase.NewApp(context.Background(), nil, opt)
		if err != nil {
			log.Printf("Warning: Failed to initialize Firebase from env: %v", err)
		} else {
			log.Println("Firebase initialized from environment variable")
		}
	} else if _, err := os.Stat("firebase-credentials.json"); err == nil {
		opt := option.WithCredentialsFile("firebase-credentials.json")
		app, err = firebase.NewApp(context.Background(), nil, opt)
		if err != nil {
			log.Printf("Warning: Failed to initialize Firebase from file: %v", err)
		} else {
			log.Println("Firebase initialized from credentials file")
		}
	} else {
		log.Println("Warning: No Firebase credentials found. Auth will be skipped.")
	}

	// Initialize Handlers
	authHandler := &handlers.AuthHandler{DB: db}
	personHandler := &handlers.PersonHandler{DB: db}
	uploadHandler := &handlers.UploadHandler{}
	postHandler := &handlers.PostHandler{DB: db}
	messageHandler := &handlers.MessageHandler{DB: db}
	eventHandler := &handlers.EventHandler{DB: db}

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
	r.Static("/uploads", "./uploads")
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "pong"})
	})

	// Public read-only access to persons (for demo mode)
	r.GET("/public/persons", personHandler.GetPersons)

	// Protected Routes (authenticated users)
	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware(app, db))
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

		// Person Routes - READ for all authenticated users
		api.GET("/persons", personHandler.GetPersons)
		api.GET("/persons/:id", personHandler.GetPerson)

		// Person UPDATE - users can update their own profile
		api.PUT("/persons/:id", personHandler.UpdatePersonWithPermission)

		// Upload Routes - all authenticated users can upload (for profile photos)
		api.POST("/upload", uploadHandler.UploadFile)

		// Post Routes - READ for all, reactions for all
		api.GET("/posts", postHandler.GetPosts)
		api.GET("/posts/:id/comments", postHandler.GetComments)
		api.POST("/posts/:id/reactions", postHandler.ToggleReaction)

		// Comments - all users can comment
		api.POST("/posts/:id/comments", postHandler.CreateComment)
		api.DELETE("/comments/:id", postHandler.DeleteComment)

		// Message Routes - all users can chat
		api.GET("/messages", messageHandler.GetMessages)
		api.POST("/messages", messageHandler.SendMessage)

		// Event Routes - READ for all, RSVP for all
		api.GET("/events", eventHandler.GetEvents)
		api.POST("/events/:id/rsvp", eventHandler.ToggleRSVP)
	}

	// Admin-only Routes
	admin := r.Group("/api/admin")
	admin.Use(middleware.AuthMiddleware(app, db))
	admin.Use(middleware.AdminMiddleware(db))
	{
		// Person management - CREATE, DELETE (admin only)
		admin.POST("/persons", personHandler.CreatePerson)
		admin.PUT("/persons/:id", personHandler.UpdatePerson)
		admin.DELETE("/persons/:id", personHandler.DeletePerson)

		// Post management - CREATE, DELETE (admin only)
		admin.POST("/posts", postHandler.CreatePost)
		admin.DELETE("/posts/:id", postHandler.DeletePost)

		// Event management - CREATE, DELETE (admin only)
		admin.POST("/events", eventHandler.CreateEvent)
		admin.DELETE("/events/:id", eventHandler.DeleteEvent)

		// User management
		admin.GET("/users", func(c *gin.Context) {
			var users []models.User
			if result := db.Find(&users); result.Error != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
				return
			}
			c.JSON(http.StatusOK, users)
		})

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

			user.Role = models.UserRole(req.Role)
			if result := db.Save(&user); result.Error != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
				return
			}

			c.JSON(http.StatusOK, user)
		})
	}

	// Start server
	log.Println("Server starting on :8080")
	r.Run(":8080")
}
