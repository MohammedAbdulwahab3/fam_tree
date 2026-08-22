package models

import (
	"database/sql/driver"
	"encoding/json"
	"time"

	"gorm.io/gorm"
)

// NotificationType represents different types of notifications
type NotificationType string

const (
	NotificationEventReminder NotificationType = "event_reminder"
	NotificationNewPost       NotificationType = "new_post"
	NotificationNewComment    NotificationType = "new_comment"
	NotificationNewMessage    NotificationType = "new_message"
	NotificationEventRSVP     NotificationType = "event_rsvp"
	NotificationMention       NotificationType = "mention"
)

// JSONMap is a custom type for storing JSON data
type JSONMap map[string]interface{}

// Scan implements the sql.Scanner interface
func (j *JSONMap) Scan(value interface{}) error {
	if value == nil {
		*j = make(JSONMap)
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return nil
	}
	return json.Unmarshal(bytes, j)
}

// Value implements the driver.Valuer interface
func (j JSONMap) Value() (driver.Value, error) {
	if j == nil {
		return nil, nil
	}
	return json.Marshal(j)
}

// Notification represents a notification sent to a user
type Notification struct {
	ID         string           `gorm:"primaryKey" json:"id"`
	UserID     string           `gorm:"index" json:"userId"`
	Type       NotificationType `json:"type"`
	EntityType string           `json:"entityType"` // event, post, message
	EntityID   string           `json:"entityId"`
	Title      string           `json:"title"`
	Body       string           `json:"body"`
	Data       JSONMap          `gorm:"type:jsonb" json:"data"` // Additional data for deep linking
	SentAt     time.Time        `json:"sentAt"`
	ReadAt     *time.Time       `json:"readAt"`
	CreatedAt  time.Time        `json:"createdAt"`
	DeletedAt  gorm.DeletedAt   `gorm:"index" json:"-"`
}

// DeviceToken represents a user's FCM device token
type DeviceToken struct {
	ID          string         `gorm:"primaryKey" json:"id"`
	UserID      string         `gorm:"index" json:"userId"`
	Token       string         `gorm:"uniqueIndex" json:"token"`
	Platform    string         `json:"platform"` // android, ios, web
	LastUpdated time.Time      `json:"lastUpdated"`
	CreatedAt   time.Time      `json:"createdAt"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
}

// NotificationPreference represents user's notification settings
type NotificationPreference struct {
	ID              string         `gorm:"primaryKey" json:"id"`
	UserID          string         `gorm:"uniqueIndex" json:"userId"`
	EventsEnabled   bool           `gorm:"default:true" json:"eventsEnabled"`
	PostsEnabled    bool           `gorm:"default:true" json:"postsEnabled"`
	MessagesEnabled bool           `gorm:"default:true" json:"messagesEnabled"`
	CommentsEnabled bool           `gorm:"default:true" json:"commentsEnabled"`
	MentionsEnabled bool           `gorm:"default:true" json:"mentionsEnabled"`
	QuietHoursStart *time.Time     `json:"quietHoursStart"` // Time of day (only hour and minute matter)
	QuietHoursEnd   *time.Time     `json:"quietHoursEnd"`
	CreatedAt       time.Time      `json:"createdAt"`
	UpdatedAt       time.Time      `json:"updatedAt"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}
