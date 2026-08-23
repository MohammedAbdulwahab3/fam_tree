package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"family-tree-backend/models"
	"family-tree-backend/services"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func init() { gin.SetMode(gin.TestMode) }

// newDB returns an empty in-memory database with the schema applied. SQLite
// rather than Postgres so the suite needs no container to run.
func newDB(t *testing.T) *gorm.DB {
	t.Helper()

	db, err := gorm.Open(sqlite.Open("file::memory:?cache=shared&_pragma=foreign_keys(1)"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatalf("open test database: %v", err)
	}

	// A shared-cache in-memory database is shared by name, so each test starts
	// by dropping whatever the last one left.
	for _, model := range []interface{}{
		&models.User{}, &models.Person{}, &models.Post{}, &models.Comment{},
		&models.Reaction{}, &models.Notification{},
		&models.NotificationPreference{}, &models.LinkRequest{},
		&models.PasswordReset{},
	} {
		_ = db.Migrator().DropTable(model)
	}

	if err := db.AutoMigrate(
		&models.User{}, &models.Person{}, &models.Post{}, &models.Comment{},
		&models.Reaction{}, &models.Notification{},
		&models.NotificationPreference{}, &models.LinkRequest{},
		&models.PasswordReset{},
	); err != nil {
		t.Fatalf("migrate test database: %v", err)
	}

	return db
}

// as builds a request context carrying an authenticated caller, exactly as
// AuthMiddleware would.
func as(user models.User, method, target string, body interface{}) (*gin.Context, *httptest.ResponseRecorder) {
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)

	var payload []byte
	if body != nil {
		payload, _ = json.Marshal(body)
	}
	c.Request = httptest.NewRequest(method, target, bytes.NewReader(payload))
	c.Request.Header.Set("Content-Type", "application/json")

	c.Set("user", user)
	c.Set("userID", user.ID)
	c.Set("isAdmin", user.IsAdmin())
	return c, rec
}

func makeUser(t *testing.T, db *gorm.DB, name string, role models.UserRole) models.User {
	t.Helper()
	user := models.User{
		ID:        uuid.New().String(),
		Email:     name + "@test.local",
		Name:      name,
		Role:      role,
		CreatedAt: time.Now(),
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	return user
}

func decode(t *testing.T, rec *httptest.ResponseRecorder) map[string]interface{} {
	t.Helper()
	var out map[string]interface{}
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("decode response %q: %v", rec.Body.String(), err)
	}
	return out
}

// ---------------------------------------------------------------- persons ---

// The admin update route used to bind into a zero-valued Person and then Save,
// so every field the request omitted was written back as empty. It survived
// only because one client always sent all of them.
func TestAdminUpdateKeepsFieldsTheRequestOmits(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	born := time.Date(1950, 3, 2, 0, 0, 0, 0, time.UTC)
	original := models.Person{
		ID:            "p1",
		FamilyTreeID:  "main-family-tree",
		FirstName:     "Issa",
		LastName:      "Mammaduu",
		BirthPlace:    "Harar",
		Occupation:    "Teacher",
		BirthDate:     &born,
		Photos:        models.JSONStringArray{"/uploads/1.jpg"},
		Relationships: models.Relationships{ParentIDs: []string{}},
	}
	if err := db.Create(&original).Error; err != nil {
		t.Fatalf("seed person: %v", err)
	}

	c, rec := as(admin, http.MethodPut, "/api/admin/persons/p1",
		map[string]interface{}{"bio": "Loved gardening"})
	c.Params = gin.Params{{Key: "id", Value: "p1"}}
	h.UpdatePersonWithPermission(c)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var saved models.Person
	db.First(&saved, "id = ?", "p1")

	if saved.Bio != "Loved gardening" {
		t.Errorf("bio should have been updated, got %q", saved.Bio)
	}
	if saved.FirstName != "Issa" || saved.LastName != "Mammaduu" {
		t.Errorf("name was wiped: %q %q", saved.FirstName, saved.LastName)
	}
	if saved.BirthPlace != "Harar" || saved.Occupation != "Teacher" {
		t.Errorf("detail was wiped: %q %q", saved.BirthPlace, saved.Occupation)
	}
	if saved.BirthDate == nil {
		t.Error("birth date was wiped")
	}
	if len(saved.Photos) != 1 {
		t.Errorf("photos were wiped: %v", saved.Photos)
	}
}

// The admin route used to answer with the record as it looked before the write.
func TestAdminUpdateReturnsTheSavedRecord(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	db.Create(&models.Person{ID: "p1", FirstName: "Old"})

	c, rec := as(admin, http.MethodPut, "/api/admin/persons/p1",
		map[string]interface{}{"firstName": "New"})
	c.Params = gin.Params{{Key: "id", Value: "p1"}}
	h.UpdatePersonWithPermission(c)

	if got := decode(t, rec)["firstName"]; got != "New" {
		t.Fatalf("expected the saved record back, got firstName=%v", got)
	}
}

func TestMemberCannotEditSomeoneElse(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	member := makeUser(t, db, "member", models.RoleMember)

	db.Create(&models.Person{ID: "p1", FirstName: "Someone", AuthUserID: "another-account"})

	c, rec := as(member, http.MethodPut, "/api/persons/p1",
		map[string]interface{}{"firstName": "Hacked"})
	c.Params = gin.Params{{Key: "id", Value: "p1"}}
	h.UpdatePersonWithPermission(c)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
}

// A member owns their story, not the shape of the tree.
func TestMemberCannotRewriteTheirOwnRelationships(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	member := makeUser(t, db, "member", models.RoleMember)

	db.Create(&models.Person{
		ID:            "p1",
		FirstName:     "Sara",
		AuthUserID:    member.ID,
		IsDeceased:    false,
		Relationships: models.Relationships{ParentIDs: []string{"mum"}},
	})

	c, rec := as(member, http.MethodPut, "/api/persons/p1", map[string]interface{}{
		"bio":           "A new bio",
		"isDeceased":    true,
		"displayOrder":  99,
		"relationships": map[string]interface{}{"parents": []string{"someone-else"}},
	})
	c.Params = gin.Params{{Key: "id", Value: "p1"}}
	h.UpdatePersonWithPermission(c)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var saved models.Person
	db.First(&saved, "id = ?", "p1")

	if saved.Bio != "A new bio" {
		t.Errorf("the member's own bio should have been saved, got %q", saved.Bio)
	}
	if saved.IsDeceased {
		t.Error("a member must not be able to mark themselves deceased")
	}
	if saved.DisplayOrder != 0 {
		t.Errorf("display order should be untouched, got %d", saved.DisplayOrder)
	}
	if len(saved.Relationships.ParentIDs) != 1 || saved.Relationships.ParentIDs[0] != "mum" {
		t.Errorf("parents should be untouched, got %v", saved.Relationships.ParentIDs)
	}
}

func TestCreatePersonRejectsAnUnknownParent(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	c, rec := as(admin, http.MethodPost, "/api/admin/persons", map[string]interface{}{
		"firstName":     "Ghost",
		"relationships": map[string]interface{}{"parents": []string{"nobody"}},
	})
	h.CreatePerson(c)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestCreatePersonNeverTakesAuthUserIDFromTheRequest(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	c, rec := as(admin, http.MethodPost, "/api/admin/persons", map[string]interface{}{
		"firstName":  "Relative",
		"authUserId": admin.ID,
	})
	h.CreatePerson(c)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var saved models.Person
	db.First(&saved, "first_name = ?", "Relative")
	if saved.AuthUserID != "" {
		t.Fatalf("a new person must be unclaimed, got %q", saved.AuthUserID)
	}
}

// Deleting used to leave the deleted id behind in every relative's
// relationships forever.
func TestDeletePersonScrubsReferencesToThem(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	db.Create(&models.Person{ID: "gran"})
	db.Create(&models.Person{
		ID:            "mum",
		Relationships: models.Relationships{SiblingIDs: []string{"gran"}},
	})

	c, rec := as(admin, http.MethodDelete, "/api/admin/persons/gran", nil)
	c.Params = gin.Params{{Key: "id", Value: "gran"}}
	h.DeletePerson(c)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var mum models.Person
	db.First(&mum, "id = ?", "mum")
	if len(mum.Relationships.SiblingIDs) != 0 {
		t.Fatalf("reference to the deleted person survived: %v", mum.Relationships.SiblingIDs)
	}
}

func TestDeletePersonRefusesToOrphanChildren(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	db.Create(&models.Person{ID: "parent"})
	db.Create(&models.Person{
		ID:            "child",
		Relationships: models.Relationships{ParentIDs: []string{"parent"}},
	})

	c, rec := as(admin, http.MethodDelete, "/api/admin/persons/parent", nil)
	c.Params = gin.Params{{Key: "id", Value: "parent"}}
	h.DeletePerson(c)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected 409, got %d: %s", rec.Code, rec.Body.String())
	}
}

// The app used to delete a subtree with one request per descendant, so a
// failure partway left half a family gone.
func TestDeletePersonCascadesInOneRequest(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	db.Create(&models.Person{ID: "gran"})
	db.Create(&models.Person{ID: "mum", Relationships: models.Relationships{ParentIDs: []string{"gran"}}})
	db.Create(&models.Person{ID: "me", Relationships: models.Relationships{ParentIDs: []string{"mum"}}})
	db.Create(&models.Person{ID: "stranger"})

	c, rec := as(admin, http.MethodDelete, "/api/admin/persons/gran?cascade=true", nil)
	c.Params = gin.Params{{Key: "id", Value: "gran"}}
	h.DeletePerson(c)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var remaining int64
	db.Model(&models.Person{}).Count(&remaining)
	if remaining != 1 {
		t.Fatalf("expected only the stranger to survive, %d remain", remaining)
	}
}

// ------------------------------------------------------------------ posts ---

func TestCreatePostTakesTheAuthorFromTheToken(t *testing.T) {
	db := newDB(t)
	h := &PostHandler{DB: db, NotificationService: services.NewNotificationService(db)}
	member := makeUser(t, db, "sara", models.RoleMember)

	c, rec := as(member, http.MethodPost, "/api/posts", map[string]interface{}{
		"content":  "Hello family",
		"userId":   "somebody-else",
		"userName": "Somebody Else",
	})
	h.CreatePost(c)

	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", rec.Code, rec.Body.String())
	}

	var saved models.Post
	db.First(&saved)
	if saved.UserID != member.ID || saved.UserName != member.Name {
		t.Fatalf("author was taken from the body: %q / %q", saved.UserID, saved.UserName)
	}
}

func TestMemberCannotDeleteSomeoneElsesPost(t *testing.T) {
	db := newDB(t)
	h := &PostHandler{DB: db}
	member := makeUser(t, db, "member", models.RoleMember)

	db.Create(&models.Post{ID: "post1", UserID: "someone-else", Content: "Mine"})

	c, rec := as(member, http.MethodDelete, "/api/posts/post1", nil)
	c.Params = gin.Params{{Key: "id", Value: "post1"}}
	h.DeletePost(c)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
}

func TestAdminCanDeleteAnyPost(t *testing.T) {
	db := newDB(t)
	h := &PostHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	db.Create(&models.Post{ID: "post1", UserID: "someone-else", Content: "Theirs"})

	c, rec := as(admin, http.MethodDelete, "/api/posts/post1", nil)
	c.Params = gin.Params{{Key: "id", Value: "post1"}}
	h.DeletePost(c)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestGetPostsPagesAndReportsMore(t *testing.T) {
	db := newDB(t)
	h := &PostHandler{DB: db}
	member := makeUser(t, db, "member", models.RoleMember)

	base := time.Now().Add(-time.Hour)
	for i := 0; i < 5; i++ {
		db.Create(&models.Post{
			ID:        uuid.New().String(),
			UserID:    member.ID,
			Content:   "post",
			CreatedAt: base.Add(time.Duration(i) * time.Minute),
		})
	}

	c, rec := as(member, http.MethodGet, "/api/posts?limit=2", nil)
	h.GetPosts(c)

	body := decode(t, rec)
	posts, _ := body["posts"].([]interface{})
	if len(posts) != 2 {
		t.Fatalf("expected 2 posts, got %d", len(posts))
	}
	if body["hasMore"] != true {
		t.Error("hasMore should be true")
	}
	if body["nextCursor"] == "" {
		t.Error("a cursor should be offered when more remain")
	}
}

// Two taps used to be a read-then-write, so simultaneous reactions raced.
func TestToggleReactionIsIdempotentPerUser(t *testing.T) {
	db := newDB(t)
	h := &PostHandler{DB: db}
	member := makeUser(t, db, "member", models.RoleMember)
	db.Create(&models.Post{ID: "post1", UserID: member.ID})

	react := func(emoji string) int {
		c, rec := as(member, http.MethodPost, "/api/posts/post1/reactions",
			map[string]string{"emoji": emoji})
		c.Params = gin.Params{{Key: "id", Value: "post1"}}
		h.ToggleReaction(c)
		return rec.Code
	}

	react("❤️")
	react("👍") // change it
	var count int64
	db.Model(&models.Reaction{}).Where("post_id = ?", "post1").Count(&count)
	if count != 1 {
		t.Fatalf("a member should hold exactly one reaction, got %d", count)
	}

	react("👍") // same again removes it
	db.Model(&models.Reaction{}).Where("post_id = ?", "post1").Count(&count)
	if count != 0 {
		t.Fatalf("reacting with the same emoji should clear it, got %d", count)
	}

	// And the row is really gone, so the unique index does not block a new one.
	if code := react("🎉"); code != http.StatusOK && code != http.StatusCreated {
		t.Fatalf("re-reacting after removal failed with %d", code)
	}
}

func TestReactingToAMissingPostIs404(t *testing.T) {
	db := newDB(t)
	h := &PostHandler{DB: db}
	member := makeUser(t, db, "member", models.RoleMember)

	c, rec := as(member, http.MethodPost, "/api/posts/ghost/reactions",
		map[string]string{"emoji": "❤️"})
	c.Params = gin.Params{{Key: "id", Value: "ghost"}}
	h.ToggleReaction(c)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}
}

// An admin may remove a comment but not rewrite what somebody said.
func TestOnlyTheAuthorCanEditAComment(t *testing.T) {
	db := newDB(t)
	h := &PostHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	db.Create(&models.Comment{ID: "c1", PostID: "p1", UserID: "someone-else", Text: "Said"})

	c, rec := as(admin, http.MethodPut, "/api/comments/c1", map[string]string{"text": "Rewritten"})
	c.Params = gin.Params{{Key: "id", Value: "c1"}}
	h.UpdateComment(c)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", rec.Code)
	}
}

// "@Sara Tesfaye" used to look for a user literally named "Sara".
func TestMentionsMatchNamesWithSpaces(t *testing.T) {
	db := newDB(t)
	notifications := services.NewNotificationService(db)
	h := &PostHandler{DB: db, NotificationService: notifications}

	author := makeUser(t, db, "commenter", models.RoleMember)
	mentioned := models.User{
		ID: uuid.New().String(), Email: "sara@test.local", Name: "Sara Tesfaye",
	}
	db.Create(&mentioned)

	h.notifyMentioned(models.Comment{
		ID: "c1", PostID: "p1", UserID: author.ID, UserName: author.Name,
		Text: "Ask @Sara Tesfaye about it",
	}, models.Post{ID: "p1", UserID: author.ID})

	var count int64
	db.Model(&models.Notification{}).Where("user_id = ?", mentioned.ID).Count(&count)
	if count != 1 {
		t.Fatalf("expected Sara Tesfaye to be notified once, got %d", count)
	}
}

func TestMentionsDoNotNotifyTheCommenter(t *testing.T) {
	db := newDB(t)
	h := &PostHandler{DB: db, NotificationService: services.NewNotificationService(db)}
	author := makeUser(t, db, "Selam", models.RoleMember)

	h.notifyMentioned(models.Comment{
		ID: "c1", PostID: "p1", UserID: author.ID, UserName: author.Name,
		Text: "@Selam talking to myself",
	}, models.Post{ID: "p1", UserID: "other"})

	var count int64
	db.Model(&models.Notification{}).Count(&count)
	if count != 0 {
		t.Fatalf("the commenter should not be notified, got %d", count)
	}
}

// ------------------------------------------------------------------- etag ---

func TestETagMatching(t *testing.T) {
	const etag = `"abc123"`

	for _, tc := range []struct {
		header string
		want   bool
	}{
		{`"abc123"`, true},
		{`W/"abc123"`, true},
		{`"other", "abc123"`, true},
		{`*`, true},
		{`"other"`, false},
		{``, false},
	} {
		if got := etagMatches(tc.header, etag); got != tc.want {
			t.Errorf("etagMatches(%q) = %v, want %v", tc.header, got, tc.want)
		}
	}
}

// Once an admin can move people around, the loop they can create is the
// dangerous one: a person placed under their own grandchild produced a cycle
// that every traversal in the app then walked until its stack ran out.
func TestUpdateRefusesToPutSomebodyBelowTheirOwnDescendant(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	db.Create(&models.Person{ID: "gran", FirstName: "Gran"})
	db.Create(&models.Person{
		ID:            "mum",
		FirstName:     "Mum",
		Relationships: models.Relationships{ParentIDs: []string{"gran"}},
	})
	db.Create(&models.Person{
		ID:            "me",
		FirstName:     "Me",
		Relationships: models.Relationships{ParentIDs: []string{"mum"}},
	})

	c, rec := as(admin, http.MethodPut, "/api/admin/persons/gran",
		map[string]interface{}{
			"relationships": map[string]interface{}{"parents": []string{"me"}},
		})
	c.Params = gin.Params{{Key: "id", Value: "gran"}}
	h.UpdatePersonWithPermission(c)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d: %s", rec.Code, rec.Body.String())
	}

	var gran models.Person
	db.First(&gran, "id = ?", "gran")
	if len(gran.Relationships.ParentIDs) != 0 {
		t.Fatalf("the move should not have been saved, got %v",
			gran.Relationships.ParentIDs)
	}
}

// Moving somebody sideways — to a different parent who is not below them — is
// the ordinary case and must still work.
func TestAdminCanMoveSomebodyToADifferentParent(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	db.Create(&models.Person{ID: "dad", FirstName: "Dad"})
	db.Create(&models.Person{ID: "uncle", FirstName: "Uncle"})
	db.Create(&models.Person{
		ID:            "kid",
		FirstName:     "Kid",
		Relationships: models.Relationships{ParentIDs: []string{"dad"}},
	})

	c, rec := as(admin, http.MethodPut, "/api/admin/persons/kid",
		map[string]interface{}{
			"relationships": map[string]interface{}{"parents": []string{"uncle"}},
		})
	c.Params = gin.Params{{Key: "id", Value: "kid"}}
	h.UpdatePersonWithPermission(c)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var kid models.Person
	db.First(&kid, "id = ?", "kid")
	if len(kid.Relationships.ParentIDs) != 1 ||
		kid.Relationships.ParentIDs[0] != "uncle" {
		t.Fatalf("expected the new parent, got %v", kid.Relationships.ParentIDs)
	}
}

func TestUpdateRefusesADuplicateParent(t *testing.T) {
	db := newDB(t)
	h := &PersonHandler{DB: db}
	admin := makeUser(t, db, "admin", models.RoleAdmin)

	db.Create(&models.Person{ID: "dad", FirstName: "Dad"})
	db.Create(&models.Person{ID: "kid", FirstName: "Kid"})

	c, rec := as(admin, http.MethodPut, "/api/admin/persons/kid",
		map[string]interface{}{
			"relationships": map[string]interface{}{
				"parents": []string{"dad", "dad"},
			},
		})
	c.Params = gin.Params{{Key: "id", Value: "kid"}}
	h.UpdatePersonWithPermission(c)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}
}
