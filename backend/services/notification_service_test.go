package services

import (
	"testing"

	"family-tree-backend/models"

	"github.com/glebarez/sqlite"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func newDB(t *testing.T) *gorm.DB {
	t.Helper()

	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test database: %v", err)
	}
	if err := db.AutoMigrate(&models.Notification{}, &models.NotificationPreference{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func countFor(t *testing.T, db *gorm.DB, userID string) int64 {
	t.Helper()
	var n int64
	db.Model(&models.Notification{}).Where("user_id = ?", userID).Count(&n)
	return n
}

func TestRecordsOneNotificationPerRecipient(t *testing.T) {
	db := newDB(t)
	s := NewNotificationService(db)

	if err := s.SendBatchNotifications(
		[]string{"a", "b", "c"}, models.NotificationNewPost,
		"post", "p1", "New post", "body", nil); err != nil {
		t.Fatalf("send: %v", err)
	}

	var total int64
	db.Model(&models.Notification{}).Count(&total)
	if total != 3 {
		t.Fatalf("expected 3 notifications, got %d", total)
	}
}

// A member who has switched posts off should not get one.
func TestHonoursPreferences(t *testing.T) {
	db := newDB(t)
	s := NewNotificationService(db)

	db.Create(&models.NotificationPreference{
		ID: uuid.New().String(), UserID: "quiet",
		PostsEnabled: false, CommentsEnabled: true, MentionsEnabled: true,
	})

	s.SendBatchNotifications([]string{"quiet", "loud"},
		models.NotificationNewPost, "post", "p1", "New post", "body", nil)

	if got := countFor(t, db, "quiet"); got != 0 {
		t.Errorf("the opted-out member got %d notifications", got)
	}
	if got := countFor(t, db, "loud"); got != 1 {
		t.Errorf("the opted-in member got %d notifications", got)
	}
}

// Announcements are how an admin reaches everybody, so a preference row must
// not silently swallow one.
func TestAnnouncementsIgnorePreferences(t *testing.T) {
	db := newDB(t)
	s := NewNotificationService(db)

	db.Create(&models.NotificationPreference{
		ID: uuid.New().String(), UserID: "quiet",
		PostsEnabled: false, CommentsEnabled: false, MentionsEnabled: false,
	})

	s.SendNotification("quiet", models.NotificationAnnouncement,
		"announcement", "a1", "Reunion", "Saturday", nil)

	if got := countFor(t, db, "quiet"); got != 1 {
		t.Fatalf("expected the announcement through, got %d", got)
	}
}

// No preference row at all means a new member who has never opened settings.
func TestNoPreferenceRowMeansEverythingOn(t *testing.T) {
	db := newDB(t)
	s := NewNotificationService(db)

	s.SendNotification("newcomer", models.NotificationNewComment,
		"post", "p1", "Comment", "body", nil)

	if got := countFor(t, db, "newcomer"); got != 1 {
		t.Fatalf("expected 1 notification, got %d", got)
	}
}

func TestDeduplicatesAndDropsBlankRecipients(t *testing.T) {
	db := newDB(t)
	s := NewNotificationService(db)

	s.SendBatchNotifications([]string{"a", "a", "", "b"},
		models.NotificationNewPost, "post", "p1", "New post", "body", nil)

	var total int64
	db.Model(&models.Notification{}).Count(&total)
	if total != 2 {
		t.Fatalf("expected 2 notifications, got %d", total)
	}
}

func TestEmptyRecipientListIsNotAnError(t *testing.T) {
	db := newDB(t)
	s := NewNotificationService(db)

	if err := s.SendBatchNotifications(nil,
		models.NotificationNewPost, "post", "p1", "t", "b", nil); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}

func TestCarriesDeepLinkData(t *testing.T) {
	db := newDB(t)
	s := NewNotificationService(db)

	s.SendNotification("a", models.NotificationMention, "comment", "c1",
		"Mentioned", "body", map[string]string{"postId": "p1"})

	var saved models.Notification
	db.First(&saved)
	if saved.Data["postId"] != "p1" {
		t.Errorf("postId missing from payload: %v", saved.Data)
	}
	if saved.Data["entityId"] != "c1" || saved.Data["entityType"] != "comment" {
		t.Errorf("entity missing from payload: %v", saved.Data)
	}
}
