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

	// Why an admin turned the claim down, in their own words. Without this a
	// rejected member sees only that they are still unlinked, has no idea what
	// went wrong, and re-submits the same claim indefinitely.
	Reason    string         `json:"reason,omitempty"`
	CreatedAt time.Time      `json:"createdAt"`
	UpdatedAt time.Time      `json:"updatedAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}
