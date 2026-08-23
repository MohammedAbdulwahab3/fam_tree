package models

import (
	"testing"
	"time"
)

func person(id string, parents ...string) Person {
	return Person{
		ID:            id,
		Relationships: Relationships{ParentIDs: parents},
	}
}

func TestDeriveChildrenBuildsTheReverseDirection(t *testing.T) {
	people := []Person{
		person("gran"),
		person("mum", "gran"),
		person("uncle", "gran"),
		person("me", "mum"),
	}

	DeriveChildren(people)

	byID := map[string]Person{}
	for _, p := range people {
		byID[p.ID] = p
	}

	if got := byID["gran"].Relationships.ChildrenIDs; len(got) != 2 {
		t.Fatalf("gran should have 2 children, got %v", got)
	}
	if got := byID["mum"].Relationships.ChildrenIDs; len(got) != 1 || got[0] != "me" {
		t.Fatalf("mum should have exactly [me], got %v", got)
	}
	if got := byID["me"].Relationships.ChildrenIDs; len(got) != 0 {
		t.Fatalf("me should have no children, got %v", got)
	}
}

// A child names both parents, and both parents must list them. The tree layout
// used to attach such a child to whichever parent it saw last and draw the
// other one as childless.
func TestDeriveChildrenHandlesTwoParents(t *testing.T) {
	people := []Person{
		person("dad"),
		person("mum"),
		person("kid", "dad", "mum"),
	}

	DeriveChildren(people)

	for _, p := range people[:2] {
		if len(p.Relationships.ChildrenIDs) != 1 {
			t.Errorf("%s should list the child, got %v", p.ID, p.Relationships.ChildrenIDs)
		}
	}
}

func TestDeriveChildrenReplacesRatherThanAppends(t *testing.T) {
	people := []Person{
		{ID: "a", Relationships: Relationships{ChildrenIDs: []string{"ghost"}}},
		person("b", "a"),
	}

	DeriveChildren(people)

	got := people[0].Relationships.ChildrenIDs
	if len(got) != 1 || got[0] != "b" {
		t.Fatalf("stale child should be gone, got %v", got)
	}
}

func TestDeriveChildrenIgnoresParentsOutsideTheSlice(t *testing.T) {
	people := []Person{person("orphan", "not-in-tree")}

	DeriveChildren(people)

	if got := people[0].Relationships.ChildrenIDs; len(got) != 0 {
		t.Fatalf("expected empty children, got %v", got)
	}
}

func TestPrunePersonReferencesClearsEveryDirection(t *testing.T) {
	people := []Person{
		{ID: "gone"},
		{ID: "child", Relationships: Relationships{ParentIDs: []string{"gone", "mum"}}},
		{ID: "sib", Relationships: Relationships{SiblingIDs: []string{"gone"}}},
		{ID: "spouse", Relationships: Relationships{
			Spouses: []RelationshipConnection{{PersonID: "gone"}, {PersonID: "other"}},
		}},
		{ID: "unrelated", Relationships: Relationships{ParentIDs: []string{"mum"}}},
	}

	changed := PrunePersonReferences(people, map[string]bool{"gone": true})

	if len(changed) != 3 {
		t.Fatalf("expected 3 repaired records, got %d", len(changed))
	}
	if got := people[1].Relationships.ParentIDs; len(got) != 1 || got[0] != "mum" {
		t.Errorf("child should keep only mum, got %v", got)
	}
	if got := people[2].Relationships.SiblingIDs; len(got) != 0 {
		t.Errorf("sibling reference should be gone, got %v", got)
	}
	if got := people[3].Relationships.Spouses; len(got) != 1 || got[0].PersonID != "other" {
		t.Errorf("spouse reference should be gone, got %v", got)
	}
}

func TestDescendantIDsIncludesTheWholeSubtree(t *testing.T) {
	people := []Person{
		person("root"),
		person("kid", "root"),
		person("grandkid", "kid"),
		person("stranger"),
	}

	got := DescendantIDs(people, "root")

	for _, want := range []string{"root", "kid", "grandkid"} {
		if !got[want] {
			t.Errorf("%s should be in the subtree", want)
		}
	}
	if got["stranger"] {
		t.Error("stranger should not be in the subtree")
	}
}

// A cycle is producible through the admin UI, and used to recurse until the
// stack ran out rather than returning an answer.
func TestDescendantIDsTerminatesOnACycle(t *testing.T) {
	people := []Person{
		person("a", "b"),
		person("b", "a"),
	}

	done := make(chan map[string]bool, 1)
	go func() { done <- DescendantIDs(people, "a") }()

	select {
	case got := <-done:
		if !got["a"] || !got["b"] {
			t.Fatalf("both should be reachable, got %v", got)
		}
	case <-time.After(time.Second):
		t.Fatal("DescendantIDs did not terminate on a cyclic tree")
	}
}
