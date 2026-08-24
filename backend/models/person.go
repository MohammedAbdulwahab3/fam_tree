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

// Relationships represents family connections.
//
// ParentIDs is the single source of truth for descent. ChildrenIDs is derived
// from it on read by DeriveChildren and is never persisted from a request.
//
// Both used to be written by the client, in two separate non-atomic calls: the
// child was created with a parent, then the parent was updated to list the
// child. A failure between the two left a person who had a parent and was
// simultaneously a root, and the tree layout — which read ChildrenIDs — and
// root detection — which read ParentIDs — disagreed about where to draw them.
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

// Clone returns a copy that shares no backing array with r.
//
// Copying the struct alone is not enough, and the difference is a live
// permission hole. A handler that snapshots a person, unmarshals a request over
// the copy, and then restores the protected fields from the snapshot is relying
// on the snapshot being untouched — but encoding/json reuses an existing slice's
// backing array when the incoming array fits, so decoding
// {"relationships":{"parents":["someone-else"]}} over a person who already had
// one parent rewrote *both* copies. Restoring from the snapshot then restored
// the attacker's value, and a member could reassign their own parentage.
func (r Relationships) Clone() Relationships {
	clone := Relationships{
		ParentIDs:   append([]string(nil), r.ParentIDs...),
		ChildrenIDs: append([]string(nil), r.ChildrenIDs...),
		SiblingIDs:  append([]string(nil), r.SiblingIDs...),
		Spouses:     append([]RelationshipConnection(nil), r.Spouses...),
	}
	return clone
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
	ID              string         `gorm:"primaryKey" json:"id"`
	FamilyTreeID    string         `gorm:"index" json:"familyTreeId"`
	AuthUserID      string         `gorm:"index" json:"authUserId"`
	FirstName       string         `json:"firstName"`
	LastName        string         `json:"lastName"`
	LocalizedNames  LocalizedNames `gorm:"type:text" json:"localizedNames"`
	BirthDate       *time.Time     `json:"birthDate,omitempty"`
	DeathDate       *time.Time     `json:"deathDate,omitempty"`
	Gender          string         `json:"gender"`
	Bio             string         `json:"bio"`
	ProfilePhotoURL string         `json:"profilePhotoUrl"`

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

	Photos        JSONStringArray `gorm:"type:text" json:"photos"`
	LifeEvents    LifeEvents      `gorm:"type:text" json:"lifeEvents"`
	Relationships Relationships   `gorm:"type:text" json:"relationships"`
	DisplayOrder  int             `gorm:"default:0" json:"displayOrder"`
	CreatedAt     time.Time       `json:"createdAt"`
	UpdatedAt     time.Time       `json:"updatedAt"`
	DeletedAt     gorm.DeletedAt  `gorm:"index" json:"-"`
}

// DeriveChildren fills in each person's ChildrenIDs from the ParentIDs of
// everyone else in the slice, in place.
//
// Descent is stored one way — a child names its parents — so the reverse
// direction cannot drift out of step with it. Children come back in
// DisplayOrder, which is the order the tree draws siblings in, so callers get
// the same sequence the admin arranged by hand.
func DeriveChildren(people []Person) {
	index := make(map[string]int, len(people))
	for i := range people {
		index[people[i].ID] = i
		people[i].Relationships.ChildrenIDs = nil
	}

	for i := range people {
		for _, parentID := range people[i].Relationships.ParentIDs {
			if j, ok := index[parentID]; ok {
				people[j].Relationships.ChildrenIDs = append(
					people[j].Relationships.ChildrenIDs, people[i].ID)
			}
		}
	}

	for i := range people {
		if people[i].Relationships.ChildrenIDs == nil {
			people[i].Relationships.ChildrenIDs = []string{}
		}
	}
}

// PrunePersonReferences removes a deleted person's id from everyone else's
// relationships, and reports which records changed.
//
// Deleting used to remove one row and leave its id behind in every relative's
// relationship blob forever, so a child kept a parent that no longer existed
// and the tree treated them as a root.
func PrunePersonReferences(people []Person, deletedIDs map[string]bool) []Person {
	changed := make([]Person, 0)

	for i := range people {
		if deletedIDs[people[i].ID] {
			continue
		}

		rel := &people[i].Relationships
		before := len(rel.ParentIDs) + len(rel.SiblingIDs) + len(rel.Spouses)

		rel.ParentIDs = withoutIDs(rel.ParentIDs, deletedIDs)
		rel.SiblingIDs = withoutIDs(rel.SiblingIDs, deletedIDs)

		spouses := rel.Spouses[:0]
		for _, s := range rel.Spouses {
			if !deletedIDs[s.PersonID] {
				spouses = append(spouses, s)
			}
		}
		rel.Spouses = spouses

		after := len(rel.ParentIDs) + len(rel.SiblingIDs) + len(rel.Spouses)
		if after != before {
			changed = append(changed, people[i])
		}
	}

	return changed
}

func withoutIDs(ids []string, drop map[string]bool) []string {
	kept := make([]string, 0, len(ids))
	for _, id := range ids {
		if !drop[id] {
			kept = append(kept, id)
		}
	}
	return kept
}

// DescendantIDs returns the id of root plus every person below it, guarding
// against a cycle in the data rather than recursing until the stack runs out.
func DescendantIDs(people []Person, rootID string) map[string]bool {
	childrenOf := make(map[string][]string, len(people))
	for _, p := range people {
		for _, parentID := range p.Relationships.ParentIDs {
			childrenOf[parentID] = append(childrenOf[parentID], p.ID)
		}
	}

	found := map[string]bool{rootID: true}
	queue := []string{rootID}
	for len(queue) > 0 {
		current := queue[0]
		queue = queue[1:]
		for _, childID := range childrenOf[current] {
			if !found[childID] {
				found[childID] = true
				queue = append(queue, childID)
			}
		}
	}
	return found
}
