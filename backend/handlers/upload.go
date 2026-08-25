package handlers

import (
	"errors"
	"fmt"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"family-tree-backend/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type UploadHandler struct {
	DB *gorm.DB
}

// MaxUploadBytes caps a single upload.
//
// There was no limit at all: any authenticated request could write a file of
// any size to the server's disk, and a member on a slow connection could spend
// a minute uploading a photo that would then be rejected by nothing. The client
// shrinks images before sending, so anything approaching this ceiling is either
// a video or a mistake.
const MaxUploadBytes = 25 << 20 // 25 MB

// allowedExtensions is what the app actually displays. Anything else is stored
// under a generic name so it cannot be served back as something executable.
var allowedExtensions = map[string]string{
	".jpg":  "image",
	".jpeg": "image",
	".png":  "image",
	".gif":  "image",
	".webp": "image",
	".heic": "image",
	".mp4":  "video",
	".mov":  "video",
	".webm": "video",
	".m4a":  "audio",
	".mp3":  "audio",
	".aac":  "audio",
	".wav":  "audio",
	".pdf":  "file",
}

func (h *UploadHandler) UploadFile(c *gin.Context) {
	// Refuse an oversized body before reading it into memory.
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, MaxUploadBytes)

	file, err := c.FormFile("file")
	if err != nil {
		if strings.Contains(err.Error(), "too large") ||
			strings.Contains(err.Error(), "http: request body too large") {
			c.JSON(http.StatusRequestEntityTooLarge, gin.H{
				"error": fmt.Sprintf(
					"That file is larger than %d MB. Try a shorter video or a smaller photo.",
					MaxUploadBytes>>20),
			})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}

	if file.Size > MaxUploadBytes {
		c.JSON(http.StatusRequestEntityTooLarge, gin.H{
			"error": fmt.Sprintf(
				"That file is larger than %d MB. Try a shorter video or a smaller photo.",
				MaxUploadBytes>>20),
		})
		return
	}

	ext := strings.ToLower(filepath.Ext(file.Filename))
	if _, ok := allowedExtensions[ext]; !ok {
		c.JSON(http.StatusUnsupportedMediaType, gin.H{
			"error": "That kind of file cannot be uploaded. Photos, videos, audio and PDFs are fine.",
		})
		return
	}

	// The stored name is generated, never the one the client sent, so a
	// crafted filename cannot escape anything or collide.
	filename := fmt.Sprintf("%d%s", time.Now().UnixNano(), ext)

	opened, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read the file"})
		return
	}
	defer opened.Close()

	data, err := io.ReadAll(opened)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read the file"})
		return
	}

	contentType := mime.TypeByExtension(ext)
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	record := models.Upload{
		Name:        filename,
		ContentType: contentType,
		Kind:        allowedExtensions[ext],
		Data:        data,
		Size:        int64(len(data)),
		UploadedBy:  c.GetString("userID"),
		CreatedAt:   time.Now(),
	}
	if err := h.DB.Create(&record).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save file"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"url":  fmt.Sprintf("/uploads/%s", filename),
		"size": file.Size,
		"kind": allowedExtensions[ext],
	})
}

// Serve returns an uploaded file by name.
//
// Rows come first, then ./uploads on disk. The disk fallback is what keeps the
// photographs baked into the image working: they were uploaded before storage
// moved into the database and their URLs are already written into person and
// post records, so they have no row to find.
func (h *UploadHandler) Serve(c *gin.Context) {
	// Strip the leading slash Gin's wildcard includes, and refuse anything
	// with a path separator in it — the name is one segment, always.
	name := strings.TrimPrefix(c.Param("name"), "/")
	if name == "" || strings.ContainsAny(name, `/\`) || strings.Contains(name, "..") {
		c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
		return
	}

	var record models.Upload
	err := h.DB.First(&record, "name = ?", name).Error
	if err == nil {
		// Immutable: the name is generated per upload and its bytes never
		// change, so it can be cached hard.
		c.Header("Cache-Control", "public, max-age=31536000, immutable")
		c.Data(http.StatusOK, record.ContentType, record.Data)
		return
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not read the file"})
		return
	}

	path := filepath.Join("uploads", name)
	if info, statErr := os.Stat(path); statErr != nil || info.IsDir() {
		c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
		return
	}
	c.Header("Cache-Control", "public, max-age=31536000, immutable")
	c.File(path)
}
