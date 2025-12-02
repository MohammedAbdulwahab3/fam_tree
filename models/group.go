package models

import (
	"time"

	"gorm.io/gorm"
)

type Post struct {
	ID           string          `gorm:"primaryKey" json:"id"`
	FamilyTreeID string          `json:"familyTreeId"`
	UserID       string          `json:"userId"`
	UserName     string          `json:"userName"`
	UserPhoto    string          `json:"userPhoto"`
	Content      string          `json:"content"`
	Photos       JSONStringArray `gorm:"type:text" json:"photos"`
	Videos       JSONStringArray `gorm:"type:text" json:"videos"`
	CreatedAt    time.Time       `json:"createdAt"`
	UpdatedAt    time.Time       `json:"updatedAt"`
	DeletedAt    gorm.DeletedAt  `gorm:"index" json:"-"`
}

type Message struct {
	ID           string         `gorm:"primaryKey" json:"id"`
	FamilyTreeID string         `json:"familyTreeId"`
	UserID       string         `json:"userId"`
	UserName     string         `json:"userName"`
	UserPhoto    string         `json:"userPhoto"`
	Text         string         `json:"text"`
	Type         string         `json:"type"` // text, image, video
	MediaURL     string         `json:"mediaUrl"`
	SentAt       time.Time      `json:"sentAt"`
	IsRead       bool           `json:"isRead"`
	CreatedAt    time.Time      `json:"createdAt"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

type Event struct {
	ID           string          `gorm:"primaryKey" json:"id"`
	FamilyTreeID string          `json:"familyTreeId"`
	Title        string          `json:"title"`
	Description  string          `json:"description"`
	Location     string          `json:"location"`
	DateTime     time.Time       `json:"dateTime"`
	CreatedBy    string          `json:"createdBy"`
	Attendees    JSONStringArray `gorm:"type:text" json:"attendees"`
	CreatedAt    time.Time       `json:"createdAt"`
	UpdatedAt    time.Time       `json:"updatedAt"`
	DeletedAt    gorm.DeletedAt  `gorm:"index" json:"-"`
}

type Comment struct {
	ID        string         `gorm:"primaryKey" json:"id"`
	PostID    string         `gorm:"index" json:"postId"`
	UserID    string         `json:"userId"`
	UserName  string         `json:"userName"`
	UserPhoto string         `json:"userPhoto"`
	Text      string         `json:"text"`
	CreatedAt time.Time      `json:"createdAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

type Reaction struct {
	ID        string         `gorm:"primaryKey" json:"id"`
	PostID    string         `gorm:"index" json:"postId"`
	UserID    string         `json:"userId"`
	Emoji     string         `json:"emoji"`
	CreatedAt time.Time      `json:"createdAt"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}
