package seed

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"family-tree-backend/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Arabic male first names
var maleFirstNames = []string{
	"Ahmed", "Ali", "Omar", "Youssef", "Hassan", "Hussein", "Khalid", "Abdulrahman", "Abdallah", "Ibrahim",
	"Ismail", "Younis", "Saleh", "Saeed", "Nasser", "Faisal", "Sultan", "Hamad", "Rashid", "Majid",
	"Tariq", "Waleed", "Samir", "Karim", "Jamal", "Adel", "Mansour", "Fahad", "Badr", "Zayed",
	"Hamza", "Bilal", "Ayman", "Marwan", "Hisham", "Osama", "Rami", "Sami", "Nabil", "Wael",
	"Amr", "Mustafa", "Mahmoud", "Tarek", "Ashraf", "Hazem", "Hatem", "Bassam", "Imad", "Ziyad",
}

var bios = []string{
	"A loving family member who enjoys spending time with relatives.",
	"Known for their warm smile and generous heart.",
	"The storyteller of the family, always sharing memories.",
	"A dedicated parent and grandparent.",
	"Passionate about keeping family traditions alive.",
	"The adventurer who traveled the world.",
	"A talented cook known for family recipes.",
	"The family historian who keeps records.",
	"Always the first to help in times of need.",
	"Brought joy and laughter to every gathering.",
}

// Structure to hold person and index for relationship building
type personEntry struct {
	person   models.Person
	parentID string
}

func SeedDatabase(db *gorm.DB) {
	log.Println("🌱 Seeding Mohammed's family tree (100 persons)...")

	// Run migrations first
	db.AutoMigrate(&models.Person{}, &models.User{})

	// Clear existing data (ignore errors if table doesn't exist)
	db.Exec("DELETE FROM people WHERE 1=1")

	rand.Seed(time.Now().UnixNano())

	familyTreeID := "main-family-tree"
	allPersons := make([]models.Person, 0, 100)

	// ==========================================
	// Generation 1: Mohammed (the patriarch)
	// ==========================================
	mohammed := createMalePerson("Mohammed", 1940, familyTreeID)
	mohammedIdx := 0
	allPersons = append(allPersons, mohammed)

	// ==========================================
	// Generation 2: Mohammed's 4 sons
	// ==========================================
	gen2Names := []string{"Ahmed", "Ali", "Omar", "Youssef"}
	gen2Indices := make([]int, 4)

	for i, name := range gen2Names {
		son := createMalePerson(name, 1965+rand.Intn(5), familyTreeID)
		son.Relationships = models.Relationships{
			ParentIDs: []string{mohammed.ID},
		}
		gen2Indices[i] = len(allPersons)
		allPersons = append(allPersons, son)
		allPersons[mohammedIdx].Relationships.ChildrenIDs = append(
			allPersons[mohammedIdx].Relationships.ChildrenIDs, son.ID)
	}

	// ==========================================
	// Generation 3: Each of the 4 sons has 4 sons (16 total)
	// ==========================================
	gen3Indices := make([]int, 0, 16)

	for _, parentIdx := range gen2Indices {
		for j := 0; j < 4; j++ {
			name := maleFirstNames[rand.Intn(len(maleFirstNames))]
			grandson := createMalePerson(name, 1985+rand.Intn(5), familyTreeID)
			grandson.Relationships = models.Relationships{
				ParentIDs: []string{allPersons[parentIdx].ID},
			}
			gen3Indices = append(gen3Indices, len(allPersons))
			allPersons = append(allPersons, grandson)
			allPersons[parentIdx].Relationships.ChildrenIDs = append(
				allPersons[parentIdx].Relationships.ChildrenIDs, grandson.ID)
		}
	}

	// ==========================================
	// Generation 4: Each of the 16 grandsons has 3 sons (48 total)
	// ==========================================
	gen4Indices := make([]int, 0, 48)

	for _, parentIdx := range gen3Indices {
		for j := 0; j < 3; j++ {
			name := maleFirstNames[rand.Intn(len(maleFirstNames))]
			greatGrandson := createMalePerson(name, 2000+rand.Intn(5), familyTreeID)
			greatGrandson.Relationships = models.Relationships{
				ParentIDs: []string{allPersons[parentIdx].ID},
			}
			gen4Indices = append(gen4Indices, len(allPersons))
			allPersons = append(allPersons, greatGrandson)
			allPersons[parentIdx].Relationships.ChildrenIDs = append(
				allPersons[parentIdx].Relationships.ChildrenIDs, greatGrandson.ID)
		}
	}

	// ==========================================
	// Generation 5: First 31 great-grandsons get 1 son each (to reach 100 total)
	// Total: 1 + 4 + 16 + 48 + 31 = 100
	// ==========================================
	gen5Count := 0
	maxGen5 := 31 // To reach exactly 100

	for i, parentIdx := range gen4Indices {
		if i >= maxGen5 {
			break
		}
		name := maleFirstNames[rand.Intn(len(maleFirstNames))]
		greatGreatGrandson := createMalePerson(name, 2015+rand.Intn(5), familyTreeID)
		greatGreatGrandson.Relationships = models.Relationships{
			ParentIDs: []string{allPersons[parentIdx].ID},
		}
		allPersons = append(allPersons, greatGreatGrandson)
		allPersons[parentIdx].Relationships.ChildrenIDs = append(
			allPersons[parentIdx].Relationships.ChildrenIDs, greatGreatGrandson.ID)
		gen5Count++
	}

	// Save all persons to database
	for i, person := range allPersons {
		if err := db.Create(&person).Error; err != nil {
			log.Printf("Error creating person %d: %v", i, err)
		}
	}

	// Create a default admin user
	adminUser := models.User{
		ID:    "admin-default",
		Email: "admin@familytree.com",
		Name:  "Admin",
		Role:  models.RoleAdmin,
	}
	db.FirstOrCreate(&adminUser, models.User{ID: "admin-default"})

	log.Printf("✅ Database seeded successfully with %d family members!", len(allPersons))
	log.Println("📊 Mohammed's Family Tree:")
	log.Println("   - Gen 1 (Mohammed): 1 person")
	log.Println("   - Gen 2 (Sons): 4 people")
	log.Println("   - Gen 3 (Grandsons): 16 people")
	log.Println("   - Gen 4 (Great-Grandsons): 48 people")
	log.Printf("   - Gen 5 (Great-Great-Grandsons): %d people", gen5Count)
	log.Println("👤 Default admin user created: admin@familytree.com")
}

func createMalePerson(firstName string, birthYear int, familyTreeID string) models.Person {
	birthMonth := rand.Intn(12) + 1
	birthDay := rand.Intn(28) + 1
	birthDate := parseDate(fmt.Sprintf("%d-%02d-%02d", birthYear, birthMonth, birthDay))

	// Older generations may have passed
	var deathDate *time.Time
	if birthYear < 1960 && rand.Float32() > 0.5 {
		deathYear := birthYear + 60 + rand.Intn(25)
		if deathYear <= time.Now().Year() {
			deathDate = parseDate(fmt.Sprintf("%d-%02d-%02d", deathYear, rand.Intn(12)+1, rand.Intn(28)+1))
		}
	}

	return models.Person{
		ID:           uuid.New().String(),
		FamilyTreeID: familyTreeID,
		FirstName:    firstName,
		LastName:     "Al-Mohammed",
		Gender:       "male",
		BirthDate:    birthDate,
		DeathDate:    deathDate,
		Bio:          bios[rand.Intn(len(bios))],
	}
}

func parseDate(dateStr string) *time.Time {
	t, _ := time.Parse("2006-01-02", dateStr)
	return &t
}
