package handlers

import (
	"fmt"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type UploadHandler struct{}

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
	// crafted filename cannot escape the uploads directory or collide.
	filename := fmt.Sprintf("%d%s", time.Now().UnixNano(), ext)
	dst := filepath.Join("uploads", filename)

	if err := c.SaveUploadedFile(file, dst); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save file"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"url":  fmt.Sprintf("/uploads/%s", filename),
		"size": file.Size,
		"kind": allowedExtensions[ext],
	})
}
