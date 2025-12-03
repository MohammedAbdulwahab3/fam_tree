package handlers

import (
	"family-tree-backend/models"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PostHandler struct {
	DB *gorm.DB
}

func (h *PostHandler) GetPosts(c *gin.Context) {
	var posts []models.Post
	if result := h.DB.Order("created_at desc").Find(&posts); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, posts)
}

func (h *PostHandler) CreatePost(c *gin.Context) {
	var post models.Post
	if err := c.ShouldBindJSON(&post); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	post.ID = uuid.New().String()
	post.CreatedAt = time.Now()
	post.UpdatedAt = time.Now()

	if result := h.DB.Create(&post); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusCreated, post)
}

func (h *PostHandler) UpdatePost(c *gin.Context) {
	id := c.Param("id")
	var req models.Post
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var post models.Post
	if result := h.DB.First(&post, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Post not found"})
		return
	}

	post.Content = req.Content
	post.Photos = req.Photos
	post.Videos = req.Videos
	post.Files = req.Files
	post.UpdatedAt = time.Now()

	if result := h.DB.Save(&post); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, post)
}

func (h *PostHandler) DeletePost(c *gin.Context) {
	id := c.Param("id")
	if result := h.DB.Delete(&models.Post{}, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Post deleted"})
}

// ===== COMMENTS =====

func (h *PostHandler) GetComments(c *gin.Context) {
	postID := c.Param("id")
	var comments []models.Comment
	if result := h.DB.Where("post_id = ?", postID).Order("created_at asc").Find(&comments); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, comments)
}

func (h *PostHandler) CreateComment(c *gin.Context) {
	postID := c.Param("id")

	var comment models.Comment
	if err := c.ShouldBindJSON(&comment); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	comment.ID = uuid.New().String()
	comment.PostID = postID
	comment.CreatedAt = time.Now()

	if result := h.DB.Create(&comment); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusCreated, comment)
}

func (h *PostHandler) DeleteComment(c *gin.Context) {
	id := c.Param("id")
	if result := h.DB.Delete(&models.Comment{}, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Comment deleted"})
}

// ===== REACTIONS =====

func (h *PostHandler) ToggleReaction(c *gin.Context) {
	postID := c.Param("id")

	var req struct {
		Emoji  string `json:"emoji"`
		UserID string `json:"userId"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if reaction exists
	var existing models.Reaction
	result := h.DB.Where("post_id = ? AND user_id = ?", postID, req.UserID).First(&existing)

	if result.Error == nil {
		// Reaction exists
		if existing.Emoji == req.Emoji {
			// Same emoji - remove reaction
			h.DB.Delete(&existing)
			c.JSON(http.StatusOK, gin.H{"message": "Reaction removed"})
			return
		}
		// Different emoji - update
		existing.Emoji = req.Emoji
		h.DB.Save(&existing)
		c.JSON(http.StatusOK, existing)
		return
	}

	// Create new reaction
	reaction := models.Reaction{
		ID:        uuid.New().String(),
		PostID:    postID,
		UserID:    req.UserID,
		Emoji:     req.Emoji,
		CreatedAt: time.Now(),
	}

	if result := h.DB.Create(&reaction); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusCreated, reaction)
}
