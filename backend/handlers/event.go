package handlers

import (
	"family-tree-backend/models"
	"family-tree-backend/services"
	"net/http"
	"strings"
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

// canManageEvent reports whether the caller may change this event. Whoever
// created it can; so can any admin. Anyone else gets a clear refusal instead of
// a silent no-op.
func canManageEvent(c *gin.Context, event models.Event) (models.User, bool) {
	caller, ok := callerOf(c)
	if !ok {
		return models.User{}, false
	}
	return caller, caller.IsAdmin() || event.CreatedBy == caller.ID
}

// CreateEvent serves both the member route and the admin route. The organiser
// is taken from the verified token so an event always has a real owner who can
// edit or cancel it later.
func (h *EventHandler) CreateEvent(c *gin.Context) {
	caller, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	var event models.Event
	if err := c.ShouldBindJSON(&event); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if strings.TrimSpace(event.Title) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Give the event a title"})
		return
	}
	if event.DateTime.IsZero() {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Choose a date and time"})
		return
	}

	event.ID = uuid.New().String()
	event.CreatedBy = caller.ID
	if event.FamilyTreeID == "" {
		event.FamilyTreeID = caller.FamilyTreeID
	}
	// The organiser is attending their own event unless the client said
	// otherwise, so the list is never empty on creation.
	if len(event.Attendees) == 0 {
		event.Attendees = models.JSONStringArray{caller.ID}
	}
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

	if _, allowed := canManageEvent(c, event); !allowed {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "Only the organiser or an admin can change this event",
		})
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

	var event models.Event
	if err := h.DB.First(&event, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
		return
	}

	if _, allowed := canManageEvent(c, event); !allowed {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "Only the organiser or an admin can cancel this event",
		})
		return
	}

	// Delete associated reminders first
	h.DB.Where("entity_id = ? AND entity_type = ?", id, "event").Delete(&models.Reminder{})

	if result := h.DB.Delete(&models.Event{}, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Event deleted", "id": id})
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
