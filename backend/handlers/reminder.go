package handlers

import (
	"family-tree-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ReminderHandler struct {
	DB *gorm.DB
}

// GetReminders retrieves all reminders for the current user
func (h *ReminderHandler) GetReminders(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var reminders []models.Reminder
	if err := h.DB.Where("user_id = ? AND is_sent = ?", userID.(string), false).
		Order("scheduled_time ASC").
		Find(&reminders).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, reminders)
}

// CreateReminder creates a custom reminder
func (h *ReminderHandler) CreateReminder(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var req struct {
		EntityType    string    `json:"entityType" binding:"required"`
		EntityID      string    `json:"entityId" binding:"required"`
		ScheduledTime time.Time `json:"scheduledTime" binding:"required"`
		Title         string    `json:"title" binding:"required"`
		Body          string    `json:"body"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	reminder := models.Reminder{
		ID:            uuid.New().String(),
		UserID:        userID.(string),
		EntityType:    req.EntityType,
		EntityID:      req.EntityID,
		ScheduledTime: req.ScheduledTime,
		ReminderType:  models.ReminderTypeCustom,
		IsSent:        false,
		Title:         req.Title,
		Body:          req.Body,
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}

	if err := h.DB.Create(&reminder).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, reminder)
}

// SnoozeReminder snoozes a reminder for a specified duration
func (h *ReminderHandler) SnoozeReminder(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	reminderID := c.Param("id")

	var req struct {
		Duration int `json:"duration" binding:"required"` // Duration in minutes
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var reminder models.Reminder
	if err := h.DB.Where("id = ? AND user_id = ?", reminderID, userID.(string)).
		First(&reminder).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Reminder not found"})
		return
	}

	snoozeUntil := time.Now().Add(time.Duration(req.Duration) * time.Minute)
	reminder.SnoozeUntil = &snoozeUntil
	reminder.IsSent = false // Reset in case it was marked as sent
	reminder.UpdatedAt = time.Now()

	if err := h.DB.Save(&reminder).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, reminder)
}

// DeleteReminder deletes a reminder
func (h *ReminderHandler) DeleteReminder(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	reminderID := c.Param("id")

	result := h.DB.Where("id = ? AND user_id = ?", reminderID, userID.(string)).
		Delete(&models.Reminder{})

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Reminder not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Reminder deleted"})
}

// UpdateReminder updates a custom reminder
func (h *ReminderHandler) UpdateReminder(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	reminderID := c.Param("id")

	var req struct {
		ScheduledTime *time.Time `json:"scheduledTime"`
		Title         *string    `json:"title"`
		Body          *string    `json:"body"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var reminder models.Reminder
	if err := h.DB.Where("id = ? AND user_id = ?", reminderID, userID.(string)).
		First(&reminder).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Reminder not found"})
		return
	}

	// Only allow updating custom reminders
	if reminder.ReminderType != models.ReminderTypeCustom {
		c.JSON(http.StatusForbidden, gin.H{"error": "Cannot update auto-generated reminders"})
		return
	}

	// Update fields if provided
	if req.ScheduledTime != nil {
		reminder.ScheduledTime = *req.ScheduledTime
	}
	if req.Title != nil {
		reminder.Title = *req.Title
	}
	if req.Body != nil {
		reminder.Body = *req.Body
	}
	reminder.UpdatedAt = time.Now()

	if err := h.DB.Save(&reminder).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, reminder)
}
