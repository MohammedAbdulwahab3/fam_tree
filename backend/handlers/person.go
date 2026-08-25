package handlers

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"family-tree-backend/config"
	"family-tree-backend/middleware"
	"family-tree-backend/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PersonHandler struct {
	DB *gorm.DB
}

const personsCacheKey = "persons:all"
const personsCacheDuration = 5 * time.Minute

// loadTree returns every person in the tree, in display order, with each
// person's ChildrenIDs derived from everyone else's ParentIDs.
func (h *PersonHandler) loadTree() ([]models.Person, error) {
	var persons []models.Person
	if err := h.DB.Order("display_order asc").Find(&persons).Error; err != nil {
		return nil, err
	}
	models.DeriveChildren(persons)
	return persons, nil
}

// GetPersons returns the whole tree, with an ETag so a client that already has
// the current version gets a 304 and no body.
//
// The app polls this endpoint on a timer. Without the ETag every poll shipped
// the full person list — a few hundred kilobytes for a real family — and handed
// the client a brand new list object, which made the tree canvas recompute its
// entire layout each time even though nothing had changed.
func (h *PersonHandler) GetPersons(c *gin.Context) {
	ctx := context.Background()

	var payload []byte

	cachedData, err := middleware.GetCache(ctx, personsCacheKey)
	if err == nil && cachedData != "" {
		payload = []byte(cachedData)
		c.Header("X-Cache", "HIT")
	} else {
		persons, err := h.loadTree()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		payload, err = json.Marshal(persons)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not encode people"})
			return
		}

		middleware.SetCache(ctx, personsCacheKey, string(payload), personsCacheDuration)
		c.Header("X-Cache", "MISS")
	}

	etag := `"` + fmt.Sprintf("%x", sha256.Sum256(payload)) + `"`
	c.Header("ETag", etag)
	// The tree is per-user only in so far as it is the same for everyone; the
	// header keeps intermediaries from serving one user's response to another.
	c.Header("Cache-Control", "private, no-cache")

	if match := c.GetHeader("If-None-Match"); match != "" && etagMatches(match, etag) {
		c.Status(http.StatusNotModified)
		return
	}

	c.Data(http.StatusOK, "application/json; charset=utf-8", payload)
}

// publicView strips a person down to what a visitor who is not signed in may
// see: who they are, and where they sit in the tree.
//
// The tree is the one thing this app shows the world, so the shape of the
// family and the names in it are public. Everything a member wrote about
// themselves is not — a stranger can see that a person exists and who their
// parents are, and nothing that would let them contact or profile them.
func publicView(p models.Person) models.Person {
	return models.Person{
		ID:              p.ID,
		FamilyTreeID:    p.FamilyTreeID,
		FirstName:       p.FirstName,
		LastName:        p.LastName,
		LocalizedNames:  p.LocalizedNames,
		Gender:          p.Gender,
		ProfilePhotoURL: p.ProfilePhotoURL,
		IsDeceased:      p.IsDeceased,
		Relationships:   p.Relationships,
		DisplayOrder:    p.DisplayOrder,

		// Deliberately left zero: AuthUserID, BirthDate, DeathDate, Bio,
		// Occupation, BirthPlace, CurrentResidence, Education, ContactEmail,
		// ContactPhone, Interests, MaritalStatus, SpouseName, Photos,
		// LifeEvents. Empty slices rather than null so the app parses them
		// as it would any other person.
		Interests:  models.JSONStringArray{},
		Photos:     models.JSONStringArray{},
		LifeEvents: models.LifeEvents{},
	}
}

// GetPublicTree returns the family tree to anybody, signed in or not, so the
// landing page's "Explore Tree" leads somewhere without demanding an account
// first.
//
// Every record is passed through publicView. This is the same tree the members
// see, drawn from the same rows, with each person reduced to the fields the
// canvas needs to place and label them.
func (h *PersonHandler) GetPublicTree(c *gin.Context) {
	persons, err := h.loadTree()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not load the tree"})
		return
	}

	redacted := make([]models.Person, 0, len(persons))
	for _, p := range persons {
		redacted = append(redacted, publicView(p))
	}

	payload, err := json.Marshal(redacted)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not encode people"})
		return
	}

	// Same conditional-request handling as the members' endpoint: the app polls
	// this on a timer, and an unchanged poll should cost a round trip and no
	// body. The ETag is of the redacted payload, so it cannot collide with the
	// full one a signed-in client holds for the same tree.
	etag := `"` + fmt.Sprintf("%x", sha256.Sum256(payload)) + `"`
	c.Header("ETag", etag)
	c.Header("Cache-Control", "public, no-cache")

	if match := c.GetHeader("If-None-Match"); match != "" && etagMatches(match, etag) {
		c.Status(http.StatusNotModified)
		return
	}

	c.Data(http.StatusOK, "application/json; charset=utf-8", payload)
}

// GetPublicStats returns the headline counts the landing page shows, and
// nothing else.
//
// It replaced a public endpoint that served every person's full record —
// contact email, phone, birth date, biography, photos — without authentication,
// so that the landing page could display two numbers.
func (h *PersonHandler) GetPublicStats(c *gin.Context) {
	var persons []models.Person
	if err := h.DB.Select("id", "relationships").Find(&persons).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not load the tree"})
		return
	}

	parentOf := make(map[string]string, len(persons))
	for _, p := range persons {
		if len(p.Relationships.ParentIDs) > 0 {
			parentOf[p.ID] = p.Relationships.ParentIDs[0]
		} else {
			parentOf[p.ID] = ""
		}
	}

	// Depth of the deepest chain, guarding against a cycle so a bad edge cannot
	// hang the landing page.
	depth := make(map[string]int, len(persons))
	var depthOf func(id string, seen map[string]bool) int
	depthOf = func(id string, seen map[string]bool) int {
		if d, ok := depth[id]; ok {
			return d
		}
		if seen[id] {
			return 1
		}
		seen[id] = true

		parent, known := parentOf[id]
		d := 1
		if known && parent != "" {
			if _, exists := parentOf[parent]; exists {
				d = depthOf(parent, seen) + 1
			}
		}
		depth[id] = d
		return d
	}

	generations := 0
	for _, p := range persons {
		if d := depthOf(p.ID, map[string]bool{}); d > generations {
			generations = d
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"people":      len(persons),
		"generations": generations,
	})
}

// etagMatches handles the comma-separated list form of If-None-Match, and the
// weak-comparison "W/" prefix some proxies add.
func etagMatches(header, etag string) bool {
	for _, candidate := range strings.Split(header, ",") {
		candidate = strings.TrimSpace(candidate)
		if candidate == "*" {
			return true
		}
		if strings.TrimPrefix(candidate, "W/") == strings.TrimPrefix(etag, "W/") {
			return true
		}
	}
	return false
}

func (h *PersonHandler) GetPerson(c *gin.Context) {
	id := c.Param("id")
	var person models.Person
	if result := h.DB.First(&person, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Person not found"})
		return
	}

	// Children are derived from other people's ParentIDs, so a single-person
	// read has to consult the rest of the tree — otherwise this endpoint
	// reports everybody as childless. Relationships live in a JSON column that
	// no index can reach into, so the scan is the honest way to do it; the tree
	// is a few hundred rows.
	people, err := h.loadTree()
	if err == nil {
		for _, p := range people {
			if p.ID == person.ID {
				person.Relationships.ChildrenIDs = p.Relationships.ChildrenIDs
				break
			}
		}
	}

	c.JSON(http.StatusOK, person)
}

func (h *PersonHandler) CreatePerson(c *gin.Context) {
	var person models.Person
	if err := c.ShouldBindJSON(&person); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if strings.TrimSpace(person.FirstName) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "A person needs at least a first name"})
		return
	}

	if person.ID == "" {
		person.ID = uuid.New().String()
	}
	if person.FamilyTreeID == "" {
		person.FamilyTreeID = config.FamilyTreeID()
	}

	person.CreatedAt = time.Now()
	person.UpdatedAt = time.Now()

	// AuthUserID is deliberately not set here. It records which account *is*
	// this person, and it is only ever written when an admin approves a link
	// request. Defaulting it to the creating admin meant every relative they
	// added was marked as owned by them, which left the record unclaimable —
	// the link flow would refuse it as "already claimed by another account".
	person.AuthUserID = ""

	// Children are derived from other people's ParentIDs, so a client cannot
	// assert them. This is what removed the old two-request dance where the
	// child was created and the parent then separately updated to list it.
	person.Relationships.ChildrenIDs = nil

	if err := h.validateParents(person); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if result := h.DB.Create(&person); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	h.invalidateCache()
	person.Relationships.ChildrenIDs = []string{}
	c.JSON(http.StatusCreated, person)
}

// validateParents rejects a parent that is not in the tree, a person who is
// their own parent, and — the one that actually matters once admins can move
// people around — a parent who is already that person's descendant.
//
// Nothing checked any of this before. A typo in an id produced a person whose
// parent silently did not exist, and moving somebody under their own grandchild
// produced a loop that the app then walked until its stack ran out.
func (h *PersonHandler) validateParents(person models.Person) error {
	parents := person.Relationships.ParentIDs
	if len(parents) == 0 {
		return nil
	}

	seen := map[string]bool{}
	for _, parentID := range parents {
		if parentID == person.ID {
			return fmt.Errorf("a person cannot be their own parent")
		}
		if seen[parentID] {
			return fmt.Errorf("that parent is listed twice")
		}
		seen[parentID] = true
	}

	var found int64
	h.DB.Model(&models.Person{}).Where("id IN ?", parents).Count(&found)
	if int(found) != len(parents) {
		return fmt.Errorf("one of those parents is not in the tree")
	}

	// A new person has no descendants yet, so there is nothing to loop.
	if person.ID == "" {
		return nil
	}

	var people []models.Person
	if err := h.DB.Find(&people).Error; err != nil {
		return fmt.Errorf("could not check the tree")
	}

	// Apply the proposed change before looking, so this catches a move that
	// would create the loop rather than only one that already has.
	for i := range people {
		if people[i].ID == person.ID {
			people[i].Relationships.ParentIDs = parents
			break
		}
	}

	below := models.DescendantIDs(people, person.ID)
	for _, parentID := range parents {
		if below[parentID] && parentID != person.ID {
			return fmt.Errorf(
				"that would put this person below one of their own descendants")
		}
	}
	return nil
}

// UpdatePersonWithPermission updates a person. A member may edit only the
// record their own account is linked to; an admin may edit anyone.
//
// Both the member route and the admin route land here. They used to be separate
// handlers, and only the member one decoded onto the record already loaded from
// the database — the admin one bound into a zero-valued Person and then called
// Save(), which writes every column, so any field the request happened to omit
// was written back as empty. It survived only because one particular client
// always sent all 27 fields.
func (h *PersonHandler) UpdatePersonWithPermission(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("userID")
	isAdmin := c.GetBool("isAdmin")

	var person models.Person
	if result := h.DB.First(&person, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Person not found"})
		return
	}

	if !isAdmin && person.AuthUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only edit your own profile"})
		return
	}

	// Decode onto the record we already loaded rather than into a zero value.
	// encoding/json only overwrites keys the request actually sent, so an
	// omitted field keeps its stored value. Save() writes every column, so
	// without this a profile form that posts only bio and occupation silently
	// erases the person's parents, spouses, children and photos.
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Could not read request body"})
		return
	}

	// Deep copy, not just a struct copy: json.Unmarshal reuses an existing
	// slice's backing array, so decoding over `updateData` would otherwise
	// rewrite the very values `original` is being kept for.
	original := person
	original.Relationships = person.Relationships.Clone()

	updateData := person
	if err := json.Unmarshal(body, &updateData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Identity is never client-settable.
	updateData.ID = original.ID
	updateData.UpdatedAt = time.Now()
	if updateData.CreatedAt.IsZero() {
		updateData.CreatedAt = original.CreatedAt
	}
	// Derived on read, never stored.
	updateData.Relationships.ChildrenIDs = nil

	// A member may rewrite their own story but not the shape of the tree, and
	// not whether they are alive — marking someone deceased is an admin's call.
	if !isAdmin {
		updateData.AuthUserID = original.AuthUserID
		updateData.FamilyTreeID = original.FamilyTreeID
		updateData.Relationships = original.Relationships.Clone()
		updateData.Relationships.ChildrenIDs = nil
		updateData.DisplayOrder = original.DisplayOrder
		updateData.IsDeceased = original.IsDeceased
		updateData.DeathDate = original.DeathDate
	} else if err := h.validateParents(updateData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if result := h.DB.Save(&updateData); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	h.invalidateCache()

	// Answer with what was actually saved. The admin route used to return the
	// record as it looked *before* the update.
	c.JSON(http.StatusOK, updateData)
}

// DeletePerson removes a person, and optionally everyone below them.
//
// The references to them held by their relatives go too. Deleting used to leave
// a person's id behind in every relative's relationship blob forever, so a
// child kept a parent that no longer existed and the tree treated them as a
// root. The whole thing runs in one transaction: the app used to delete a
// subtree with one request per descendant, and a failure partway left half a
// family gone with no way to tell which half.
func (h *PersonHandler) DeletePerson(c *gin.Context) {
	id := c.Param("id")
	cascade := c.Query("cascade") == "true"

	var people []models.Person
	if err := h.DB.Find(&people).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not load the tree"})
		return
	}

	var target *models.Person
	for i := range people {
		if people[i].ID == id {
			target = &people[i]
			break
		}
	}
	if target == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Person not found"})
		return
	}

	doomed := map[string]bool{id: true}
	if cascade {
		doomed = models.DescendantIDs(people, id)
	} else {
		// Refuse to orphan a subtree silently.
		for _, p := range people {
			for _, parentID := range p.Relationships.ParentIDs {
				if parentID == id {
					c.JSON(http.StatusConflict, gin.H{
						"error": "That person has children in the tree. " +
							"Delete them together, or move the children first.",
					})
					return
				}
			}
		}
	}

	doomedIDs := make([]string, 0, len(doomed))
	for personID := range doomed {
		doomedIDs = append(doomedIDs, personID)
	}

	repaired := models.PrunePersonReferences(people, doomed)

	err := h.DB.Transaction(func(tx *gorm.DB) error {
		for _, person := range repaired {
			if err := tx.Model(&models.Person{}).Where("id = ?", person.ID).
				Updates(map[string]interface{}{
					"relationships": person.Relationships,
					"updated_at":    time.Now(),
				}).Error; err != nil {
				return err
			}
		}
		return tx.Where("id IN ?", doomedIDs).Delete(&models.Person{}).Error
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not delete"})
		return
	}

	h.invalidateCache()
	c.JSON(http.StatusOK, gin.H{
		"message": "Person deleted",
		"deleted": doomedIDs,
		"count":   len(doomedIDs),
	})
}

func (h *PersonHandler) invalidateCache() {
	middleware.DeleteCache(context.Background(), personsCacheKey)
}
