package handlers

import (
	"family-tree-backend/models"
	"family-tree-backend/services"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PostHandler struct {
	DB                  *gorm.DB
	NotificationService *services.NotificationService
}

func (h *PostHandler) GetPosts(c *gin.Context) {
	var posts []models.Post
	if result := h.DB.Preload("Reactions").Order("created_at desc").Find(&posts); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, posts)
}

// callerOf returns the authenticated user AuthMiddleware attached to the
// request. Every route below it is authenticated, so the second return is only
// false in a misconfiguration.
func callerOf(c *gin.Context) (models.User, bool) {
	value, exists := c.Get("user")
	if !exists {
		return models.User{}, false
	}
	user, ok := value.(models.User)
	return user, ok
}

// CreatePost serves both the member feed composer and the admin composer. The
// author is taken from the verified token rather than the request body, so a
// post can never be attributed to someone else and a client that does not know
// its own user id — which the feed composer did not — still posts correctly.
func (h *PostHandler) CreatePost(c *gin.Context) {
	author, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	var post models.Post
	if err := c.ShouldBindJSON(&post); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if strings.TrimSpace(post.Content) == "" &&
		len(post.Photos) == 0 && len(post.Videos) == 0 &&
		len(post.Files) == 0 && post.AudioURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Write something or attach a photo before posting",
		})
		return
	}

	post.ID = uuid.New().String()
	post.UserID = author.ID
	post.UserName = author.Name
	post.UserPhoto = author.ProfilePhotoURL
	if post.FamilyTreeID == "" {
		post.FamilyTreeID = author.FamilyTreeID
	}
	post.CreatedAt = time.Now()
	post.UpdatedAt = time.Now()

	if result := h.DB.Create(&post); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// Send notification to all users about new post
	if h.NotificationService != nil {
		go func() {
			var users []models.User
			h.DB.Find(&users)

			var userIDs []string
			for _, user := range users {
				// Don't notify the post author
				if user.ID != post.UserID {
					userIDs = append(userIDs, user.ID)
				}
			}

			h.NotificationService.SendBatchNotifications(
				userIDs,
				models.NotificationNewPost,
				"post",
				post.ID,
				"New Post from "+post.UserName,
				post.Content,
				nil,
			)
		}()
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

// DeletePost removes a post. Mounted on both the member route and the admin
// route: a member may only delete their own, an admin may delete any.
func (h *PostHandler) DeletePost(c *gin.Context) {
	id := c.Param("id")

	caller, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	var post models.Post
	if err := h.DB.First(&post, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Post not found"})
		return
	}

	if !caller.IsAdmin() && post.UserID != caller.ID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only delete your own posts"})
		return
	}

	// The comments and reactions hanging off a deleted post would otherwise
	// stay behind and be counted by anything that reads them by post id.
	h.DB.Where("post_id = ?", id).Delete(&models.Comment{})
	h.DB.Where("post_id = ?", id).Delete(&models.Reaction{})

	if result := h.DB.Delete(&models.Post{}, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Post deleted", "id": id})
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

	author, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	if strings.TrimSpace(comment.Text) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Comment cannot be empty"})
		return
	}

	comment.ID = uuid.New().String()
	comment.PostID = postID
	comment.UserID = author.ID
	comment.UserName = author.Name
	comment.UserPhoto = author.ProfilePhotoURL
	comment.CreatedAt = time.Now()

	if result := h.DB.Create(&comment); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// Send notification to post author and mentioned users
	if h.NotificationService != nil {
		go func() {
			// Get post details
			var post models.Post
			if h.DB.First(&post, "id = ?", postID).Error == nil {
				// Notify post author (if not the commenter)
				if post.UserID != comment.UserID {
					h.NotificationService.SendNotification(
						post.UserID,
						models.NotificationNewComment,
						"post",
						postID,
						comment.UserName+" commented on your post",
						comment.Text,
						nil,
					)
				}
			}

			// Extract @mentions from comment text
			mentionRegex := regexp.MustCompile(`@(\w+)`)
			mentions := mentionRegex.FindAllStringSubmatch(comment.Text, -1)

			for _, mention := range mentions {
				if len(mention) > 1 {
					userName := mention[1]
					var user models.User
					if h.DB.Where("name = ?", userName).First(&user).Error == nil {
						// Don't notify if they're the commenter or already notified as post author
						if user.ID != comment.UserID && user.ID != post.UserID {
							h.NotificationService.SendNotification(
								user.ID,
								models.NotificationMention,
								"comment",
								comment.ID,
								comment.UserName+" mentioned you in a comment",
								comment.Text,
								map[string]string{"postId": postID},
							)
						}
					}
				}
			}
		}()
	}

	c.JSON(http.StatusCreated, comment)
}

// UpdateComment edits a comment. Only its author may edit it — an admin can
// remove a comment but not rewrite what someone else said.
func (h *PostHandler) UpdateComment(c *gin.Context) {
	id := c.Param("id")

	caller, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	var req struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	text := strings.TrimSpace(req.Text)
	if text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Comment cannot be empty"})
		return
	}

	var comment models.Comment
	if err := h.DB.First(&comment, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Comment not found"})
		return
	}

	if comment.UserID != caller.ID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only edit your own comments"})
		return
	}

	comment.Text = text
	if err := h.DB.Save(&comment).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, comment)
}

// DeleteComment removes a comment. Its author, the author of the post it sits
// under, and any admin may do this.
func (h *PostHandler) DeleteComment(c *gin.Context) {
	id := c.Param("id")

	caller, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	var comment models.Comment
	if err := h.DB.First(&comment, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Comment not found"})
		return
	}

	allowed := caller.IsAdmin() || comment.UserID == caller.ID
	if !allowed {
		var post models.Post
		if err := h.DB.First(&post, "id = ?", comment.PostID).Error; err == nil {
			allowed = post.UserID == caller.ID
		}
	}
	if !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only delete your own comments"})
		return
	}

	if result := h.DB.Delete(&models.Comment{}, "id = ?", id); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Comment deleted", "id": id})
}

// ===== REACTIONS =====

func (h *PostHandler) ToggleReaction(c *gin.Context) {
	postID := c.Param("id")

	caller, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	var req struct {
		Emoji string `json:"emoji"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if strings.TrimSpace(req.Emoji) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No reaction given"})
		return
	}

	// Check if reaction exists
	var existing models.Reaction
	result := h.DB.Where("post_id = ? AND user_id = ?", postID, caller.ID).First(&existing)

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
		UserID:    caller.ID,
		Emoji:     req.Emoji,
		CreatedAt: time.Now(),
	}

	if result := h.DB.Create(&reaction); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	c.JSON(http.StatusCreated, reaction)
}
