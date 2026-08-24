package handlers

import (
	"crypto/rand"
	"math/big"
	"net/http"
	"strings"
	"time"

	"family-tree-backend/auth"
	"family-tree-backend/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type PasswordHandler struct {
	DB *gorm.DB
}

// ResetCodeTTL is how long an issued reset code stays good for. Long enough for
// an admin to reach someone by phone, short enough that a code read out and
// forgotten does not stay live for weeks.
const ResetCodeTTL = 2 * time.Hour

// resetCodeAlphabet leaves out characters that are easy to confuse when a code
// is read aloud or copied off a screen: 0/O, 1/I/L.
const resetCodeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

func newResetCode() (string, error) {
	const length = 8
	code := make([]byte, 0, length+1)
	for i := 0; i < length; i++ {
		// Grouped as XXXX-XXXX so it survives being read down a phone.
		if i == 4 {
			code = append(code, '-')
		}
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(resetCodeAlphabet))))
		if err != nil {
			return "", err
		}
		code = append(code, resetCodeAlphabet[n.Int64()])
	}
	return string(code), nil
}

// IssueResetCode gives an admin a one-time code for a member who cannot sign
// in. Admin-only: the code is the credential, so handing one out is the same as
// vouching for who is asking.
func (h *PasswordHandler) IssueResetCode(c *gin.Context) {
	admin, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	var user models.User
	if err := h.DB.First(&user, "id = ?", c.Param("id")).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// A reset code is a credential. Letting one admin mint one for another is a
	// lateral takeover between peers who are supposed to be equals, so an admin
	// who is locked out has to be helped from the database instead.
	if user.IsAdmin() && user.ID != admin.ID {
		c.JSON(http.StatusConflict, gin.H{
			"error": "Cannot issue a reset code for another admin",
		})
		return
	}

	code, err := newResetCode()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not generate a code"})
		return
	}

	// Any earlier code for this account stops working the moment a new one is
	// issued, so a code from a previous conversation cannot be used later.
	h.DB.Where("user_id = ? AND used_at IS NULL", user.ID).
		Delete(&models.PasswordReset{})

	reset := models.PasswordReset{
		ID:        uuid.New().String(),
		UserID:    user.ID,
		Code:      code,
		IssuedBy:  admin.ID,
		ExpiresAt: time.Now().Add(ResetCodeTTL),
		CreatedAt: time.Now(),
	}
	if err := h.DB.Create(&reset).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not issue the code"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"code":      code,
		"email":     user.Email,
		"name":      user.Name,
		"expiresAt": reset.ExpiresAt,
		"expiresIn": "2 hours",
	})
}

// ResetPassword sets a new password using a code an admin issued. Public: the
// whole point is that the person cannot sign in.
func (h *PasswordHandler) ResetPassword(c *gin.Context) {
	var req struct {
		Email       string `json:"email" binding:"required,email"`
		Code        string `json:"code" binding:"required"`
		NewPassword string `json:"newPassword" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Enter your email, the code, and a password of at least 6 characters",
		})
		return
	}

	// Normalised so a code read off a screen still works whatever case it was
	// typed in and whether or not the dash was included.
	code := strings.ToUpper(strings.TrimSpace(req.Code))
	code = strings.ReplaceAll(code, " ", "")
	if !strings.Contains(code, "-") && len(code) == 8 {
		code = code[:4] + "-" + code[4:]
	}

	var user models.User
	email := strings.ToLower(strings.TrimSpace(req.Email))
	if err := h.DB.First(&user, "email = ?", email).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "That email and code do not match"})
		return
	}

	var reset models.PasswordReset
	if err := h.DB.Where("user_id = ? AND code = ?", user.ID, code).
		Order("created_at desc").First(&reset).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "That email and code do not match"})
		return
	}

	now := time.Now()
	if !reset.IsUsable(now) {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "That code has expired or has already been used. Ask an admin for a new one.",
		})
		return
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not set the password"})
		return
	}

	tx := h.DB.Begin()
	if err := tx.Model(&models.User{}).Where("id = ?", user.ID).
		Update("password", string(hashed)).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not set the password"})
		return
	}
	if err := tx.Model(&models.PasswordReset{}).Where("id = ?", reset.ID).
		Update("used_at", now).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not set the password"})
		return
	}
	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not set the password"})
		return
	}

	// Sign them straight in — being told "password changed, now go and log in"
	// is a pointless extra step when we already know who they are.
	token, err := auth.GenerateToken(user.ID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"message": "Password changed. Sign in with your new password."})
		return
	}

	user.Password = ""
	c.JSON(http.StatusOK, gin.H{"token": token, "user": user})
}

// ChangePassword updates the signed-in user's own password. The current
// password is required, so a borrowed unlocked phone cannot lock the owner out.
func (h *PasswordHandler) ChangePassword(c *gin.Context) {
	caller, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	var req struct {
		CurrentPassword string `json:"currentPassword" binding:"required"`
		NewPassword     string `json:"newPassword" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Enter your current password and a new one of at least 6 characters",
		})
		return
	}

	var user models.User
	if err := h.DB.First(&user, "id = ?", caller.ID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if err := bcrypt.CompareHashAndPassword(
		[]byte(user.Password), []byte(req.CurrentPassword)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "That is not your current password"})
		return
	}

	if req.CurrentPassword == req.NewPassword {
		c.JSON(http.StatusBadRequest, gin.H{"error": "The new password is the same as the old one"})
		return
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not set the password"})
		return
	}

	if err := h.DB.Model(&models.User{}).Where("id = ?", user.ID).
		Update("password", string(hashed)).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not set the password"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Password changed"})
}

// DeleteOwnAccount removes the caller's account for good.
//
// The person record they were linked to stays in the tree and simply becomes
// unclaimed again: it is a record of a family member, not of a login, and
// deleting it would tear a hole in everyone else's tree.
func (h *PasswordHandler) DeleteOwnAccount(c *gin.Context) {
	caller, ok := callerOf(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Not signed in"})
		return
	}

	var req struct {
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Enter your password to confirm"})
		return
	}

	var user models.User
	if err := h.DB.First(&user, "id = ?", caller.ID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	if err := bcrypt.CompareHashAndPassword(
		[]byte(user.Password), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "That password is not correct"})
		return
	}

	// The tree must not be left without an administrator.
	if user.IsAdmin() {
		var admins int64
		h.DB.Model(&models.User{}).Where("role = ?", models.RoleAdmin).Count(&admins)
		if admins <= 1 {
			c.JSON(http.StatusConflict, gin.H{
				"error": "You are the only admin. Make someone else an admin first.",
			})
			return
		}
	}

	tx := h.DB.Begin()

	// Release the person record rather than deleting it.
	if err := tx.Model(&models.Person{}).Where("auth_user_id = ?", user.ID).
		Update("auth_user_id", "").Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not delete the account"})
		return
	}

	tx.Where("user_id = ?", user.ID).Delete(&models.Notification{})
	tx.Where("user_id = ?", user.ID).Delete(&models.NotificationPreference{})
	tx.Where("user_id = ?", user.ID).Unscoped().Delete(&models.Reaction{})
	tx.Where("user_id = ?", user.ID).Unscoped().Delete(&models.LinkRequest{})
	tx.Where("user_id = ?", user.ID).Unscoped().Delete(&models.PasswordReset{})

	// Unscoped so the email is freed up and could be registered again.
	if err := tx.Unscoped().Delete(&models.User{}, "id = ?", user.ID).Error; err != nil {
		tx.Rollback()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not delete the account"})
		return
	}

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not delete the account"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Account deleted"})
}
