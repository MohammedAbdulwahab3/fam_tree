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
