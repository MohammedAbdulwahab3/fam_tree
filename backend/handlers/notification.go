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

// defaultPreference is what a member who has never opened the settings screen
// implicitly has: everything on.
func defaultPreference(userID string) models.NotificationPreference {
	now := time.Now()
	return models.NotificationPreference{
		ID:              uuid.New().String(),
		UserID:          userID,
		PostsEnabled:    true,
		CommentsEnabled: true,
		MentionsEnabled: true,
		CreatedAt:       now,
		UpdatedAt:       now,
	}
}

// GetNotifications retrieves the caller's notifications, newest first.
func (h *NotificationHandler) GetNotifications(c *gin.Context) {
	userID := c.GetString("userID")

	var notifications []models.Notification
	if err := h.DB.Where("user_id = ?", userID).
		Order("created_at DESC").
		Limit(100).
		Find(&notifications).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, notifications)
}

// MarkAsRead marks one of the caller's notifications as read.
func (h *NotificationHandler) MarkAsRead(c *gin.Context) {
	userID := c.GetString("userID")
	notifID := c.Param("id")

	var notification models.Notification
	if err := h.DB.Where("id = ? AND user_id = ?", notifID, userID).
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

// MarkAllAsRead marks all of the caller's notifications as read.
func (h *NotificationHandler) MarkAllAsRead(c *gin.Context) {
	userID := c.GetString("userID")

	if err := h.DB.Model(&models.Notification{}).
		Where("user_id = ? AND read_at IS NULL", userID).
		Update("read_at", time.Now()).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "All notifications marked as read"})
}

// GetPreferences retrieves the caller's notification preferences, creating the
// all-on default row on first read.
func (h *NotificationHandler) GetPreferences(c *gin.Context) {
	userID := c.GetString("userID")

	var pref models.NotificationPreference
	err := h.DB.Where("user_id = ?", userID).First(&pref).Error

	if err == gorm.ErrRecordNotFound {
		pref = defaultPreference(userID)
		h.DB.Create(&pref)
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, pref)
}

// UpdatePreferences updates the caller's notification preferences.
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
	userID := c.GetString("userID")

	var req struct {
		PostsEnabled    *bool `json:"postsEnabled"`
		CommentsEnabled *bool `json:"commentsEnabled"`
		MentionsEnabled *bool `json:"mentionsEnabled"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var pref models.NotificationPreference
	err := h.DB.Where("user_id = ?", userID).First(&pref).Error

	if err == gorm.ErrRecordNotFound {
		pref = defaultPreference(userID)
		if err := h.DB.Create(&pref).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	changes := map[string]interface{}{"updated_at": time.Now()}
	if req.PostsEnabled != nil {
		changes["posts_enabled"] = *req.PostsEnabled
	}
	if req.CommentsEnabled != nil {
		changes["comments_enabled"] = *req.CommentsEnabled
	}
	if req.MentionsEnabled != nil {
		changes["mentions_enabled"] = *req.MentionsEnabled
	}

	if err := h.DB.Model(&models.NotificationPreference{}).
		Where("id = ?", pref.ID).Updates(changes).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	h.DB.First(&pref, "id = ?", pref.ID)
	c.JSON(http.StatusOK, pref)
}

// GetUnreadCount returns the count of the caller's unread notifications.
func (h *NotificationHandler) GetUnreadCount(c *gin.Context) {
	userID := c.GetString("userID")

	var count int64
	if err := h.DB.Model(&models.Notification{}).
		Where("user_id = ? AND read_at IS NULL", userID).
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
	userID := c.GetString("userID")
	notifID := c.Param("id")

	result := h.DB.Where("id = ? AND user_id = ?", notifID, userID).
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
	userID := c.GetString("userID")

	result := h.DB.Where("user_id = ?", userID).Delete(&models.Notification{})
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notifications cleared", "count": result.RowsAffected})
}
