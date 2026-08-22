package models

import (
	"time"

	"gorm.io/gorm"
)

// PasswordReset is a one-time code that lets someone who has lost their
// password set a new one.
//
// There is no mail server in this deployment, so a code is not emailed — an
// admin issues it and passes it on however they normally reach that relative.
// That fits how a family tree is actually administered: the admin knows who
// everyone is and can confirm identity by simply recognising them.
type PasswordReset struct {
	ID     string `gorm:"primaryKey" json:"id"`
	UserID string `gorm:"index" json:"userId"`

	// The code the member types in. Short enough to read down a phone line.
	Code string `gorm:"index" json:"code"`

	// Which admin issued it, so an unexpected reset can be traced.
	IssuedBy  string    `json:"issuedBy"`
	ExpiresAt time.Time `json:"expiresAt"`

	// Set the moment it is spent. A code is good for exactly one reset.
	UsedAt *time.Time `json:"usedAt,omitempty"`

	CreatedAt time.Time      `json:"createdAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

// IsUsable reports whether this code can still set a password.
func (p *PasswordReset) IsUsable(now time.Time) bool {
	return p.UsedAt == nil && now.Before(p.ExpiresAt)
}
