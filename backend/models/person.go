package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"

	"gorm.io/gorm"
)

// JSONStringArray for storing []string as JSON
type JSONStringArray []string

func (a *JSONStringArray) Scan(value interface{}) error {
	if value == nil {
		*a = JSONStringArray{}
		return nil
	}
	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return errors.New("type assertion failed for JSONStringArray")
	}
	return json.Unmarshal(bytes, a)
}

func (a JSONStringArray) Value() (driver.Value, error) {
	return json.Marshal(a)
}

// Relationships represents family connections
type Relationships struct {
	ParentIDs   []string                 `json:"parents"`
	Spouses     []RelationshipConnection `json:"spouses"`
	ChildrenIDs []string                 `json:"children"`
	SiblingIDs  []string                 `json:"siblings"`
}

func (r *Relationships) Scan(value interface{}) error {
	if value == nil {
		*r = Relationships{}
		return nil
	}
	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return errors.New("type assertion failed for Relationships")
	}
	return json.Unmarshal(bytes, r)
}

func (r Relationships) Value() (driver.Value, error) {
	return json.Marshal(r)
}

// RelationshipConnection represents a spousal relationship
type RelationshipConnection struct {
	PersonID  string     `json:"personId"`
	Type      string     `json:"type"`
	StartDate *time.Time `json:"startDate,omitempty"`
	EndDate   *time.Time `json:"endDate,omitempty"`
}

// LifeEvent represents a life event
type LifeEvent struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description,omitempty"`
	Date        time.Time `json:"date"`
	Location    string    `json:"location,omitempty"`
	Photos      []string  `json:"photos"`
}

type LifeEvents []LifeEvent

func (le *LifeEvents) Scan(value interface{}) error {
	if value == nil {
		*le = LifeEvents{}
		return nil
	}
	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return errors.New("type assertion failed for LifeEvents")
	}
	return json.Unmarshal(bytes, le)
}

func (le LifeEvents) Value() (driver.Value, error) {
	return json.Marshal(le)
}

// Person model matching Flutter structure
type Person struct {
	ID              string          `gorm:"primaryKey" json:"id"`
	FamilyTreeID    string          `gorm:"index" json:"familyTreeId"`
	AuthUserID      string          `gorm:"index" json:"authUserId"`
	FirstName       string          `json:"firstName"`
	LastName        string          `json:"lastName"`
	BirthDate       *time.Time      `json:"birthDate,omitempty"`
	DeathDate       *time.Time      `json:"deathDate,omitempty"`
	Gender          string          `json:"gender"`
	Bio             string          `json:"bio"`
	ProfilePhotoURL string          `json:"profilePhotoUrl"`
	Photos          JSONStringArray `gorm:"type:text" json:"photos"`
	LifeEvents      LifeEvents      `gorm:"type:text" json:"lifeEvents"`
	Relationships   Relationships   `gorm:"type:text" json:"relationships"`
	CreatedAt       time.Time       `json:"createdAt"`
	UpdatedAt       time.Time       `json:"updatedAt"`
	DeletedAt       gorm.DeletedAt  `gorm:"index" json:"-"`
}
