package services

import (
	"log"
	"time"

	"family-tree-backend/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// NotificationService records what happened to a family member so the app's
// notifications screen can show it.
//
// There is no device-push channel. The app polls, so a row in the notifications
// table is the entire delivery mechanism — which means this service has exactly
// one job and no external dependency to fail.
type NotificationService struct {
	DB *gorm.DB
}

// NewNotificationService returns a service that records notifications.
func NewNotificationService(db *gorm.DB) *NotificationService {
	return &NotificationService{DB: db}
}

// SendNotification records a notification for one user.
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
// insert. Users who have switched this kind of notification off are skipped.
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

	return nil
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
	case models.NotificationNewPost:
		return pref.PostsEnabled
	case models.NotificationNewComment:
		return pref.CommentsEnabled
	case models.NotificationMention:
		return pref.MentionsEnabled
	default:
		// Announcements and anything new always go through.
		return true
	}
}
