# Family Tree - Go Backend Setup

## Quick Start

### 1. Start the Backend Server
```bash
cd /home/maw/Desktop/family_tree/backend
go run main.go
```

Server will start on **http://localhost:8080**

### 2. Test the Backend
```bash
# Health check
curl http://localhost:8080/ping

# Register a test user
curl -X POST http://localhost:8080/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","name":"Test User"}'
```

## Flutter Integration Status

### ✅ Completed
1. **ApiService** (`lib/data/services/api_service.dart`)
   - HTTP client with token management
   - Handles all API calls to Go backend
   - File upload support

2. **AuthService** (`lib/data/services/auth_service_new.dart`)
   - JWT-based authentication
   - Register, Login, Logout methods
   - Replaces Firebase Auth

3. **Providers** (`lib/providers/auth_provider_new.dart`)
   - Riverpod providers for new auth system
   - Drop-in replacement for Firebase providers

### ⏳ Next Steps (Manual)

To complete the migration, you need to:

1. **Update Login Page**
   - Replace `lib/features/auth/providers/auth_provider.dart` with the new provider
   - The UI is already set up, just swap the import

2. **Update main.dart**
   - Remove Firebase initialization
   - Initialize ApiService instead
   - Use new auth providers

3. **Refactor Repositories** (optional for now)
   - PersonRepository: Use `/api/persons` endpoints
   - GroupRepository: Use `/api/posts`, `/api/messages`, `/api/events`
   - StorageService: Use `/api/upload` endpoint

## Quick Migration Guide

### Option 1: Test New Auth (Recommended)
1. Create a new test page that uses `auth_provider_new.dart`
2. Test login/register flow
3. Once confirmed working, update main login page

### Option 2: Full Switch
1. Backup your current code
2. Replace all Firebase auth imports with new auth
3. Update routing to use new providers
4. Test thoroughly

## API Endpoints

### Public Endpoints
- `POST /register` - Create account
- `POST /login` - Login

### Protected Endpoints (require JWT token)
- `GET /api/persons` - Get all persons
- `POST /api/persons` - Create person
- `PUT /api/persons/:id` - Update person
- `DELETE /api/persons/:id` - Delete person
- `POST /api/upload` - Upload file
- `GET /api/posts` - Get posts
- `POST /api/messages` - Send message
- `GET /api/events` - Get events

## Configuration

### Change Backend URL
In `lib/data/services/api_service.dart`:
```dart
static const String baseUrl = 'http://localhost:8080';
```

Change to your production URL when deploying.

## Benefits

✅ **No Firebase Costs** - Fully self-hosted  
✅ **Full Control** - Own your data  
✅ **Simple Deployment** - Single binary  
✅ **Easy Development** - Modify backend as needed  
✅ **Privacy** - Data stays on your server
# tree
