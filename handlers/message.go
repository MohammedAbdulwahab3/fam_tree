package handlers

import (
	"family-tree-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type MessageHandler struct {
	DB *gorm.DB
}

func (h *MessageHandler) GetMessages(c *gin.Context) {
	var messages []models.Message
	if result := h.DB.Order("sent_at asc").Find(&messages); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, messages)
}

func (h *MessageHandler) SendMessage(c *gin.Context) {
	var message models.Message
	if err := c.ShouldBindJSON(&message); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	message.ID = uuid.New().String()
	message.SentAt = time.Now()
	message.CreatedAt = time.Now()
	message.IsRead = false

	if result := h.DB.Create(&message); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusCreated, message)
}

func (h *MessageHandler) UpdateMessage(c *gin.Context) {
	id := c.Param("id")
	var req models.Message
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var message models.Message
	if result := h.DB.First(&message, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Message not found"})
		return
	}

	// Authorization check
	user, exists := c.Get("user")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	currentUser := user.(models.User)

	if currentUser.Role != "admin" && message.UserID != currentUser.ID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to edit this message"})
		return
	}

	message.Text = req.Text

	if result := h.DB.Save(&message); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, message)
}

func (h *MessageHandler) DeleteMessage(c *gin.Context) {
	id := c.Param("id")

	var message models.Message
	if result := h.DB.First(&message, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Message not found"})
		return
	}

	// Authorization check
	user, exists := c.Get("user")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	currentUser := user.(models.User)

	if currentUser.Role != "admin" && message.UserID != currentUser.ID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to delete this message"})
		return
	}

	if result := h.DB.Delete(&message); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Message deleted"})
}
