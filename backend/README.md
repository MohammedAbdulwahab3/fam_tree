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

A REST API for one family's tree, built with **Go**, **Gin**, **GORM** and **PostgreSQL**: people and their relationships, self-authored profiles, the claim flow that ties an account to a person, a family feed, in-app notifications, and role-based access.

### Tech Stack

- **Language:** Go 1.21
- **Web Framework:** Gin
- **Database:** PostgreSQL
- **ORM:** GORM
- **Authentication:** JWT issued by this server (bcrypt password hashing)
- **Storage:** Local file system (uploads)

There is deliberately no push channel, no mail server, and no chat. See the
root README for why.

---

## ✨ Features

### Core Features
- 👤 **People and relationships** — the tree itself, with parents, marriages
  and self-authored profiles
- 🔗 **Claiming** — a member says which person they are, an admin confirms
- 📝 **Family feed** — posts, comments and reactions
- 🔔 **Notifications** — in-app, with per-type preferences
- 🔐 **Authentication** — email and password, JWT sessions, admin-issued
  password resets
- 👑 **Roles** — admin and member, enforced on every route

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
├── auth/           # JWT: issuing, and verifying with the algorithm pinned
├── config/         # Everything read from the environment, in one place
├── handlers/       # HTTP request handlers
│   ├── auth.go         # register, login
│   ├── person.go       # the tree; children are derived here on read
│   ├── post.go         # feed, comments, reactions
│   ├── link_handler.go # claiming a person, and admin review
│   ├── notification.go
│   ├── password.go     # change, reset by admin-issued code, delete account
│   └── upload.go
├── middleware/     # HTTP middlewares
│   ├── auth.go         # verifies the token, re-reads role and ban state
│   ├── admin.go        # admin-only
│   ├── ratelimit.go    # per-IP, on the public auth routes
│   └── cache.go        # optional Redis
├── models/         # Database models
├── seed/           # Fills the tree with people. Creates no admin.
├── cmd/make_admin/ # The only way to create the first admin
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
# Required. A release build (GIN_MODE=release) refuses to start without it
# rather than signing every session with a key that is public in this repo.
export JWT_SECRET="$(openssl rand -base64 48)"

# Database. Defaults to a local Postgres on 5432 if unset.
export DATABASE_URL="host=127.0.0.1 user=postgres password=postgres dbname=family_tree port=5432 sslmode=disable"

# Optional. How long a session lasts; defaults to 720h (30 days).
export TOKEN_TTL=720h

# Optional. Which family tree this deployment serves. Must match the app's
# FAMILY_TREE_ID.
export FAMILY_TREE_ID=main-family-tree
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

This fills the tree with people. It creates no admin: the one it used to create
had an empty password hash, so bcrypt rejected every sign-in against it — an
account that looked like a way in and was not one. Register through the app,
then promote yourself with `go run ./cmd/make_admin <your-email>`.

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
# A page of the feed, newest first. Paging is by timestamp rather than
# offset: the feed is written to while it is read, and an offset silently
# repeats or skips a post when something arrives between two pages.
GET /api/posts?limit=20&before=<RFC3339 from the last nextCursor>

# -> { "posts": [...], "hasMore": true, "nextCursor": "2026-..." }

# A post's comments
GET /api/posts/:id/comments?limit=20
# -> { "comments": [...], "total": 42 }

# Set, change or clear your reaction. Sending the same emoji twice
# takes it back.
POST /api/posts/:id/reactions
Content-Type: application/json

{
  "emoji": "❤️"
}

# Add comment
POST /api/posts/:id/comments
Content-Type: application/json

{
  "text": "Great post!"
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

This is the only way to create the *first* admin, and it is deliberate: an HTTP
route that grants admin is a route anybody can call. There used to be one here,
gated on a secret string committed to this repository.

```bash
# The most recently registered account
go run ./cmd/make_admin

# A specific one, by email or id
go run ./cmd/make_admin user@example.com
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

GORM auto-migrates every model on startup. Two notes for an existing database:

- Reactions gained a unique `(post_id, user_id)` index and lost their soft
  delete. AutoMigrate will not drop the old `deleted_at` column, so any reaction
  soft-deleted by an older build becomes visible again.
- Notification preferences lost their `default:true` column defaults, which is
  what made turning a notification off silently store "on". Existing rows are
  unaffected.

### Testing

```bash
# Unit and handler tests. No database — these run against in-memory SQLite.
go test ./...

# End-to-end, each suite against a throwaway database.
./e2e/run.sh                  # everything
./e2e/run.sh permissions      # one suite

# Health check
curl http://localhost:8080/ping
```

`go test ./...` covers token validation, rate limiting, notification
preferences, relationship derivation and pruning, cycle termination, and the
permission and field-merge behaviour of every person and post route.

`e2e/` covers the API end to end in five suites — `permissions`,
`notifications`, `linking`, `sessions`, `tree`. Locally it wants the Postgres
container from `docker-compose.yml`; in CI it talks to a service container. Set
`PG_HOST` and `PG_PORT` to point it elsewhere.

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
| `JWT_SECRET` | Signs session tokens | dev-only fallback; **release refuses to start without it** |
| `DATABASE_URL` | PostgreSQL connection string | `host=127.0.0.1 user=postgres password=postgres dbname=family_tree port=5432 sslmode=disable` |
| `TOKEN_TTL` | How long a session lasts | `720h` (30 days) |
| `FAMILY_TREE_ID` | Which tree this deployment serves | `main-family-tree` |
| `REDIS_URL` | Optional response cache | unset — caching off |
| `GIN_MODE` | Gin mode (debug/release) | `debug` |
| `PORT` | Server port | `8080` |

### Notifications

Recorded in the database and read by the app, which polls. There is no push
channel: nothing ever registered a device token, so the Firebase layer that used
to be here could not have delivered anything, and it has been removed.

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
