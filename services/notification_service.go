package services

import (
	"context"
	"fmt"
	"log"
	"time"

	"family-tree-backend/models"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type NotificationService struct {
	DB          *gorm.DB
	FirebaseApp *firebase.App
	FCMClient   *messaging.Client
}

// NewNotificationService creates a new notification service
func NewNotificationService(db *gorm.DB, app *firebase.App) (*NotificationService, error) {
	if app == nil {
		return nil, fmt.Errorf("firebase app is nil")
	}

	ctx := context.Background()
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get FCM client: %w", err)
	}

	return &NotificationService{
		DB:          db,
		FirebaseApp: app,
		FCMClient:   client,
	}, nil
}

// SendNotification sends a notification to a specific user's devices
func (s *NotificationService) SendNotification(
	userID string,
	notifType models.NotificationType,
	entityType string,
	entityID string,
	title string,
	body string,
	data map[string]string,
) error {
	// Check user preferences
	if !s.shouldSendNotification(userID, notifType) {
		log.Printf("Notification blocked by user preferences: user=%s, type=%s", userID, notifType)
		return nil
	}

	// Check quiet hours
	if s.isQuietHours(userID) {
		log.Printf("Notification blocked by quiet hours: user=%s", userID)
		return nil
	}

	// Get user's device tokens
	var tokens []models.DeviceToken
	if err := s.DB.Where("user_id = ?", userID).Find(&tokens).Error; err != nil {
		return fmt.Errorf("failed to get device tokens: %w", err)
	}

	if len(tokens) == 0 {
		log.Printf("No device tokens found for user: %s", userID)
		return nil
	}

	// Prepare FCM data
	if data == nil {
		data = make(map[string]string)
	}
	data["type"] = string(notifType)
	data["entityType"] = entityType
	data["entityId"] = entityID

	// Send to each device
	ctx := context.Background()
	for _, token := range tokens {
		message := &messaging.Message{
			Notification: &messaging.Notification{
				Title: title,
				Body:  body,
			},
			Data:  data,
			Token: token.Token,
			Android: &messaging.AndroidConfig{
				Priority: "high",
				Notification: &messaging.AndroidNotification{
					Sound:        "default",
					ChannelID:    "family_tree_notifications",
					Priority:     messaging.PriorityHigh,
					DefaultSound: true,
				},
			},
		}

		_, err := s.FCMClient.Send(ctx, message)
		if err != nil {
			// If token is invalid, remove it
			if messaging.IsInvalidArgument(err) || messaging.IsUnregistered(err) {
				s.DB.Delete(&token)
				log.Printf("Removed invalid token for user %s", userID)
			} else {
				log.Printf("Failed to send notification to token %s: %v", token.Token[:10], err)
			}
		}
	}

	// Save notification to database
	// Convert map[string]string to map[string]interface{}
	jsonData := make(models.JSONMap)
	for k, v := range data {
		jsonData[k] = v
	}

	notification := models.Notification{
		ID:         uuid.New().String(),
		UserID:     userID,
		Type:       notifType,
		EntityType: entityType,
		EntityID:   entityID,
		Title:      title,
		Body:       body,
		Data:       jsonData,
		SentAt:     time.Now(),
		CreatedAt:  time.Now(),
	}

	if err := s.DB.Create(&notification).Error; err != nil {
		log.Printf("Failed to save notification to database: %v", err)
	}

	return nil
}

// SendBatchNotifications sends notifications to multiple users
func (s *NotificationService) SendBatchNotifications(
	userIDs []string,
	notifType models.NotificationType,
	entityType string,
	entityID string,
	title string,
	body string,
	data map[string]string,
) error {
	for _, userID := range userIDs {
		if err := s.SendNotification(userID, notifType, entityType, entityID, title, body, data); err != nil {
			log.Printf("Failed to send notification to user %s: %v", userID, err)
		}
	}
	return nil
}

// ScheduleEventReminders creates automatic reminders for an event
func (s *NotificationService) ScheduleEventReminders(event *models.Event) error {
	if len(event.Attendees) == 0 {
		return nil
	}

	// Schedule reminder for 24 hours before
	oneDayBefore := event.DateTime.Add(-24 * time.Hour)
	// Schedule reminder for 1 hour before
	oneHourBefore := event.DateTime.Add(-1 * time.Hour)

	now := time.Now()

	// Create reminders for each attendee
	for _, attendeeID := range event.Attendees {
		// 24-hour reminder
		if oneDayBefore.After(now) {
			reminder1 := models.Reminder{
				ID:            uuid.New().String(),
				UserID:        attendeeID,
				EntityType:    "event",
				EntityID:      event.ID,
				ScheduledTime: oneDayBefore,
				ReminderType:  models.ReminderTypeAuto,
				IsSent:        false,
				Title:         fmt.Sprintf("Event Tomorrow: %s", event.Title),
				Body:          fmt.Sprintf("%s is happening tomorrow at %s", event.Title, event.DateTime.Format("3:04 PM")),
				CreatedAt:     now,
				UpdatedAt:     now,
			}
			s.DB.Create(&reminder1)
		}

		// 1-hour reminder
		if oneHourBefore.After(now) {
			reminder2 := models.Reminder{
				ID:            uuid.New().String(),
				UserID:        attendeeID,
				EntityType:    "event",
				EntityID:      event.ID,
				ScheduledTime: oneHourBefore,
				ReminderType:  models.ReminderTypeAuto,
				IsSent:        false,
				Title:         fmt.Sprintf("Event in 1 Hour: %s", event.Title),
				Body:          fmt.Sprintf("%s starts in 1 hour at %s", event.Title, event.DateTime.Format("3:04 PM")),
				CreatedAt:     now,
				UpdatedAt:     now,
			}
			s.DB.Create(&reminder2)
		}
	}

	return nil
}

// ProcessScheduledReminders is a background worker that sends due reminders
func (s *NotificationService) ProcessScheduledReminders() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		now := time.Now()

		var dueReminders []models.Reminder
		s.DB.Where("is_sent = ? AND scheduled_time <= ?", false, now).
			Where("snooze_until IS NULL OR snooze_until <= ?", now).
			Find(&dueReminders)

		for _, reminder := range dueReminders {
			// Get entity details based on type
			var title, body string
			if reminder.Title != "" && reminder.Body != "" {
				title = reminder.Title
				body = reminder.Body
			} else {
				// Fetch from entity
				switch reminder.EntityType {
				case "event":
					var event models.Event
					if s.DB.First(&event, "id = ?", reminder.EntityID).Error == nil {
						title = fmt.Sprintf("Event Reminder: %s", event.Title)
						body = fmt.Sprintf("%s at %s", event.Title, event.DateTime.Format("Jan 2, 3:04 PM"))
					}
				}
			}

			// Send notification
			err := s.SendNotification(
				reminder.UserID,
				models.NotificationEventReminder,
				reminder.EntityType,
				reminder.EntityID,
				title,
				body,
				nil,
			)

			if err != nil {
				log.Printf("Failed to send reminder %s: %v", reminder.ID, err)
			} else {
				// Mark as sent
				reminder.IsSent = true
				reminder.UpdatedAt = now
				s.DB.Save(&reminder)
			}
		}
	}
}

// shouldSendNotification checks user preferences
func (s *NotificationService) shouldSendNotification(userID string, notifType models.NotificationType) bool {
	var pref models.NotificationPreference
	if err := s.DB.Where("user_id = ?", userID).First(&pref).Error; err != nil {
		// No preferences found, allow all by default
		return true
	}

	switch notifType {
	case models.NotificationEventReminder:
		return pref.EventsEnabled
	case models.NotificationNewPost:
		return pref.PostsEnabled
	case models.NotificationNewMessage:
		return pref.MessagesEnabled
	case models.NotificationNewComment:
		return pref.CommentsEnabled
	case models.NotificationMention:
		return pref.MentionsEnabled
	default:
		return true
	}
}

// isQuietHours checks if current time is in user's quiet hours
func (s *NotificationService) isQuietHours(userID string) bool {
	var pref models.NotificationPreference
	if err := s.DB.Where("user_id = ?", userID).First(&pref).Error; err != nil {
		return false
	}

	if pref.QuietHoursStart == nil || pref.QuietHoursEnd == nil {
		return false
	}

	now := time.Now()
	currentTime := now.Hour()*60 + now.Minute()

	startTime := pref.QuietHoursStart.Hour()*60 + pref.QuietHoursStart.Minute()
	endTime := pref.QuietHoursEnd.Hour()*60 + pref.QuietHoursEnd.Minute()

	// Handle case where quiet hours span midnight
	if startTime <= endTime {
		return currentTime >= startTime && currentTime <= endTime
	}
	return currentTime >= startTime || currentTime <= endTime
}
