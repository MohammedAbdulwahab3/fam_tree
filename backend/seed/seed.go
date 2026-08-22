package seed

import (
	"log"
	"time"

	"family-tree-backend/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

const DefaultFamilyTreeID = "main-family-tree"

type Node struct {
	FirstName string
	LastName  string
	Gender    string
	Children  []Node
}

func n(firstName, lastName, gender string, children ...Node) Node {
	return Node{
		FirstName: firstName,
		LastName:  lastName,
		Gender:    gender,
		Children:  children,
	}
}

// Complete Mammaduu Family Tree matching family_tree_local
var familyTreeNodes = []Node{
	n("Mammaduu", "Family", "male",
		n("Issa", "Mammaduu", "male",
			n("MohammedSani", "Issa", "male"),
			n("Makkah", "Issa", "male"),
			n("Suleyman", "Issa", "male"),
			n("Jemila", "Issa", "female"),
			n("Kulsum", "Issa", "female"),
		),
		n("Osman", "Mammaduu", "male",
			n("Muzeyen", "Osman", "male",
				n("Oumer", "Muzeyen", "male",
					n("Mohammed", "Oumer", "male"),
					n("Saeeda", "Oumer", "female"),
					n("Ahmed", "Oumer", "male"),
					n("Seid", "Oumer", "male"),
					n("Jihan", "Oumer", "female"),
					n("Anwar", "Oumer", "male"),
					n("Wahib", "Oumer", "male"),
					n("Ihsan", "Oumer", "male"),
				),
				n("Seid", "Muzeyen", "male",
					n("Eliyas", "seid", "male",
						n("Mina", "Elias", "female"),
						n("Seberina", "Elias", "female"),
						n("Yasmin", "Elias", "female"),
						n("Semhar", "Elias", "female"),
					),
					n("Yusuf", "seid", "male"),
					n("Yunus", "seid", "male",
						n("Riham", "Yunus", "female"),
						n("Imran", "Yunus", "male"),
						n("Isam", "Yunus", "male"),
						n("Rami", "Yunus", "male"),
						n("Reyan", "Yunus", "male"),
						n("Isra", "Yunus", "female"),
						n("Yumna", "Yunus", "female"),
					),
					n("Zeki", "seid", "male",
						n("Ayub", "zeki", "male"),
						n("Ahmed", "Zeki", "male"),
					),
					n("Ishaq", "seid", "male",
						n("Jemil", "Ishaq", "male"),
						n("Hafsa", "Ishaq", "female"),
						n("Mohammed", "Ishaq", "male"),
					),
					n("Maki", "seid", "male",
						n("Berket", "Maki", "male"),
						n("Haniya", "Maki", "female"),
						n("Hanana", "Maki", "female"),
						n("Amru", "Maki", "male"),
					),
					n("Million", "seid", "male",
						n("Amrah", "Million", "female"),
						n("Eman", "Million", "female"),
						n("Ikhlas", "Million", "female"),
					),
					n("Abdu", "seid", "male",
						n("Amal", "Abdu", "female"),
						n("Mahi", "Abdu", "male"),
					),
					n("Seada", "seid", "female",
						n("Amir", "Seada", "male"),
						n("Oumer", "Seada", "male"),
						n("Yusra", "Seada", "female"),
						n("Ahmed", "Seada", "male"),
					),
					n("Taher", "Seid", "male",
						n("Mohammed", "Taher", "male"),
						n("Oumer", "Taher", "male"),
						n("Tesnim", "Taher", "female"),
					),
				),
				n("Osman", "Muzeyen", "male",
					n("Yusuf", "Osman", "male"),
					n("Zeyneb", "Osman", "female"),
					n("Fuad", "Osman", "male"),
				),
				n("Kheria", "Muzeyen", "female",
					n("Mohammed", "Muhaba", "male"),
					n("Abas", "Muhaba", "male"),
					n("Sulatan", "Muhaba", "male"),
				),
				n("Sofia", "Muzeyen", "female"),
				n("Hussein", "Muzeyen", "male",
					n("Mina", "Hussein", "female"),
					n("Lina", "Hussein", "male"),
				),
				n("Jemal", "Muzeyen", "male",
					n("Newal", "Jemal", "male"),
					n("Nehla", "Jemal", "female"),
					n("Mesud", "Jemal", "male"),
				),
				n("Abdellah", "Muzeyen", "male",
					n("Zeytuna", "Abdellah", "female"),
				),
				n("Temam", "Muzeyen", "male"),
				n("Ibrahim", "Muzeyen", "male"),
				n("Ali", "Muzeyen", "male"),
				n("Abdulhakim", "Muzeyen", "male",
					n("Mohammed", "Abdulhakim", "male",
						n("Khedija", "Mohammed", "female"),
						n("Abdulhakim", "Mohammed", "male"),
					),
				),
				n("Ayisha", "Muzeyen", "female"),
				n("Amina", "Muzeyen", "female",
					n("Reem", "Seid", "male",
						n("batool", "feysel", "female"),
					),
				),
				n("Rashid", "Muzeyen", "male"),
				n("Almaz", "Muzeyen", "female",
					n("Hayat", "Mohammed", "female",
						n("Mustefa", "Sami", "male"),
						n("Fatuma", "Sami", "female"),
						n("Yasin", "Sami", "male"),
					),
					n("Abdulrehman", "Mohammed", "male"),
					n("Umer", "Mohammed", "male"),
					n("Rahma", "Mohammed", "female",
						n("Adem", "Omer", "male"),
						n("Noria", "Omer", "female"),
						n("Mohammed", "Omer", "male"),
						n("Selhadin", "Omer", "male"),
						n("Seid", "Omer", "male"),
					),
					n("AbdulQadir", "Mohammed", "male"),
					n("Harun", "Mohammed", "male"),
					n("Hawa", "Mohammed", "female"),
					n("Nesib", "Mohammed", "male"),
					n("Hussien", "Mohammed", "male"),
					n("Yasin", "Mohammed", "male"),
					n("Eliyas", "Mohammed", "male"),
					n("Kheria", "Mohammed", "female"),
					n("India", "Mohammed", "female"),
				),
				n("Abubaker", "Muzeyen", "male"),
				n("Fatuma", "Muzeyen", "female"),
				n("Idris", "Muzeyen", "male",
					n("Khalid", "Idris", "male"),
					n("Ismaeel", "Idris", "male"),
				),
				n("Abdulkerim", "Muzeyen", "male",
					n("Mariam", "Abdulkerim", "female"),
					n("Issa", "Abdulkerim", "male"),
				),
				n("Zubaida", "Muzeyen", "female",
					n("Iftikahar", "MohammedAli", "female"),
					n("Ibtisam", "MohammedAli", "female"),
				),
				n("Nuru", "Muzeyen", "male",
					n("Yasmin", "Nuru", "male",
						n("Roya", "Idris", "female"),
					),
					n("Khalid", "Nuru", "male"),
					n("Adel", "Nuru", "male"),
					n("Emad", "Nuru", "male"),
					n("Menel", "Nuru", "female"),
				),
				n("Mohammed", "Muzeyen", "male",
					n("Muzeyen", "Mohammed", "male"),
					n("Nebil", "Mohammed", "male"),
					n("Ahmed", "Mohammed", "male"),
					n("Zamzam", "Mohammed", "female"),
					n("Abdulqadir", "Mohammed", "male"),
				),
			),
			n("Mohammed", "Osman", "male",
				n("Khedir", "Mohammed", "male",
					n("Kikiya", "Khedir", "male",
						n("Ahmed", "Kikiya", "male"),
						n("Amir", "Kikiya", "male"),
					),
					n("AbdulJabar", "Khedir", "male",
						n("Isamdin", "AbdulJebar", "male"),
						n("Imran", "Abduljebar", "male"),
						n("Nerjis", "Abduljebar", "female"),
						n("Nejwa", "Abduljebar", "male"),
						n("Newara", "Abduljebar", "male"),
						n("zikera", "Abduljebar", "male"),
						n("Bediuzeman", "Abduljebar", "male"),
						n("Beyan", "Abduljebar", "male"),
					),
					n("AbdulWahab", "Khedir", "male",
						n("Mohammed", "Abdulwahab", "male"),
						n("Jabir", "Abdulwahab", "male"),
						n("Rawan", "Abdulwahab", "male"),
						n("Fatima", "Abdulwahab", "male"),
					),
					n("AbdulBasit", "Khedir", "male",
						n("Firdows", "Abdulbasit", "female"),
						n("Inaya", "Abdulbasit", "male"),
						n("Faruq", "Abdulbasit", "male"),
					),
					n("Khalid", "Khedir", "male",
						n("MohammedSalih", "Khalid", "male"),
					),
				),
				n("Khedija", "Mohammed", "male",
					n("Rahma", "Abdu", "female"),
					n("Fatima", "Abdu", "male"),
					n("Mohammed", "Abdu", "male"),
					n("Nura", "Abdu", "female"),
					n("Sulayman", "Abdu", "male"),
					n("Khalid", "Abdu", "male"),
					n("Hussen", "Abdu", "male"),
					n("Yunus", "Abdu", "male"),
				),
			),
			n("Ruqiya", "Osman", "female"),
			n("Fantaye", "Osman", "female"),
			n("Mustefa", "Osman", "male",
				n("Adam", "Mustefa", "male"),
				n("AbdulQadir", "Mustefa", "male"),
				n("Khedir", "Mustefa", "male"),
				n("Temima", "Mustefa", "female",
					n("Eliyas", "MohammedAmin", "male"),
					n("Saliha", "MohammedAmin", "female"),
					n("Emebet", "MohammedAmin", "female"),
					n("Nebil", "MohammedAmin", "male"),
					n("Hussen", "MohammedAmin", "male"),
				),
				n("Fatima", "Mustefa", "female"),
				n("Jibrel", "Mustefa", "male",
					n("Rahma", "Jibrel", "female"),
					n("Temam", "Jibrel", "male"),
					n("Nejat", "Jibrel", "female"),
				),
			),
			n("Radiya", "Osman", "female"),
			n("Zame", "Osman", "female"),
		),
		n("Sheikh Mussa", "Mammaduu", "male",
			n("Dawud", "Mussa", "male"),
			n("Ibrahim", "Mussa", "male"),
			n("Ahmed", "Mussa", "male"),
			n("Hassen", "Mussa", "male"),
			n("Zeyneb", "Mussa", "female"),
		),
		n("Sheikh Abdu", "Mammaduu", "male",
			n("Abdulqadir", "Abdu", "male"),
			n("Yusuf", "Abdu", "male"),
			n("Jemila", "Abdu", "female"),
			n("Hawa", "Abdu", "female"),
			n("MohammedAmin", "Abdu", "male"),
		),
		n("Ibrahim", "Mammaduu", "male"),
		n("Hassen", "Mammaduu", "male"),
		n("Hussen", "Mammaduu", "male"),
	),
}

func SeedDatabase(db *gorm.DB) {
	log.Println("🌱 Seeding Mammaduu Family Tree...")

	// Run migrations first
	db.AutoMigrate(&models.Person{}, &models.User{})

	// Clear existing data
	if err := db.Exec("DELETE FROM people WHERE 1=1").Error; err != nil {
		log.Printf("Warning clearing people table: %v", err)
	}

	allPersons := make([]models.Person, 0, 200)
	childrenMap := make(map[string][]string)

	var buildSubtree func(nd Node, parentID string, displayOrder int, gen int)
	buildSubtree = func(nd Node, parentID string, displayOrder int, gen int) {
		personID := uuid.New().String()
		birthYear := 1900 + (gen * 25)
		birthDate := time.Date(birthYear, time.January, 1, 0, 0, 0, 0, time.UTC)

		parents := []string{}
		if parentID != "" {
			parents = append(parents, parentID)
		}

		p := models.Person{
			ID:           personID,
			FamilyTreeID: DefaultFamilyTreeID,
			FirstName:    nd.FirstName,
			LastName:     nd.LastName,
			Gender:       nd.Gender,
			BirthDate:    &birthDate,
			Bio:          "",
			Relationships: models.Relationships{
				ParentIDs: parents,
			},
			DisplayOrder: displayOrder,
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
		}

		personIdx := len(allPersons)
		allPersons = append(allPersons, p)

		if parentID != "" {
			childrenMap[parentID] = append(childrenMap[parentID], personID)
		}

		for i, child := range nd.Children {
			buildSubtree(child, personID, i, gen+1)
		}
		_ = personIdx
	}

	for i, root := range familyTreeNodes {
		buildSubtree(root, "", i, 0)
	}

	// Link children back to parent relationships
	for i := range allPersons {
		pID := allPersons[i].ID
		if kids, exists := childrenMap[pID]; exists && len(kids) > 0 {
			allPersons[i].Relationships.ChildrenIDs = kids
		}
	}

	// Batch insert all persons into DB
	for i, person := range allPersons {
		if err := db.Create(&person).Error; err != nil {
			log.Printf("Error creating person %d (%s %s): %v", i, person.FirstName, person.LastName, err)
		}
	}

	// Create default admin user if missing
	adminUser := models.User{
		ID:    "admin-default",
		Email: "admin@familytree.com",
		Name:  "Admin",
		Role:  models.RoleAdmin,
	}
	db.FirstOrCreate(&adminUser, models.User{ID: "admin-default"})

	log.Printf("✅ Mammaduu Family Tree seeded successfully with %d persons!", len(allPersons))
}
