package handlers

import (
	"family-tree-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type NotificationHandler struct {
	DB *gorm.DB
}

// RegisterDeviceToken registers a new FCM device token for a user
func (h *NotificationHandler) RegisterDeviceToken(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var req struct {
		Token    string `json:"token" binding:"required"`
		Platform string `json:"platform" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if token already exists
	var existingToken models.DeviceToken
	result := h.DB.Where("token = ?", req.Token).First(&existingToken)

	if result.Error == nil {
		// Update existing token
		existingToken.UserID = userID.(string)
		existingToken.Platform = req.Platform
		existingToken.LastUpdated = time.Now()
		h.DB.Save(&existingToken)
		c.JSON(http.StatusOK, existingToken)
		return
	}

	// Create new token
	token := models.DeviceToken{
		ID:          uuid.New().String(),
		UserID:      userID.(string),
		Token:       req.Token,
		Platform:    req.Platform,
		LastUpdated: time.Now(),
		CreatedAt:   time.Now(),
	}

	if err := h.DB.Create(&token).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, token)
}

// GetNotifications retrieves all notifications for the current user
func (h *NotificationHandler) GetNotifications(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var notifications []models.Notification
	if err := h.DB.Where("user_id = ?", userID.(string)).
		Order("created_at DESC").
		Limit(100).
		Find(&notifications).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, notifications)
}

// MarkAsRead marks a notification as read
func (h *NotificationHandler) MarkAsRead(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	notifID := c.Param("id")

	var notification models.Notification
	if err := h.DB.Where("id = ? AND user_id = ?", notifID, userID.(string)).
		First(&notification).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
		return
	}

	now := time.Now()
	notification.ReadAt = &now

	if err := h.DB.Save(&notification).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, notification)
}

// MarkAllAsRead marks all notifications as read for the current user
func (h *NotificationHandler) MarkAllAsRead(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	now := time.Now()
	if err := h.DB.Model(&models.Notification{}).
		Where("user_id = ? AND read_at IS NULL", userID.(string)).
		Update("read_at", now).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "All notifications marked as read"})
}

// GetPreferences retrieves notification preferences for the current user
func (h *NotificationHandler) GetPreferences(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var pref models.NotificationPreference
	err := h.DB.Where("user_id = ?", userID.(string)).First(&pref).Error

	if err == gorm.ErrRecordNotFound {
		// Create default preferences
		pref = models.NotificationPreference{
			ID:              uuid.New().String(),
			UserID:          userID.(string),
			EventsEnabled:   true,
			PostsEnabled:    true,
			MessagesEnabled: true,
			CommentsEnabled: true,
			MentionsEnabled: true,
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}
		h.DB.Create(&pref)
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, pref)
}

// UpdatePreferences updates notification preferences for the current user
func (h *NotificationHandler) UpdatePreferences(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var req models.NotificationPreference
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var pref models.NotificationPreference
	err := h.DB.Where("user_id = ?", userID.(string)).First(&pref).Error

	if err == gorm.ErrRecordNotFound {
		// Create new preferences
		pref = models.NotificationPreference{
			ID:     uuid.New().String(),
			UserID: userID.(string),
		}
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Update fields
	pref.EventsEnabled = req.EventsEnabled
	pref.PostsEnabled = req.PostsEnabled
	pref.MessagesEnabled = req.MessagesEnabled
	pref.CommentsEnabled = req.CommentsEnabled
	pref.MentionsEnabled = req.MentionsEnabled
	pref.QuietHoursStart = req.QuietHoursStart
	pref.QuietHoursEnd = req.QuietHoursEnd
	pref.UpdatedAt = time.Now()

	if err := h.DB.Save(&pref).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, pref)
}

// GetUnreadCount returns the count of unread notifications
func (h *NotificationHandler) GetUnreadCount(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var count int64
	if err := h.DB.Model(&models.Notification{}).
		Where("user_id = ? AND read_at IS NULL", userID.(string)).
		Count(&count).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"count": count})
}
