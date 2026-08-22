package models

import (
	"time"

	"gorm.io/gorm"
)

type LinkRequestStatus string

const (
	LinkStatusPending  LinkRequestStatus = "pending"
	LinkStatusApproved LinkRequestStatus = "approved"
	LinkStatusRejected LinkRequestStatus = "rejected"
)

type LinkRequest struct {
	ID           string            `gorm:"primaryKey" json:"id"`
	UserID       string            `gorm:"index" json:"userId"`
	PersonID     string            `gorm:"index" json:"personId"`
	FamilyTreeID string            `json:"familyTreeId"`
	Status       LinkRequestStatus `gorm:"default:pending" json:"status"`
	RequestedAt  time.Time         `json:"requestedAt"`
	ProcessedAt  *time.Time        `json:"processedAt,omitempty"`
	ProcessedBy  string            `json:"processedBy,omitempty"` // Admin User ID
	CreatedAt    time.Time         `json:"createdAt"`
	UpdatedAt    time.Time         `json:"updatedAt"`
	DeletedAt    gorm.DeletedAt    `gorm:"index" json:"-"`
}
