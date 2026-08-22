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

// UpdatePreferences updates notification preferences for the current user.
//
// Two details matter here and both used to be wrong.
//
// The booleans are pointers, so a request that mentions only one switch leaves
// the others alone instead of resetting them to false.
//
// The write goes through Updates with an explicit column map rather than Save.
// Every one of these columns is declared `default:true`, and GORM omits a
// false-valued field on insert when a default exists — so letting it build the
// statement meant turning a notification off silently stored "on", and the
// switch sprang back the next time the screen loaded.
func (h *NotificationHandler) UpdatePreferences(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var req struct {
		EventsEnabled   *bool      `json:"eventsEnabled"`
		PostsEnabled    *bool      `json:"postsEnabled"`
		MessagesEnabled *bool      `json:"messagesEnabled"`
		CommentsEnabled *bool      `json:"commentsEnabled"`
		MentionsEnabled *bool      `json:"mentionsEnabled"`
		QuietHoursStart *time.Time `json:"quietHoursStart"`
		QuietHoursEnd   *time.Time `json:"quietHoursEnd"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var pref models.NotificationPreference
	err := h.DB.Where("user_id = ?", userID.(string)).First(&pref).Error

	if err == gorm.ErrRecordNotFound {
		// Everything on, which is what a member who has never opened the
		// settings implicitly has.
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
		if err := h.DB.Create(&pref).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	changes := map[string]interface{}{"updated_at": time.Now()}
	if req.EventsEnabled != nil {
		changes["events_enabled"] = *req.EventsEnabled
	}
	if req.PostsEnabled != nil {
		changes["posts_enabled"] = *req.PostsEnabled
	}
	if req.MessagesEnabled != nil {
		changes["messages_enabled"] = *req.MessagesEnabled
	}
	if req.CommentsEnabled != nil {
		changes["comments_enabled"] = *req.CommentsEnabled
	}
	if req.MentionsEnabled != nil {
		changes["mentions_enabled"] = *req.MentionsEnabled
	}
	// Quiet hours are cleared by sending null, so these are always written.
	changes["quiet_hours_start"] = req.QuietHoursStart
	changes["quiet_hours_end"] = req.QuietHoursEnd

	if err := h.DB.Model(&models.NotificationPreference{}).
		Where("id = ?", pref.ID).Updates(changes).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	h.DB.First(&pref, "id = ?", pref.ID)
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

// DeleteNotification removes one of the caller's own notifications. Scoping the
// lookup by user id means a notification that is not yours reads as missing
// rather than as a refusal, which is also what the swipe-to-dismiss gesture in
// the app expects.
func (h *NotificationHandler) DeleteNotification(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	notifID := c.Param("id")

	result := h.DB.Where("id = ? AND user_id = ?", notifID, userID.(string)).
		Delete(&models.Notification{})
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notification deleted", "id": notifID})
}

// DeleteAllNotifications clears the caller's whole list.
func (h *NotificationHandler) DeleteAllNotifications(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	result := h.DB.Where("user_id = ?", userID.(string)).Delete(&models.Notification{})
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notifications cleared", "count": result.RowsAffected})
}
