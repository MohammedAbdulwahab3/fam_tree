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
	NotificationNewPost      NotificationType = "new_post"
	NotificationNewComment   NotificationType = "new_comment"
	NotificationMention      NotificationType = "mention"
	NotificationAnnouncement NotificationType = "announcement"
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

// Notification represents a notification sent to a user.
//
// Notifications are recorded here and read by the app's notifications screen.
// There is no device-push channel: the app polls, so a row in this table is the
// whole delivery mechanism.
type Notification struct {
	ID         string           `gorm:"primaryKey" json:"id"`
	UserID     string           `gorm:"index" json:"userId"`
	Type       NotificationType `json:"type"`
	EntityType string           `json:"entityType"` // post, comment, link_request, announcement
	EntityID   string           `json:"entityId"`
	Title      string           `json:"title"`
	Body       string           `json:"body"`
	Data       JSONMap          `gorm:"type:jsonb" json:"data"` // Additional data for deep linking
	SentAt     time.Time        `json:"sentAt"`
	ReadAt     *time.Time       `json:"readAt"`
	CreatedAt  time.Time        `json:"createdAt"`
	DeletedAt  gorm.DeletedAt   `gorm:"index" json:"-"`
}

// NotificationPreference represents a user's notification settings.
//
// The switches deliberately carry no `default:true` tag. GORM omits a
// false-valued field from an INSERT when the column has a default, so a row
// built in Go with a switch turned off was stored with it turned on — which is
// why turning a notification off used to spring back the next time the settings
// screen loaded. The all-on default a new member gets is set explicitly in
// handlers.defaultPreference instead, where it is visible.
type NotificationPreference struct {
	ID              string         `gorm:"primaryKey" json:"id"`
	UserID          string         `gorm:"uniqueIndex" json:"userId"`
	PostsEnabled    bool           `json:"postsEnabled"`
	CommentsEnabled bool           `json:"commentsEnabled"`
	MentionsEnabled bool           `json:"mentionsEnabled"`
	CreatedAt       time.Time      `json:"createdAt"`
	UpdatedAt       time.Time      `json:"updatedAt"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}
