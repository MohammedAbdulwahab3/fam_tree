package handlers

import (
	"family-tree-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type LinkHandler struct {
	DB *gorm.DB
}

type CreateLinkRequest struct {
	PersonID string `json:"personId" binding:"required"`
}

type UpdateLinkStatusRequest struct {
	Status models.LinkRequestStatus `json:"status" binding:"required"`
}

// RequestLink creates a new link request for the current user
func (h *LinkHandler) RequestLink(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var req CreateLinkRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get User to find FamilyTreeID
	var user models.User
	if err := h.DB.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Check if request already exists
	var existingRequest models.LinkRequest
	if err := h.DB.Where("user_id = ? AND person_id = ? AND status = ?", userID, req.PersonID, models.LinkStatusPending).First(&existingRequest).Error; err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Pending request already exists"})
		return
	}

	linkRequest := models.LinkRequest{
		ID:           uuid.New().String(),
		UserID:       userID,
		PersonID:     req.PersonID,
		FamilyTreeID: user.FamilyTreeID,
		Status:       models.LinkStatusPending,
		RequestedAt:  time.Now(),
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := h.DB.Create(&linkRequest).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create link request"})
		return
	}

	c.JSON(http.StatusCreated, linkRequest)
}

// GetLinkRequests returns all pending link requests (Admin only)
func (h *LinkHandler) GetLinkRequests(c *gin.Context) {
	var requests []models.LinkRequest
	// Preload User and Person details if needed, for now just raw requests
	if err := h.DB.Where("status = ?", models.LinkStatusPending).Find(&requests).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch requests"})
		return
	}

	c.JSON(http.StatusOK, requests)
}

// UpdateLinkStatus approves or rejects a link request (Admin only)
func (h *LinkHandler) UpdateLinkStatus(c *gin.Context) {
	requestID := c.Param("id")
	adminID := c.GetString("userID")

	var req UpdateLinkStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var linkRequest models.LinkRequest
	if err := h.DB.First(&linkRequest, "id = ?", requestID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Request not found"})
		return
	}

	if linkRequest.Status != models.LinkStatusPending {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Request is not pending"})
		return
	}

	tx := h.DB.Begin()

	now := time.Now()
	linkRequest.Status = req.Status
	linkRequest.ProcessedAt = &now
	linkRequest.ProcessedBy = adminID

	if err := tx.Save(&linkRequest).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update request"})
		return
	}

	if req.Status == models.LinkStatusApproved {
		// Update User: IsVerified = true
		if err := tx.Model(&models.User{}).Where("id = ?", linkRequest.UserID).Update("is_verified", true).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify user"})
			return
		}

		// Update Person: AuthUserID = linkRequest.UserID
		if err := tx.Model(&models.Person{}).Where("id = ?", linkRequest.PersonID).Update("auth_user_id", linkRequest.UserID).Error; err != nil {
			tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to link person"})
			return
		}
	}

	tx.Commit()
	c.JSON(http.StatusOK, linkRequest)
}

// GetMyLinkStatus returns the current user's link request status
func (h *LinkHandler) GetMyLinkStatus(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Get user
	var user models.User
	if err := h.DB.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// If already verified, return verified status
	if user.IsVerified {
		c.JSON(http.StatusOK, gin.H{
			"isVerified": true,
			"status":     "verified",
		})
		return
	}

	// Check for pending request
	var linkRequest models.LinkRequest
	if err := h.DB.Where("user_id = ? AND status = ?", userID, models.LinkStatusPending).First(&linkRequest).Error; err != nil {
		// No pending request
		c.JSON(http.StatusOK, gin.H{
			"isVerified": false,
			"status":     "not_linked",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"isVerified":  false,
		"status":      "pending",
		"requestId":   linkRequest.ID,
		"personId":    linkRequest.PersonID,
		"requestedAt": linkRequest.RequestedAt,
	})
}
