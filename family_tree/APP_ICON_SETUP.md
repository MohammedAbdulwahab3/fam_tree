# App Icon Setup Instructions

## 📱 How to Change the App Icon

Since I can't generate images right now, here's how to create and set up your custom app icon:

### Option 1: Create Icon Online (Easiest)
1. **Go to:** https://www.canva.com or https://www.figma.com
2. **Create a 1024x1024 design** with:
   - Stylized tree with connected nodes
   - Gradient background: Terracotta (#E07856) to Warm Coral
   - Gold/cream tree with circular family nodes
   - Clean, modern, minimalist style
3. **Export as PNG** (1024x1024)

### Option 2: Use AI Image Generator
1. **Go to:** https://designer.microsoft.com or https://www.bing.com/create
2. **Use this prompt:**
   ```
   "Modern app icon for family tree genealogy app. Elegant golden tree with 
   interconnected circular nodes on terracotta orange gradient background. 
   Minimalist, professional, premium aesthetic. Square 1024x1024."
   ```
3. **Download and save**

### Option 3: Hire on Fiverr
- Quick, professional icon for $5-20
- Search "app icon design"

## 🚀 Installation Steps

### Step 1: Save Your Icon
1. Create your 1024x1024 icon image
2. Save it as: `/home/maw/Desktop/family_tree/family_tree/assets/icons/app_icon.png`

### Step 2: (Optional) Create Adaptive Icon Foreground
For best Android results, create a foreground-only version:
- Same tree design, but transparent background
- Save as: `assets/icons/app_icon_foreground.png`

### Step 3: Generate Icons
```bash
cd /home/maw/Desktop/family_tree/family_tree
flutter pub get
dart run flutter_launcher_icons
```

### Step 4: Rebuild App
```bash
flutter build apk --release
```

## ✅ What's Already Configured

I've already set up:
- ✅ flutter_launcher_icons package added to pubspec.yaml
- ✅ Configuration for Android, iOS, and Web
- ✅ Terracotta background color (#E07856)  
- ✅ Icon paths configured

**All you need to do:**
1. Create/download your icon image (1024x1024 PNG)
2. Place it at `assets/icons/app_icon.png`
3. Run `flutter pub get`
4. Run `dart run flutter_launcher_icons`
5. Rebuild the app

The icons will be automatically generated for all platforms! 🎨
