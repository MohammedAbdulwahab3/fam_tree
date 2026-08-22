package handlers

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"family-tree-backend/middleware"
	"family-tree-backend/models"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PersonHandler struct {
	DB *gorm.DB
}

const personsCacheKey = "persons:all"
const personsCacheDuration = 5 * time.Minute

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

	// Try to get from cache first
	cachedData, err := middleware.GetCache(ctx, personsCacheKey)
	if err == nil && cachedData != "" {
		payload = []byte(cachedData)
		c.Header("X-Cache", "HIT")
	} else {
		var persons []models.Person
		if result := h.DB.Order("display_order asc").Find(&persons); result.Error != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
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
	c.JSON(http.StatusOK, person)
}

func (h *PersonHandler) CreatePerson(c *gin.Context) {
	var person models.Person
	if err := c.ShouldBindJSON(&person); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Set ID if not provided
	if person.ID == "" {
		person.ID = uuid.New().String()
	}

	// Set timestamps
	person.CreatedAt = time.Now()
	person.UpdatedAt = time.Now()

	// AuthUserID is deliberately not set here. It records which account *is*
	// this person, and it is only ever written when an admin approves a link
	// request. Defaulting it to the creating admin meant every relative they
	// added was marked as owned by them, which left the record unclaimable —
	// the link flow would refuse it as "already claimed by another account".
	person.AuthUserID = ""

	if result := h.DB.Create(&person); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// Invalidate cache
	ctx := context.Background()
	middleware.DeleteCache(ctx, personsCacheKey)

	c.JSON(http.StatusCreated, person)
}

func (h *PersonHandler) UpdatePerson(c *gin.Context) {
	id := c.Param("id")
	var person models.Person
	if result := h.DB.First(&person, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Person not found"})
		return
	}

	// Check ownership if needed (skip for now to mimic "allow write" rules)

	var updateData models.Person
	if err := c.ShouldBindJSON(&updateData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Update fields
	updateData.ID = person.ID // Ensure ID doesn't change
	updateData.UpdatedAt = time.Now()
	// Keep the incoming CreatedAt if provided (for reordering)
	if updateData.CreatedAt.IsZero() {
		updateData.CreatedAt = person.CreatedAt
	}

	// Use Save to update ALL fields including CreatedAt (needed for reordering)
	if result := h.DB.Save(&updateData); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// Invalidate cache
	ctx := context.Background()
	middleware.DeleteCache(ctx, personsCacheKey)

	c.JSON(http.StatusOK, person)
}

func (h *PersonHandler) DeletePerson(c *gin.Context) {
	id := c.Param("id")
	if result := h.DB.Delete(&models.Person{}, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// Invalidate cache
	ctx := context.Background()
	middleware.DeleteCache(ctx, personsCacheKey)

	c.JSON(http.StatusOK, gin.H{"message": "Person deleted"})
}

// UpdatePersonWithPermission allows users to update only their own profile, or admin to update any
func (h *PersonHandler) UpdatePersonWithPermission(c *gin.Context) {
	id := c.Param("id")
	userID, _ := c.Get("userID")
	isAdmin, _ := c.Get("isAdmin")

	var person models.Person
	if result := h.DB.First(&person, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Person not found"})
		return
	}

	// Check permission: user can only update their own linked profile, or be admin
	isAdminBool, ok := isAdmin.(bool)
	if !ok {
		isAdminBool = false
	}

	if !isAdminBool && person.AuthUserID != userID.(string) {
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

	original := person
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

	// A member may rewrite their own story but not the shape of the tree, and
	// not whether they are alive — marking someone deceased is an admin's call.
	if !isAdminBool {
		updateData.AuthUserID = original.AuthUserID
		updateData.FamilyTreeID = original.FamilyTreeID
		updateData.Relationships = original.Relationships
		updateData.DisplayOrder = original.DisplayOrder
		updateData.IsDeceased = original.IsDeceased
		updateData.DeathDate = original.DeathDate
	}

	if result := h.DB.Save(&updateData); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// Invalidate cache
	ctx := context.Background()
	middleware.DeleteCache(ctx, personsCacheKey)

	// Fetch updated person
	h.DB.First(&person, "id = ?", id)
	c.JSON(http.StatusOK, person)
}
