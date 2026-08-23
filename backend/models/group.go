package models

import (
	"time"

	"gorm.io/gorm"
)

type Post struct {
	ID           string          `gorm:"primaryKey" json:"id"`
	FamilyTreeID string          `gorm:"index" json:"familyTreeId"`
	UserID       string          `gorm:"index" json:"userId"`
	UserName     string          `json:"userName"`
	UserPhoto    string          `json:"userPhoto"`
	Content      string          `json:"content"`
	Photos       JSONStringArray `gorm:"type:text" json:"photos"`
	Videos       JSONStringArray `gorm:"type:text" json:"videos"`
	Files        JSONStringArray `gorm:"type:text" json:"files"`
	AudioURL     string          `json:"audioUrl"`
	Reactions    []Reaction      `gorm:"foreignKey:PostID" json:"reactions"`
	CreatedAt    time.Time       `gorm:"index" json:"createdAt"`
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

// Reaction is one member's reaction to one post.
//
// The (post_id, user_id) pair is unique so that two taps arriving at the same
// moment cannot produce two rows for the same person. The toggle handler
// depends on that constraint rather than on a read-then-write, which used to
// lose a reaction whenever two members reacted simultaneously.
//
// Deliberately has no DeletedAt: removing a reaction is a hard delete. A
// soft-deleted row would keep occupying the unique index, so the same person
// could never react to that post again.
type Reaction struct {
	ID        string    `gorm:"primaryKey" json:"id"`
	PostID    string    `gorm:"index:idx_reaction_post_user,unique" json:"postId"`
	UserID    string    `gorm:"index:idx_reaction_post_user,unique" json:"userId"`
	Emoji     string    `json:"emoji"`
	CreatedAt time.Time `json:"createdAt"`
}
