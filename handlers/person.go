package handlers

import (
	"family-tree-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PersonHandler struct {
	DB *gorm.DB
}

func (h *PersonHandler) GetPersons(c *gin.Context) {
	var persons []models.Person

	// Optional: Filter by AuthUserID if query param provided, or just return all
	// For now, let's return all, or filter by treeId if we had one.
	// The frontend expects to filter.

	if result := h.DB.Find(&persons); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, persons)
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

	// Set AuthUserID from context if not provided (optional, depending on logic)
	userID, exists := c.Get("userID")
	if exists && person.AuthUserID == "" {
		person.AuthUserID = userID.(string)
	}

	if result := h.DB.Create(&person); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

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

	if result := h.DB.Model(&person).Updates(updateData); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, person)
}

func (h *PersonHandler) DeletePerson(c *gin.Context) {
	id := c.Param("id")
	if result := h.DB.Delete(&models.Person{}, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
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

	var updateData models.Person
	if err := c.ShouldBindJSON(&updateData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Preserve certain fields
	updateData.ID = person.ID
	updateData.UpdatedAt = time.Now()

	// Non-admins cannot change their authUserId (prevent unlinking)
	if !isAdminBool {
		updateData.AuthUserID = person.AuthUserID
	}

	if result := h.DB.Model(&person).Updates(updateData); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// Fetch updated person
	h.DB.First(&person, "id = ?", id)
	c.JSON(http.StatusOK, person)
}
