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

// LocalizedPersonName holds a person's name in a specific locale
type LocalizedPersonName struct {
	FirstName string `json:"firstName"`
	LastName  string `json:"lastName"`
}

// LocalizedNames maps a locale code (e.g. "am") to that locale's name
type LocalizedNames map[string]LocalizedPersonName

func (ln *LocalizedNames) Scan(value interface{}) error {
	if value == nil {
		*ln = LocalizedNames{}
		return nil
	}
	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return errors.New("type assertion failed for LocalizedNames")
	}
	return json.Unmarshal(bytes, ln)
}

func (ln LocalizedNames) Value() (driver.Value, error) {
	return json.Marshal(ln)
}

// Person model matching Flutter structure
type Person struct {
	ID              string          `gorm:"primaryKey" json:"id"`
	FamilyTreeID    string          `gorm:"index" json:"familyTreeId"`
	AuthUserID      string          `gorm:"index" json:"authUserId"`
	FirstName       string          `json:"firstName"`
	LastName        string          `json:"lastName"`
	LocalizedNames  LocalizedNames  `gorm:"type:text" json:"localizedNames"`
	BirthDate       *time.Time      `json:"birthDate,omitempty"`
	DeathDate       *time.Time      `json:"deathDate,omitempty"`
	Gender          string          `json:"gender"`
	Bio             string          `json:"bio"`
	ProfilePhotoURL string          `json:"profilePhotoUrl"`

	// Self-authored profile detail. A linked member fills these in about
	// themselves; everyone browsing the tree sees them on the person's card.
	Occupation       string          `json:"occupation"`
	BirthPlace       string          `json:"birthPlace"`
	CurrentResidence string          `json:"currentResidence"`
	Education        string          `json:"education"`
	ContactEmail     string          `json:"contactEmail"`
	ContactPhone     string          `json:"contactPhone"`
	Interests        JSONStringArray `gorm:"type:text" json:"interests"`

	// "single" | "married" | "divorced" | "widowed", or empty when unstated.
	MaritalStatus string `json:"maritalStatus"`
	// Free text, for a spouse who has no record of their own in the tree.
	// A spouse who *is* in the tree lives in Relationships.Spouses.
	SpouseName string `json:"spouseName"`

	// Whether the person has died. Kept separate from DeathDate because a
	// family often knows someone has passed long before anyone can name the
	// date — deriving this from DeathDate alone would leave them shown as
	// living until a date is found.
	IsDeceased bool `json:"isDeceased"`

	Photos          JSONStringArray `gorm:"type:text" json:"photos"`
	LifeEvents      LifeEvents      `gorm:"type:text" json:"lifeEvents"`
	Relationships   Relationships   `gorm:"type:text" json:"relationships"`
	DisplayOrder    int             `gorm:"default:0" json:"displayOrder"`
	CreatedAt       time.Time       `json:"createdAt"`
	UpdatedAt       time.Time       `json:"updatedAt"`
	DeletedAt       gorm.DeletedAt  `gorm:"index" json:"-"`
}
