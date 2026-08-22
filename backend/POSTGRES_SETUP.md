# Family Tree Backend - PostgreSQL Setup

## Option 1: Docker Compose (Recommended)

### Start PostgreSQL with Docker
```bash
# Fix Docker permissions first
sudo usermod -aG docker $USER
newgrp docker  # Or logout/login

# Start PostgreSQL
cd /home/maw/Desktop/family_tree/backend
docker compose up -d
```

## Option 2: System PostgreSQL

### Install PostgreSQL
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

### Create Database
```bash
sudo -u postgres psql
```
Then in psql:
```sql
CREATE DATABASE family_tree;
CREATE USER postgres WITH PASSWORD 'postgres';
GRANT ALL PRIVILEGES ON DATABASE family_tree TO postgres;
\q
```

### Update pg_hba.conf for local access
```bash
sudo nano /etc/postgresql/*/main/pg_hba.conf
```
Change `peer` to `md5` for local connections, then:
```bash
sudo systemctl restart postgresql
```

## Option 3: Use existing PostgreSQL

If you already have PostgreSQL running, just update the connection string:

```bash
export DATABASE_URL="host=localhost user=YOUR_USER password=YOUR_PASSWORD dbname=family_tree port=5432 sslmode=disable"
```

Or edit `main.go` line 25 with your connection details.

## Run the Backend

Once PostgreSQL is ready:

```bash
cd /home/maw/Desktop/family_tree/backend
go run main.go
```

The backend will:
1. Connect to PostgreSQL
2. Auto-create all tables (users, persons, posts, messages, events)
3. Start API server on http://localhost:8080

## Test Connection

```bash
curl http://localhost:8080/ping
# Should return: {"message":"pong"}

curl http://localhost:8080/api/persons -H "Authorization: Bearer test-token"
# Should return: []
```
