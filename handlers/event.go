package handlers

import (
	"family-tree-backend/models"
	"family-tree-backend/services"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type EventHandler struct {
	DB                  *gorm.DB
	NotificationService *services.NotificationService
}

func (h *EventHandler) GetEvents(c *gin.Context) {
	var events []models.Event
	if result := h.DB.Order("date_time asc").Find(&events); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, events)
}

func (h *EventHandler) CreateEvent(c *gin.Context) {
	var event models.Event
	if err := c.ShouldBindJSON(&event); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	event.ID = uuid.New().String()
	event.CreatedAt = time.Now()
	event.UpdatedAt = time.Now()

	if result := h.DB.Create(&event); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// Schedule automatic reminders for attendees
	if h.NotificationService != nil && len(event.Attendees) > 0 {
		go h.NotificationService.ScheduleEventReminders(&event)
	}

	c.JSON(http.StatusCreated, event)
}

func (h *EventHandler) UpdateEvent(c *gin.Context) {
	id := c.Param("id")
	var req models.Event
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var event models.Event
	if result := h.DB.First(&event, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
		return
	}

	event.Title = req.Title
	event.Description = req.Description
	event.Location = req.Location
	event.MapLink = req.MapLink
	event.DateTime = req.DateTime
	event.UpdatedAt = time.Now()

	if result := h.DB.Save(&event); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// Delete old auto-reminders and create new ones if date/time changed
	if h.NotificationService != nil {
		go func() {
			h.DB.Where("entity_id = ? AND entity_type = ? AND reminder_type = ?",
				event.ID, "event", models.ReminderTypeAuto).Delete(&models.Reminder{})
			if len(event.Attendees) > 0 {
				h.NotificationService.ScheduleEventReminders(&event)
			}
		}()
	}

	c.JSON(http.StatusOK, event)
}

func (h *EventHandler) DeleteEvent(c *gin.Context) {
	id := c.Param("id")

	// Delete associated reminders first
	h.DB.Where("entity_id = ? AND entity_type = ?", id, "event").Delete(&models.Reminder{})

	if result := h.DB.Delete(&models.Event{}, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Event deleted"})
}

// ToggleRSVP toggles a user's attendance for an event
func (h *EventHandler) ToggleRSVP(c *gin.Context) {
	id := c.Param("id")

	var event models.Event
	if result := h.DB.First(&event, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
		return
	}

	// Get user ID from context (set by auth middleware)
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	userIDStr := userID.(string)

	// Check if user is already attending
	found := false
	newAttendees := []string{}
	for _, attendee := range event.Attendees {
		if attendee == userIDStr {
			found = true
			// Don't add this user (they're leaving)
		} else {
			newAttendees = append(newAttendees, attendee)
		}
	}

	if !found {
		// Add user to attendees
		newAttendees = append(newAttendees, userIDStr)
	}

	event.Attendees = newAttendees
	event.UpdatedAt = time.Now()

	if result := h.DB.Save(&event); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, event)
}
