package handlers

import (
	"family-tree-backend/models"
	"family-tree-backend/services"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type LinkHandler struct {
	DB                  *gorm.DB
	NotificationService *services.NotificationService
}

// notifyAdmins tells every admin that something needs their attention. Claims
// used to land in the review queue with nothing to announce them, so a new
// member could wait days for an admin who had no reason to go and look.
func (h *LinkHandler) notifyAdmins(entityID, title, body string) {
	if h.NotificationService == nil {
		return
	}

	var admins []models.User
	if err := h.DB.Where("role = ?", models.RoleAdmin).Find(&admins).Error; err != nil {
		return
	}

	ids := make([]string, 0, len(admins))
	for _, a := range admins {
		ids = append(ids, a.ID)
	}
	if len(ids) == 0 {
		return
	}

	h.NotificationService.SendBatchNotifications(
		ids, models.NotificationAnnouncement, "link_request", entityID, title, body, nil)
}

type CreateLinkRequest struct {
	PersonID string `json:"personId" binding:"required"`
}

type UpdateLinkStatusRequest struct {
	Status models.LinkRequestStatus `json:"status" binding:"required"`
	// Optional on approve, and what the member is shown on reject.
	Reason string `json:"reason"`
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

	if user.IsVerified {
		c.JSON(http.StatusConflict, gin.H{
			"error": "Your account is already linked to someone in the tree",
		})
		return
	}

	// One pending claim per person, not per person-and-target. Someone who
	// picked the wrong relative would otherwise be able to stack up claims and
	// bury the admin queue in near-identical rows.
	var existingRequest models.LinkRequest
	if err := h.DB.Where("user_id = ? AND status = ?", userID, models.LinkStatusPending).
		First(&existingRequest).Error; err == nil {
		if existingRequest.PersonID == req.PersonID {
			c.JSON(http.StatusConflict, gin.H{
				"error": "You have already asked to be linked to this person. An admin is reviewing it.",
			})
			return
		}
		c.JSON(http.StatusConflict, gin.H{
			"error": "You already have a claim waiting for review. Cancel it first to claim someone else.",
		})
		return
	}

	var person models.Person
	if err := h.DB.First(&person, "id = ?", req.PersonID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "That person is not in the tree"})
		return
	}
	if person.AuthUserID != "" {
		c.JSON(http.StatusConflict, gin.H{
			"error": "Someone has already claimed that person. Ask an admin if you think that is wrong.",
		})
		return
	}

	linkRequest := models.LinkRequest{
		ID:           uuid.New().String(),
		UserID:       userID,
		PersonID:     req.PersonID,
		FamilyTreeID: person.FamilyTreeID,
		Status:       models.LinkStatusPending,
		RequestedAt:  time.Now(),
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := h.DB.Create(&linkRequest).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create link request"})
		return
	}

	go h.notifyAdmins(
		linkRequest.ID,
		"New account to review",
		user.Name+" says they are "+fullName(person)+". Review the claim to link them.",
	)

	c.JSON(http.StatusCreated, linkRequest)
}

// CancelMyLinkRequest withdraws the caller's own pending claim, so someone who
// picked the wrong relative can correct it themselves instead of waiting for a
// rejection that may never come.
func (h *LinkHandler) CancelMyLinkRequest(c *gin.Context) {
	userID := c.GetString("userID")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var linkRequest models.LinkRequest
	if err := h.DB.Where("user_id = ? AND status = ?", userID, models.LinkStatusPending).
		First(&linkRequest).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "You have no claim waiting for review"})
		return
	}

	if err := h.DB.Unscoped().Delete(&linkRequest).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not cancel the claim"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Claim withdrawn", "id": linkRequest.ID})
}

// PersonSummary is the slice of a person record an admin needs to recognise
// them while reviewing a claim.
type PersonSummary struct {
	ID              string     `json:"id"`
	FullName        string     `json:"fullName"`
	BirthDate       *time.Time `json:"birthDate,omitempty"`
	DeathDate       *time.Time `json:"deathDate,omitempty"`
	Gender          string     `json:"gender,omitempty"`
	ProfilePhotoURL string     `json:"profilePhotoUrl,omitempty"`
	// Names of the people this person is directly connected to, so the admin
	// can sanity-check the claim against a family they recognise.
	ParentNames []string `json:"parentNames"`
	SpouseNames []string `json:"spouseNames"`
	ChildNames  []string `json:"childNames"`
	// Set when someone else already owns this record — approving would be a
	// mistake, and the admin should see that before deciding.
	AlreadyClaimedBy string `json:"alreadyClaimedBy,omitempty"`
}

// RequesterSummary identifies the account behind a claim.
type RequesterSummary struct {
	ID         string     `json:"id"`
	Name       string     `json:"name"`
	Email      string     `json:"email"`
	Role       string     `json:"role"`
	PhotoURL   string     `json:"profilePhotoUrl,omitempty"`
	JoinedAt   *time.Time `json:"joinedAt,omitempty"`
	IsVerified bool       `json:"isVerified"`
}

// DetailedLinkRequest is a pending request with both sides resolved to names.
type DetailedLinkRequest struct {
	models.LinkRequest
	Requester *RequesterSummary `json:"requester,omitempty"`
	Person    *PersonSummary    `json:"person,omitempty"`
}

// GetLinkRequests returns all pending link requests (Admin only).
//
// The raw rows carry only two opaque UUIDs, which is not enough to approve or
// reject anything — so both sides are resolved here into the names, dates and
// relatives an admin can actually recognise.
func (h *LinkHandler) GetLinkRequests(c *gin.Context) {
	var requests []models.LinkRequest
	if err := h.DB.Where("status = ?", models.LinkStatusPending).
		Order("requested_at desc").Find(&requests).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch requests"})
		return
	}

	if len(requests) == 0 {
		c.JSON(http.StatusOK, []DetailedLinkRequest{})
		return
	}

	userIDs := make([]string, 0, len(requests))
	personIDs := make([]string, 0, len(requests))
	for _, r := range requests {
		userIDs = append(userIDs, r.UserID)
		personIDs = append(personIDs, r.PersonID)
	}

	var users []models.User
	h.DB.Where("id IN ?", userIDs).Find(&users)
	usersByID := make(map[string]models.User, len(users))
	for _, u := range users {
		usersByID[u.ID] = u
	}

	// The claimed people plus everyone in their trees, so relatives can be
	// named without a query per relationship.
	var claimed []models.Person
	h.DB.Where("id IN ?", personIDs).Find(&claimed)

	treeIDs := make([]string, 0, len(claimed))
	seenTree := map[string]bool{}
	for _, p := range claimed {
		if !seenTree[p.FamilyTreeID] {
			seenTree[p.FamilyTreeID] = true
			treeIDs = append(treeIDs, p.FamilyTreeID)
		}
	}

	var treePeople []models.Person
	if len(treeIDs) > 0 {
		h.DB.Where("family_tree_id IN ?", treeIDs).Find(&treePeople)
	}

	nameByID := make(map[string]string, len(treePeople))
	childrenOf := map[string][]string{}
	for _, p := range treePeople {
		nameByID[p.ID] = fullName(p)
		for _, parentID := range p.Relationships.ParentIDs {
			childrenOf[parentID] = append(childrenOf[parentID], p.ID)
		}
	}

	personByID := make(map[string]models.Person, len(claimed))
	for _, p := range claimed {
		personByID[p.ID] = p
	}

	detailed := make([]DetailedLinkRequest, 0, len(requests))
	for _, r := range requests {
		entry := DetailedLinkRequest{LinkRequest: r}

		if u, ok := usersByID[r.UserID]; ok {
			joined := u.CreatedAt
			entry.Requester = &RequesterSummary{
				ID:         u.ID,
				Name:       u.Name,
				Email:      u.Email,
				Role:       string(u.Role),
				PhotoURL:   u.ProfilePhotoURL,
				JoinedAt:   &joined,
				IsVerified: u.IsVerified,
			}
		}

		if p, ok := personByID[r.PersonID]; ok {
			summary := &PersonSummary{
				ID:              p.ID,
				FullName:        fullName(p),
				BirthDate:       p.BirthDate,
				DeathDate:       p.DeathDate,
				Gender:          p.Gender,
				ProfilePhotoURL: p.ProfilePhotoURL,
				ParentNames:     namesFor(p.Relationships.ParentIDs, nameByID),
				ChildNames:      namesFor(childrenOf[p.ID], nameByID),
			}
			spouseIDs := make([]string, 0, len(p.Relationships.Spouses))
			for _, s := range p.Relationships.Spouses {
				spouseIDs = append(spouseIDs, s.PersonID)
			}
			summary.SpouseNames = namesFor(spouseIDs, nameByID)

			if p.AuthUserID != "" && p.AuthUserID != r.UserID {
				if owner, ok := usersByID[p.AuthUserID]; ok {
					summary.AlreadyClaimedBy = owner.Email
				} else {
					var owner models.User
					if err := h.DB.First(&owner, "id = ?", p.AuthUserID).Error; err == nil {
						summary.AlreadyClaimedBy = owner.Email
					} else {
						summary.AlreadyClaimedBy = "another account"
					}
				}
			}
			entry.Person = summary
		}

		detailed = append(detailed, entry)
	}

	c.JSON(http.StatusOK, detailed)
}

func fullName(p models.Person) string {
	name := strings.TrimSpace(p.FirstName + " " + p.LastName)
	if name == "" {
		return "Unnamed person"
	}
	return name
}

func namesFor(ids []string, nameByID map[string]string) []string {
	names := make([]string, 0, len(ids))
	for _, id := range ids {
		if name, ok := nameByID[id]; ok {
			names = append(names, name)
		}
	}
	return names
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

	if req.Status != models.LinkStatusApproved && req.Status != models.LinkStatusRejected {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Status must be 'approved' or 'rejected'",
		})
		return
	}

	var person models.Person
	if err := h.DB.First(&person, "id = ?", linkRequest.PersonID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "That person is no longer in the tree"})
		return
	}

	// Approving a person somebody else already owns would quietly take the
	// record away from them, so it is refused rather than resolved by whoever
	// was approved last.
	if req.Status == models.LinkStatusApproved &&
		person.AuthUserID != "" && person.AuthUserID != linkRequest.UserID {
		c.JSON(http.StatusConflict, gin.H{
			"error": "Another account is already linked to " + fullName(person),
		})
		return
	}

	tx := h.DB.Begin()

	now := time.Now()
	linkRequest.Status = req.Status
	linkRequest.ProcessedAt = &now
	linkRequest.ProcessedBy = adminID
	linkRequest.Reason = strings.TrimSpace(req.Reason)

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

	if err := tx.Commit().Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save the decision"})
		return
	}

	// Tell the member either way. Being approved and never hearing about it is
	// almost as bad as being rejected and never hearing about it.
	go h.notifyRequester(linkRequest, person)

	c.JSON(http.StatusOK, linkRequest)
}

// notifyRequester tells the member what an admin decided about their claim.
func (h *LinkHandler) notifyRequester(request models.LinkRequest, person models.Person) {
	if h.NotificationService == nil {
		return
	}

	var title, body string
	if request.Status == models.LinkStatusApproved {
		title = "You are linked to " + fullName(person)
		body = "Your profile in the family tree is yours to edit now."
	} else {
		title = "Your claim was not approved"
		body = "An admin did not link your account to " + fullName(person) + "."
		if request.Reason != "" {
			reason := request.Reason
			// The admin typed this into a free-text box, so it may or may not
			// end in punctuation; without this the next sentence runs into it.
			if !strings.ContainsAny(reason[len(reason)-1:], ".!?") {
				reason += "."
			}
			body += " They said: " + reason
		}
		body += " You can claim a different person from your profile."
	}

	h.NotificationService.SendNotification(
		request.UserID,
		models.NotificationAnnouncement,
		"link_request",
		request.ID,
		title,
		body,
		map[string]string{"status": string(request.Status)},
	)
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
		response := gin.H{"isVerified": true, "status": "verified"}
		var person models.Person
		if err := h.DB.First(&person, "auth_user_id = ?", userID).Error; err == nil {
			response["personId"] = person.ID
			response["personName"] = fullName(person)
		}
		c.JSON(http.StatusOK, response)
		return
	}

	// The most recent claim, whatever became of it. Looking only for a pending
	// row meant a rejected member got the same answer as someone who had never
	// applied — no reason, no record, and nothing to do but claim the same
	// person again.
	var linkRequest models.LinkRequest
	if err := h.DB.Where("user_id = ?", userID).
		Order("requested_at desc").First(&linkRequest).Error; err != nil {
		c.JSON(http.StatusOK, gin.H{
			"isVerified": false,
			"status":     "not_linked",
		})
		return
	}

	response := gin.H{
		"isVerified":  false,
		"requestId":   linkRequest.ID,
		"personId":    linkRequest.PersonID,
		"requestedAt": linkRequest.RequestedAt,
	}

	var person models.Person
	if err := h.DB.First(&person, "id = ?", linkRequest.PersonID).Error; err == nil {
		response["personName"] = fullName(person)
	}

	switch linkRequest.Status {
	case models.LinkStatusPending:
		response["status"] = "pending"
	case models.LinkStatusRejected:
		response["status"] = "rejected"
		response["reason"] = linkRequest.Reason
		response["processedAt"] = linkRequest.ProcessedAt
	default:
		// Approved on the request but the account is not verified — an
		// inconsistency worth showing as unlinked rather than pretending.
		response["status"] = "not_linked"
	}

	c.JSON(http.StatusOK, response)
}
