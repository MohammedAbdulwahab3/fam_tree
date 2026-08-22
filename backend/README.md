# 🌳 Family Tree - Go Backend

<div align="center">

**A powerful, self-hosted REST API backend for the Family Tree application**

[![Go Version](https://img.shields.io/badge/Go-1.21-00ADD8?style=flat&logo=go)](https://go.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?style=flat&logo=postgresql)](https://www.postgresql.org/)
[![Firebase](https://img.shields.io/badge/Firebase-Auth-FFCA28?style=flat&logo=firebase)](https://firebase.google.com/)
[![Deployed on Render](https://img.shields.io/badge/Deployed%20on-Render-46E3B7?style=flat)](https://render.com)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
- [API Documentation](#-api-documentation)
- [Admin Utilities](#-admin-utilities)
- [Deployment](#-deployment)
- [Development](#-development)

---

## 🎯 Overview

This is a production-ready REST API backend for managing family trees, built with **Go**, **Gin**, **GORM**, and **PostgreSQL**. It provides complete family management features including person profiles, family posts, events, messaging, and role-based access control.

### Tech Stack

- **Language:** Go 1.21
- **Web Framework:** Gin
- **Database:** PostgreSQL
- **ORM:** GORM
- **Authentication:** Firebase Auth (ID Token Verification)
- **Deployment:** Render
- **Storage:** Local file system (uploads)

---

## ✨ Features

### Core Features
- 👤 **Person Management** - Complete CRUD operations for family members
- 📝 **Family Posts** - Share updates, photos, and stories
- 📅 **Events** - Create and manage family events with RSVP
- 💬 **Messaging** - Real-time family chat system
- 🔐 **Authentication** - Firebase ID token verification
- 👑 **Role-Based Access** - Admin and member roles

### Technical Features
- ✅ RESTful API design
- ✅ JWT token authentication
- ✅ File upload support
- ✅ Database seeding
- ✅ CORS enabled
- ✅ Auto-migration
- ✅ Admin utilities

---

## 🏗️ Architecture

```
backend/
├── auth/           # JWT token utilities
├── handlers/       # HTTP request handlers
│   ├── auth.go
│   ├── person.go
│   ├── post.go
│   ├── event.go
│   ├── message.go
│   └── upload.go
├── middleware/     # HTTP middlewares
│   ├── auth.go     # Firebase token verification
│   └── admin.go    # Admin access control
├── models/         # Database models
│   ├── user.go
│   ├── person.go
│   └── post.go
├── seed/           # Database seeding
│   └── seed.go
├── uploads/        # File uploads directory
├── main.go         # Application entry point
├── make_admin.go   # Admin promotion utility
└── render.yaml     # Render deployment config
```

---

## 🚀 Getting Started

### Prerequisites

- **Go 1.21+** ([Download](https://go.dev/dl/))
- **PostgreSQL 15+** ([Download](https://www.postgresql.org/download/))
- **Firebase Project** with service account credentials

### 1. Clone the Repository

```bash
git clone https://github.com/MohammedAbdulwahab3/tree.git
cd tree
```

### 2. Install Dependencies

```bash
go mod download
```

### 3. Setup PostgreSQL Database

```bash
# Create database
createdb family_tree

# Or using psql
psql -U postgres -c "CREATE DATABASE family_tree;"
```

See [POSTGRES_SETUP.md](POSTGRES_SETUP.md) for detailed database setup instructions.

### 4. Configure Environment Variables

Create a `.env` file or set environment variables:

```bash
# Database Configuration
export DATABASE_URL="host=127.0.0.1 user=postgres password=postgres dbname=family_tree port=5432 sslmode=disable"

# Firebase Credentials (as JSON string)
export FIREBASE_CREDENTIALS='{"type":"service_account","project_id":"your-project",...}'

# Or point to credentials file
# FIREBASE_CREDENTIALS will be loaded from firebase-credentials.json if not set
```

### 5. Run the Server

```bash
# Start the server
go run main.go

# Or build and run
go build -o server .
./server
```

Server will start on **http://localhost:8080** 🎉

### 6. (Optional) Seed the Database

```bash
go run main.go --seed
```

This will create:
- Sample persons (Adam, Eve, Cain, Abel, Seth)
- Sample posts, events, and messages
- Default admin user (`admin@familytree.com`)

---

## 📚 API Documentation

### Base URL

- **Local:** `http://localhost:8080`
- **Production:** `https://your-app.onrender.com`

### Authentication

Most endpoints require authentication via Firebase ID token:

```bash
Authorization: Bearer <FIREBASE_ID_TOKEN>
```

---

### Public Endpoints

#### Health Check
```http
GET /ping
```

#### User Registration (Legacy)
```http
POST /register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe"
}
```

#### Public Persons List
```http
GET /public/persons
```

---

### Protected Endpoints

All `/api/*` endpoints require authentication.

#### Get Current User
```http
GET /api/me
Authorization: Bearer <token>
```

#### Person Management

```http
# List all persons
GET /api/persons

# Get specific person
GET /api/persons/:id

# Update own profile (or admin can update any)
PUT /api/persons/:id
Content-Type: application/json

{
  "name": "Updated Name",
  "birth_date": "1990-01-01",
  "gender": "male"
}
```

#### Posts

```http
# Get all posts
GET /api/posts

# Get post comments
GET /api/posts/:id/comments

# Toggle reaction
POST /api/posts/:id/reactions
Content-Type: application/json

{
  "reaction_type": "like"
}

# Add comment
POST /api/posts/:id/comments
Content-Type: application/json

{
  "content": "Great post!"
}
```

#### Events

```http
# Get all events
GET /api/events

# Toggle RSVP
POST /api/events/:id/rsvp
Content-Type: application/json

{
  "status": "attending"
}
```

#### Messages

```http
# Get messages
GET /api/messages

# Send message
POST /api/messages
Content-Type: application/json

{
  "content": "Hello family!"
}
```

#### File Upload

```http
POST /api/upload
Content-Type: multipart/form-data

file: <binary_file>
```

**Response:**
```json
{
  "url": "/uploads/filename.jpg"
}
```

---

### Admin Endpoints

All `/api/admin/*` endpoints require **admin role**.

#### User Management

```http
# List all users
GET /api/admin/users

# Update user role
PUT /api/admin/users/:id/role
Content-Type: application/json

{
  "role": "admin"
}
```

#### Person Management (Admin Only)

```http
# Create person
POST /api/admin/persons
Content-Type: application/json

{
  "name": "New Person",
  "birth_date": "1990-01-01",
  "gender": "male"
}

# Update any person
PUT /api/admin/persons/:id

# Delete person
DELETE /api/admin/persons/:id
```

#### Post Management (Admin Only)

```http
# Create post
POST /api/admin/posts
Content-Type: multipart/form-data

content: "Post content"
media_urls: ["url1", "url2"]

# Delete post
DELETE /api/admin/posts/:id
```

#### Event Management (Admin Only)

```http
# Create event
POST /api/admin/events
Content-Type: application/json

{
  "title": "Family Reunion",
  "description": "Annual gathering",
  "event_date": "2025-12-25T10:00:00Z",
  "location": "New York"
}

# Delete event
DELETE /api/admin/events/:id
```

---

## 👑 Admin Utilities

### Promote User to Admin

#### Method 1: Using Go Script (Local/Production)

```bash
# Make most recent user an admin
go run cmd/make_admin/main.go

# Make specific user an admin by email
go run cmd/make_admin/main.go user@example.com

# Make specific user an admin by ID
go run cmd/make_admin/main.go <user_id>
```

#### Method 2: Direct Database (Production)

Using Render's database shell:

```sql
UPDATE users SET role = 'admin' WHERE email = 'user@example.com';
```

#### Method 3: Using API (Requires existing admin)

```http
PUT /api/admin/users/:id/role
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "role": "admin"
}
```

---

## 🚢 Deployment

### Deploy to Render

This project includes a `render.yaml` blueprint for easy deployment.

#### Prerequisites
1. Create a [Render](https://render.com) account
2. Push code to GitHub repository
3. Prepare Firebase credentials as environment variable

#### Steps

1. **Create PostgreSQL Database**
   - New → PostgreSQL
   - Name: `family-tree-db`
   - Plan: Free

2. **Create Web Service**
   - New → Blueprint
   - Connect your GitHub repository
   - Select `backend/render.yaml`

3. **Set Environment Variables**
   
   In Render dashboard, add:
   
   ```
   FIREBASE_CREDENTIALS = <paste_your_firebase_credentials_json>
   GIN_MODE = release
   ```

4. **Deploy**
   
   Render will automatically:
   - Build the Go application
   - Connect to PostgreSQL
   - Start the server on port 8080
   - Deploy on a `.onrender.com` URL

5. **(Optional) Seed Database**
   
   In Render shell:
   ```bash
   ./server --seed
   ```

### Manual Deployment

```bash
# Build for Linux
GOOS=linux GOARCH=amd64 go build -o server .

# Upload to your server and run
./server
```

---

## 🛠️ Development

### Running Locally

```bash
# Start with hot reload (using air or similar)
air

# Or just run
go run main.go
```

### Database Migrations

GORM auto-migrates on startup, but you can trigger manually:

```go
db.AutoMigrate(&models.User{}, &models.Person{}, &models.Post{}, &models.Event{}, &models.Message{})
```

### Testing

```bash
# Test health endpoint
curl http://localhost:8080/ping

# Test with authentication
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/persons
```

### Project Structure Best Practices

- **Handlers:** Keep business logic minimal, delegate to services
- **Models:** Define database schema and relationships
- **Middleware:** Handle cross-cutting concerns (auth, logging, etc.)
- **Keep it simple:** Favor readability over cleverness

---

## 📝 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `host=127.0.0.1 user=postgres password=postgres dbname=family_tree port=5432 sslmode=disable` |
| `FIREBASE_CREDENTIALS` | Firebase service account JSON | Reads from `firebase-credentials.json` |
| `GIN_MODE` | Gin mode (debug/release) | `debug` |
| `PORT` | Server port | `8080` |

### Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create or select your project
3. Go to Project Settings → Service Accounts
4. Click "Generate New Private Key"
5. Save as `firebase-credentials.json` or set as `FIREBASE_CREDENTIALS` env var

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is private and proprietary.

---

## 🐛 Troubleshooting

### Database Connection Issues

```bash
# Check PostgreSQL is running
pg_isready

# Test connection
psql -U postgres -d family_tree -c "SELECT 1;"
```

### Firebase Auth Issues

- Ensure `FIREBASE_CREDENTIALS` is valid JSON
- Check Firebase project ID matches your Flutter app
- Verify SHA-1 fingerprint is registered in Firebase Console

### Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>
```

---

## 📞 Support

For issues or questions:
- Open an issue on GitHub
- Contact: maw3c3@gmail.com

---

<div align="center">

**Built with ❤️ using Go and PostgreSQL**

</div>
