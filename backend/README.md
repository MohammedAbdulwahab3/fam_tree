# 🌳 Family Tree - Go Backend

<div align="center">

**A powerful, self-hosted REST API backend for the Family Tree application**

[![Go Version](https://img.shields.io/badge/Go-1.21-00ADD8?style=flat&logo=go)](https://go.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?style=flat&logo=postgresql)](https://www.postgresql.org/)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
- [API Documentation](#-api-documentation)
- [Admin Utilities](#-admin-utilities)
- [Development](#-development)

---

## 🎯 Overview

This is a production-ready REST API backend for managing family trees, built with **Go**, **Gin**, **GORM**, and **PostgreSQL**. It provides complete family management features including person profiles, family posts, events, messaging, and role-based access control.

### Tech Stack

- **Language:** Go 1.21
- **Web Framework:** Gin
- **Database:** PostgreSQL
- **ORM:** GORM
- **Authentication:** JWT issued by this server (bcrypt password hashing)
- **Storage:** Local file system (uploads)

---

## ✨ Features

### Core Features
- 👤 **Person Management** - Complete CRUD operations for family members
- 📝 **Family Posts** - Share updates, photos, and stories
- 📅 **Events** - Create and manage family events with RSVP
- 💬 **Messaging** - Real-time family chat system
- 🔐 **Authentication** - Email and password, JWT sessions
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
│   ├── auth.go     # JWT verification, loads the user
│   └── admin.go    # Admin access control
├── models/         # Database models
│   ├── user.go
│   ├── person.go
│   └── post.go
├── seed/           # Database seeding
│   └── seed.go
├── uploads/        # File uploads directory
├── e2e/            # End-to-end API checks
└── main.go         # Application entry point
```

---

## 🚀 Getting Started

### Prerequisites

- **Go 1.21+** ([Download](https://go.dev/dl/))
- **PostgreSQL 15+** ([Download](https://www.postgresql.org/download/))
- **Docker** (optional) for the local Postgres in `docker-compose.yml`

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
# Required in anything but a local run — without it the server falls back to a
# development signing key and says so loudly at startup.
export JWT_SECRET="a-long-random-string"

# Database. Defaults to a local Postgres on 5432 if unset.
export DATABASE_URL="host=127.0.0.1 user=postgres password=postgres dbname=family_tree port=5432 sslmode=disable"

# Optional. How long a session lasts; defaults to 720h (30 days).
export TOKEN_TTL=720h

# Optional. Enables device push notifications. Without it, notifications still
# appear in the app — they just do not reach the lock screen.
export FIREBASE_CREDENTIALS='{"type":"service_account",...}'
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

### Authentication

Most endpoints require the JWT that `/login` or `/register` returned:

```bash
Authorization: Bearer <TOKEN>
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

#### Account

```http
# Change your own password
PUT /api/me/password
{ "currentPassword": "...", "newPassword": "..." }

# Delete your own account. Your person record stays in the tree, unclaimed.
DELETE /api/me
{ "password": "..." }

# Set a new password with a code an admin issued (public — you cannot sign in)
POST /reset-password
{ "email": "...", "code": "ABCD-1234", "newPassword": "..." }
```

#### Claiming Your Record

```http
# Ask to be linked to a person in the tree
POST /api/link-requests
{ "personId": "..." }

# Where your claim stands: not_linked | pending | rejected | verified.
# A rejection carries the admin's reason.
GET /api/link-requests/my-status

# Withdraw a claim that is still waiting
DELETE /api/link-requests/mine
```

#### Notifications

```http
GET    /api/notifications
GET    /api/notifications/unread-count
PUT    /api/notifications/:id/read
PUT    /api/notifications/read-all
DELETE /api/notifications/:id
DELETE /api/notifications
GET    /api/notifications/preferences
PUT    /api/notifications/preferences
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

Straight against the database:

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
# End-to-end checks, each against a throwaway database
./e2e/run.sh          # all phases
./e2e/run.sh 3        # one phase

# Health check
curl http://localhost:8080/ping
```

`e2e/` covers the API surface end to end: feed posting and deletion, comment and
event permissions, notification delivery and preferences, reminder scheduling,
the account-claim flow, and password reset. It needs the Postgres container from
`docker-compose.yml` running.

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
| `JWT_SECRET` | Signs session tokens. Set it. | insecure dev key, with a warning |
| `DATABASE_URL` | PostgreSQL connection string | `host=127.0.0.1 user=postgres password=postgres dbname=family_tree port=5432 sslmode=disable` |
| `TOKEN_TTL` | How long a session lasts | `720h` (30 days) |
| `FIREBASE_CREDENTIALS` | Service account JSON; enables push notifications | unset — push off, in-app notifications unaffected |
| `REDIS_URL` | Optional response cache | unset — caching off |
| `GIN_MODE` | Gin mode (debug/release) | `debug` |
| `PORT` | Server port | `8080` |

### Push Notifications (optional)

Notifications are recorded in the database and shown in the app with no external
service. Firebase only adds delivery to devices:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Project Settings → Service Accounts → "Generate New Private Key"
3. Set the JSON as the `FIREBASE_CREDENTIALS` environment variable

Keep the key out of the repository — the server reads it from the environment
only, never from a file on disk.

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

### Signed Out Unexpectedly

- Check `JWT_SECRET` is set and has not changed — every existing session is
  invalidated when the signing key changes
- Sessions last `TOKEN_TTL` (30 days by default)

### A Member Cannot Sign In

Issue them a reset code: **Admin panel → Members → ⋮ → Password reset code**, or
`POST /api/admin/users/:id/reset-code`. Pass the code on yourself; they enter it
on the app's "Forgot your password?" screen. Codes last 2 hours and work once.

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
