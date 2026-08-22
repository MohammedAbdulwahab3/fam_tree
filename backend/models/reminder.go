package models

import (
	"time"

	"gorm.io/gorm"
)

// ReminderType represents whether a reminder was auto-created or user-created
type ReminderType string

const (
	ReminderTypeAuto   ReminderType = "auto"   // Auto-created (e.g., event reminders)
	ReminderTypeCustom ReminderType = "custom" // User-created custom reminder
)

// Reminder represents a scheduled notification reminder
type Reminder struct {
	ID            string         `gorm:"primaryKey" json:"id"`
	UserID        string         `gorm:"index" json:"userId"`
	EntityType    string         `json:"entityType"` // event, post, message
	EntityID      string         `json:"entityId"`
	ScheduledTime time.Time      `gorm:"index" json:"scheduledTime"` // When to send the reminder
	SnoozeUntil   *time.Time     `json:"snoozeUntil"`                // If snoozed, send after this time
	ReminderType  ReminderType   `json:"reminderType"`               // auto or custom
	IsSent        bool           `gorm:"default:false" json:"isSent"`
	Title         string         `json:"title"`
	Body          string         `json:"body"`
	CreatedAt     time.Time      `json:"createdAt"`
	UpdatedAt     time.Time      `json:"updatedAt"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`
}
