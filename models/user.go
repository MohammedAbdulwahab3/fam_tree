package models

import (
	"time"

	"gorm.io/gorm"
)

// UserRole defines the role of a user
type UserRole string

const (
	RoleAdmin  UserRole = "admin"
	RoleMember UserRole = "member"
)

type User struct {
	ID           string         `gorm:"primaryKey" json:"id"`
	Email        string         `gorm:"uniqueIndex" json:"email"`
	Password     string         `json:"-"` // Don't return password in JSON
	Name         string         `json:"name"`
	Role         UserRole       `gorm:"default:member" json:"role"`
	IsVerified   bool           `gorm:"default:false" json:"isVerified"`
	FamilyTreeID string         `json:"familyTreeId"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

// IsAdmin checks if user has admin role
func (u *User) IsAdmin() bool {
	return u.Role == RoleAdmin
}
