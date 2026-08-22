# Quick Setup Guide

## 🚀 Get Started in 3 Steps

### Step 1: Install Dependencies

```bash
cd /home/maw/Desktop/family_tree/family_tree
flutter pub get
```

### Step 2: Configure Firebase

**Option A: Use Demo Mode (Quick Test)**
The app includes demo Firebase credentials to test locally. Simply run:

```bash
flutter run -d chrome
```

**Option B: Connect Real Firebase (Production)**

1. Create a Firebase project at https://console.firebase.google.com/
2. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
3. Configure Firebase:
   ```bash
   flutterfire configure
   ```
4. Enable services in Firebase Console:
   - Firestore Database
   - Firebase Storage
   - Authentication (Email/Google)

### Step 3: Run the App

**Web:**
```bash
flutter run -d chrome
```

**Android/iOS:**
```bash
flutter run
```

---

## 📱 Test the Features

1. **Add your first family member** - Click the FAB button
2. **Switch layouts** - Use the view menu icon in app bar
3. **Search** - Type names in the search bar
4. **Focus mode** - Select a person, use arrow buttons to filter ancestors/descendants
5. **Pan/Zoom** - Drag to pan, pinch/scroll to zoom

---

## 🔧 Firebase Security Rules

After setting up Firebase, add these security rules:

**Firestore Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**Storage Rules:**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 📞 Need Help?

Check [README.md](file:///home/maw/Desktop/family_tree/family_tree/README.md) for detailed documentation.
