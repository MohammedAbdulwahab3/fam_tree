package handlers

import (
	"errors"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"family-tree-backend/config"
	"family-tree-backend/models"
	"family-tree-backend/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// defaultPageSize and maxPageSize bound every list endpoint below.
//
// These used to return the whole table. A feed that has run for two years
// answered every five-second poll with two years of posts, and preloaded every
// reaction on every one of them.
const (
	defaultPageSize = 20
	maxPageSize     = 100
)

// pageSize reads a ?limit= within bounds.
func pageSize(c *gin.Context) int {
	raw := c.Query("limit")
	if raw == "" {
		return defaultPageSize
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 {
		return defaultPageSize
	}
	if n > maxPageSize {
		return maxPageSize
	}
	return n
}

type PostHandler struct {
	DB                  *gorm.DB
	NotificationService *services.NotificationService
}

// GetPosts returns a page of the feed, newest first.
//
// Paging is by creation time rather than by offset: the feed is written to
// while it is being read, and an offset silently repeats or skips a post
// whenever something new arrives between two pages.
func (h *PostHandler) GetPosts(c *gin.Context) {
	limit := pageSize(c)

	query := h.DB.Preload("Reactions").Order("created_at desc").Limit(limit + 1)
	if before := c.Query("before"); before != "" {
		cutoff, err := time.Parse(time.RFC3339, before)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "The 'before' cursor must be an RFC3339 timestamp",
			})
			return
		}
		query = query.Where("created_at < ?", cutoff)
	}

	var posts []models.Post
	if result := query.Find(&posts); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	// One extra row was requested purely to find out whether another page
	// exists, so drop it before answering.
	hasMore := len(posts) > limit
	if hasMore {
		posts = posts[:limit]
	}

	var nextCursor string
	if hasMore && len(posts) > 0 {
		nextCursor = posts[len(posts)-1].CreatedAt.UTC().Format(time.RFC3339Nano)
	}

	c.JSON(http.StatusOK, gin.H{
		"posts":      posts,
		"hasMore":    hasMore,
		"nextCursor": nextCursor,
	})
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
	if post.FamilyTreeID == "" {
		post.FamilyTreeID = config.FamilyTreeID()
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

// GetComments returns the newest page of a post's comments, oldest-first
// within the page so the thread still reads in order.
func (h *PostHandler) GetComments(c *gin.Context) {
	postID := c.Param("id")
	limit := pageSize(c)

	var total int64
	h.DB.Model(&models.Comment{}).Where("post_id = ?", postID).Count(&total)

	var comments []models.Comment
	if result := h.DB.Where("post_id = ?", postID).
		Order("created_at desc").Limit(limit).Find(&comments); result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}

	for i, j := 0, len(comments)-1; i < j; i, j = i+1, j-1 {
		comments[i], comments[j] = comments[j], comments[i]
	}

	c.JSON(http.StatusOK, gin.H{
		"comments": comments,
		"total":    total,
	})
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

			h.notifyMentioned(comment, post)
		}()
	}

	c.JSON(http.StatusCreated, comment)
}

// mentionPattern matches an @mention of up to three words, so that a relative
// whose name has a space in it — which is most of them — can be mentioned at
// all. The old pattern was `@(\w+)` matched against an exact name column, so
// "@Sara Tesfaye" looked for a user literally called "Sara" and found nobody.
var mentionPattern = regexp.MustCompile(`@([\p{L}][\p{L}\-']*(?:\s+[\p{L}][\p{L}\-']*){0,2})`)

// notifyMentioned tells anyone named in a comment about it. Longest candidate
// first, so "@Sara Tesfaye" notifies Sara Tesfaye rather than a different Sara.
func (h *PostHandler) notifyMentioned(comment models.Comment, post models.Post) {
	matches := mentionPattern.FindAllStringSubmatch(comment.Text, -1)
	if len(matches) == 0 {
		return
	}

	candidates := make([]string, 0, len(matches)*3)
	for _, match := range matches {
		words := strings.Fields(match[1])
		for n := len(words); n > 0; n-- {
			candidates = append(candidates, strings.Join(words[:n], " "))
		}
	}

	var users []models.User
	if err := h.DB.Where("LOWER(name) IN ?", lowered(candidates)).
		Find(&users).Error; err != nil || len(users) == 0 {
		return
	}

	byName := make(map[string]models.User, len(users))
	for _, u := range users {
		byName[strings.ToLower(u.Name)] = u
	}

	notified := map[string]bool{comment.UserID: true, post.UserID: true}
	for _, candidate := range candidates {
		user, found := byName[strings.ToLower(candidate)]
		if !found || notified[user.ID] {
			continue
		}
		notified[user.ID] = true

		h.NotificationService.SendNotification(
			user.ID,
			models.NotificationMention,
			"comment",
			comment.ID,
			comment.UserName+" mentioned you in a comment",
			comment.Text,
			map[string]string{"postId": comment.PostID},
		)
	}
}

func lowered(values []string) []string {
	out := make([]string, len(values))
	for i, v := range values {
		out[i] = strings.ToLower(v)
	}
	return out
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

// ToggleReaction sets, changes or clears the caller's reaction to a post.
//
// The write is a single upsert rather than a read followed by a write. The old
// version selected the existing row, decided in Go what to do, and saved —
// which meant two members reacting at the same moment could both see "no
// reaction yet" and one of the two inserts was then lost to the unique index,
// as a 500.
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

	emoji := strings.TrimSpace(req.Emoji)
	if emoji == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No reaction given"})
		return
	}

	if err := h.DB.First(&models.Post{}, "id = ?", postID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Post not found"})
		return
	}

	var removed bool
	var reaction models.Reaction

	err := h.DB.Transaction(func(tx *gorm.DB) error {
		// Lock the caller's own row for this post, if there is one, so a second
		// tap of theirs waits rather than racing.
		err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("post_id = ? AND user_id = ?", postID, caller.ID).
			First(&reaction).Error

		switch {
		case errors.Is(err, gorm.ErrRecordNotFound):
			reaction = models.Reaction{
				ID:        uuid.New().String(),
				PostID:    postID,
				UserID:    caller.ID,
				Emoji:     emoji,
				CreatedAt: time.Now(),
			}
			return tx.Create(&reaction).Error
		case err != nil:
			return err
		case reaction.Emoji == emoji:
			// Same emoji again means "take it back".
			removed = true
			return tx.Delete(&models.Reaction{}, "id = ?", reaction.ID).Error
		default:
			reaction.Emoji = emoji
			return tx.Save(&reaction).Error
		}
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not save your reaction"})
		return
	}

	if removed {
		c.JSON(http.StatusOK, gin.H{"message": "Reaction removed", "postId": postID})
		return
	}
	c.JSON(http.StatusOK, reaction)
}
