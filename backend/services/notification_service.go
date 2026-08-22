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

// NotificationService records what happened to a family member and, where a
// push channel is configured, delivers it to their devices too.
//
// The two halves are deliberately independent. The in-app record is what the
// notifications screen reads and is the thing a user actually relies on, so it
// is written whether or not push is available. FCM is an optional extra on top:
// with FirebaseApp unset the service still works, it just stays silent on the
// lock screen.
type NotificationService struct {
	DB          *gorm.DB
	FirebaseApp *firebase.App
	FCMClient   *messaging.Client
}

// NewNotificationService returns a service that records notifications in the
// database. Call EnableFCM to add push delivery.
func NewNotificationService(db *gorm.DB) *NotificationService {
	return &NotificationService{DB: db}
}

// EnableFCM attaches Firebase Cloud Messaging so notifications also reach
// devices. Returns an error if the app cannot produce a messaging client; the
// service stays usable for in-app notifications either way.
func (s *NotificationService) EnableFCM(app *firebase.App) error {
	if app == nil {
		return fmt.Errorf("firebase app is nil")
	}

	client, err := app.Messaging(context.Background())
	if err != nil {
		return fmt.Errorf("failed to get FCM client: %w", err)
	}

	s.FirebaseApp = app
	s.FCMClient = client
	return nil
}

// PushEnabled reports whether device delivery is configured.
func (s *NotificationService) PushEnabled() bool { return s.FCMClient != nil }

// SendNotification records a notification for one user and pushes it to their
// devices if push is configured.
func (s *NotificationService) SendNotification(
	userID string,
	notifType models.NotificationType,
	entityType string,
	entityID string,
	title string,
	body string,
	data map[string]string,
) error {
	return s.SendBatchNotifications(
		[]string{userID}, notifType, entityType, entityID, title, body, data)
}

// SendBatchNotifications records the same notification for many users in one
// insert, then pushes to each. Users who have switched this kind of
// notification off are skipped entirely.
func (s *NotificationService) SendBatchNotifications(
	userIDs []string,
	notifType models.NotificationType,
	entityType string,
	entityID string,
	title string,
	body string,
	data map[string]string,
) error {
	recipients := s.filterByPreference(userIDs, notifType)
	if len(recipients) == 0 {
		return nil
	}

	if data == nil {
		data = make(map[string]string)
	}
	data["type"] = string(notifType)
	data["entityType"] = entityType
	data["entityId"] = entityID

	payload := make(models.JSONMap, len(data))
	for k, v := range data {
		payload[k] = v
	}

	now := time.Now()
	records := make([]models.Notification, 0, len(recipients))
	for _, userID := range recipients {
		records = append(records, models.Notification{
			ID:         uuid.New().String(),
			UserID:     userID,
			Type:       notifType,
			EntityType: entityType,
			EntityID:   entityID,
			Title:      title,
			Body:       body,
			Data:       payload,
			SentAt:     now,
			CreatedAt:  now,
		})
	}

	if err := s.DB.Create(&records).Error; err != nil {
		// A failed insert is worth reporting: the caller's action succeeded but
		// nobody will be told about it.
		log.Printf("notifications: could not record %s for %d users: %v",
			notifType, len(records), err)
		return err
	}

	s.push(recipients, notifType, entityType, entityID, title, body, data)
	return nil
}

// SendPushOnly delivers to devices without leaving an entry in the
// notifications list. Used for chat, where one row per message would bury
// everything else in the list within a day.
func (s *NotificationService) SendPushOnly(
	userIDs []string,
	notifType models.NotificationType,
	entityType string,
	entityID string,
	title string,
	body string,
	data map[string]string,
) {
	if !s.PushEnabled() {
		return
	}

	recipients := s.filterByPreference(userIDs, notifType)
	if len(recipients) == 0 {
		return
	}

	if data == nil {
		data = make(map[string]string)
	}
	data["type"] = string(notifType)
	data["entityType"] = entityType
	data["entityId"] = entityID

	s.push(recipients, notifType, entityType, entityID, title, body, data)
}

// push delivers to every device of every recipient. Quiet hours are honoured
// here and only here: a notification that arrives at 3am should not buzz, but
// it should still be waiting in the list in the morning.
func (s *NotificationService) push(
	userIDs []string,
	notifType models.NotificationType,
	entityType string,
	entityID string,
	title string,
	body string,
	data map[string]string,
) {
	if !s.PushEnabled() {
		return
	}

	awake := make([]string, 0, len(userIDs))
	for _, userID := range userIDs {
		if !s.isQuietHours(userID) {
			awake = append(awake, userID)
		}
	}
	if len(awake) == 0 {
		return
	}

	var tokens []models.DeviceToken
	if err := s.DB.Where("user_id IN ?", awake).Find(&tokens).Error; err != nil {
		log.Printf("notifications: could not load device tokens: %v", err)
		return
	}

	ctx := context.Background()
	for _, token := range tokens {
		message := &messaging.Message{
			Notification: &messaging.Notification{Title: title, Body: body},
			Data:         data,
			Token:        token.Token,
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

		if _, err := s.FCMClient.Send(ctx, message); err != nil {
			// A token for an app that has been uninstalled or reinstalled will
			// never work again, so drop it rather than retrying it forever.
			if messaging.IsInvalidArgument(err) || messaging.IsUnregistered(err) {
				s.DB.Delete(&models.DeviceToken{}, "id = ?", token.ID)
				log.Printf("notifications: dropped dead device token for user %s", token.UserID)
			} else {
				log.Printf("notifications: push failed for user %s: %v", token.UserID, err)
			}
		}
	}
}

// filterByPreference drops users who have turned this kind of notification off.
// One query for the whole set: this runs on every post, and a family of any
// size would otherwise mean a query per member.
func (s *NotificationService) filterByPreference(
	userIDs []string,
	notifType models.NotificationType,
) []string {
	if len(userIDs) == 0 {
		return nil
	}

	var prefs []models.NotificationPreference
	s.DB.Where("user_id IN ?", userIDs).Find(&prefs)

	byUser := make(map[string]models.NotificationPreference, len(prefs))
	for _, p := range prefs {
		byUser[p.UserID] = p
	}

	allowed := make([]string, 0, len(userIDs))
	seen := make(map[string]bool, len(userIDs))
	for _, userID := range userIDs {
		if userID == "" || seen[userID] {
			continue
		}
		seen[userID] = true

		pref, hasPref := byUser[userID]
		// No saved preferences means everything is on, which is the default a
		// new member gets.
		if !hasPref || allowsType(pref, notifType) {
			allowed = append(allowed, userID)
		}
	}
	return allowed
}

func allowsType(pref models.NotificationPreference, notifType models.NotificationType) bool {
	switch notifType {
	case models.NotificationEventReminder, models.NotificationEventRSVP:
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
		// Announcements and anything new always go through.
		return true
	}
}

// ScheduleEventReminders creates the automatic reminders for an event: one the
// day before, one an hour before, for everyone attending.
func (s *NotificationService) ScheduleEventReminders(event *models.Event) error {
	if len(event.Attendees) == 0 {
		return nil
	}

	oneDayBefore := event.DateTime.Add(-24 * time.Hour)
	oneHourBefore := event.DateTime.Add(-1 * time.Hour)
	now := time.Now()

	reminders := make([]models.Reminder, 0, len(event.Attendees)*2)
	for _, attendeeID := range event.Attendees {
		if oneDayBefore.After(now) {
			reminders = append(reminders, models.Reminder{
				ID:            uuid.New().String(),
				UserID:        attendeeID,
				EntityType:    "event",
				EntityID:      event.ID,
				ScheduledTime: oneDayBefore,
				ReminderType:  models.ReminderTypeAuto,
				Title:         fmt.Sprintf("Tomorrow: %s", event.Title),
				Body: fmt.Sprintf("%s is tomorrow at %s", event.Title,
					event.DateTime.Format("3:04 PM")),
				CreatedAt: now,
				UpdatedAt: now,
			})
		}
		if oneHourBefore.After(now) {
			reminders = append(reminders, models.Reminder{
				ID:            uuid.New().String(),
				UserID:        attendeeID,
				EntityType:    "event",
				EntityID:      event.ID,
				ScheduledTime: oneHourBefore,
				ReminderType:  models.ReminderTypeAuto,
				Title:         fmt.Sprintf("In an hour: %s", event.Title),
				Body: fmt.Sprintf("%s starts at %s", event.Title,
					event.DateTime.Format("3:04 PM")),
				CreatedAt: now,
				UpdatedAt: now,
			})
		}
	}

	if len(reminders) == 0 {
		return nil
	}
	return s.DB.Create(&reminders).Error
}

// ProcessScheduledReminders delivers reminders as they come due. Run it once,
// in its own goroutine, for the lifetime of the process — without it a user can
// set a reminder and snooze it and never hear from it again.
func (s *NotificationService) ProcessScheduledReminders(every time.Duration) {
	if every <= 0 {
		every = time.Minute
	}

	log.Printf("reminders: checking every %s", every)
	ticker := time.NewTicker(every)
	defer ticker.Stop()

	for range ticker.C {
		s.deliverDueReminders(time.Now())
	}
}

// deliverDueReminders is the body of one tick, split out so it can be called
// directly rather than only from a ticker.
func (s *NotificationService) deliverDueReminders(now time.Time) int {
	var due []models.Reminder
	if err := s.DB.
		Where("is_sent = ?", false).
		Where("scheduled_time <= ?", now).
		Where("snooze_until IS NULL OR snooze_until <= ?", now).
		Find(&due).Error; err != nil {
		log.Printf("reminders: could not load due reminders: %v", err)
		return 0
	}

	sent := 0
	for _, reminder := range due {
		title, body := reminder.Title, reminder.Body

		// A reminder created against an entity may carry no wording of its own.
		if title == "" {
			switch reminder.EntityType {
			case "event":
				var event models.Event
				if s.DB.First(&event, "id = ?", reminder.EntityID).Error == nil {
					title = event.Title
					body = fmt.Sprintf("%s at %s", event.Title,
						event.DateTime.Format("Jan 2, 3:04 PM"))
				} else {
					// The event was cancelled; the reminder has nothing to say.
					s.DB.Delete(&models.Reminder{}, "id = ?", reminder.ID)
					continue
				}
			default:
				title = "Reminder"
			}
		}

		if err := s.SendNotification(
			reminder.UserID,
			models.NotificationEventReminder,
			reminder.EntityType,
			reminder.EntityID,
			title,
			body,
			nil,
		); err != nil {
			log.Printf("reminders: could not deliver %s: %v", reminder.ID, err)
			continue
		}

		// Marked sent only after delivery, so a failed run retries next tick
		// instead of silently dropping the reminder.
		s.DB.Model(&models.Reminder{}).
			Where("id = ?", reminder.ID).
			Updates(map[string]interface{}{"is_sent": true, "updated_at": now})
		sent++
	}

	if sent > 0 {
		log.Printf("reminders: delivered %d", sent)
	}
	return sent
}

// isQuietHours reports whether the user has asked not to be disturbed now.
func (s *NotificationService) isQuietHours(userID string) bool {
	var pref models.NotificationPreference
	if err := s.DB.Where("user_id = ?", userID).First(&pref).Error; err != nil {
		return false
	}

	if pref.QuietHoursStart == nil || pref.QuietHoursEnd == nil {
		return false
	}

	now := time.Now()
	current := now.Hour()*60 + now.Minute()
	start := pref.QuietHoursStart.Hour()*60 + pref.QuietHoursStart.Minute()
	end := pref.QuietHoursEnd.Hour()*60 + pref.QuietHoursEnd.Minute()

	// A window like 22:00–07:00 wraps past midnight.
	if start <= end {
		return current >= start && current <= end
	}
	return current >= start || current <= end
}
