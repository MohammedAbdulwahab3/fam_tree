# 📱 Quick App Icon Setup Using Landing Page Logo

## ✅ I've Created Everything You Need!

### Option 1: Screenshot Method (Easiest - 2 minutes)

1. **Open the file I just created:**
   ```bash
   xdg-open /home/maw/Desktop/family_tree/family_tree/generate_app_icon.html
   ```
   Or just double-click: `generate_app_icon.html`

2. **Click "Hide Instructions" button**

3. **Take a screenshot of just the icon:**
   - Use your screenshot tool (e.g., `gnome-screenshot -a` or Spectacle)
   - Select just the circular green gradient icon
   - Make sure it's 1024x1024 pixels (or crop it after)

4. **Save the screenshot as:**
   ```
   /home/maw/Desktop/family_tree/family_tree/assets/icons/app_icon.png
   ```

5. **Generate all platform icons:**
   ```bash
   cd /home/maw/Desktop/family_tree/family_tree
   flutter pub get
   dart run flutter_launcher_icons
   ```

6. **Rebuild your app:**
   ```bash
   flutter build apk --release
   ```

### Option 2: Use Online Tool (Even Easier!)

1. **Go to:** https://www.screely.com or https://www.remove.bg
2. **Upload a screenshot** of your landing page logo
3. **Crop/resize to 1024x1024**
4. **Download and save** as `app_icon.png`
5. **Run the commands above** (steps 5-6)

---

## 🎨 The Logo Design

The landing page uses:
- **Gradient:** Green (#10B981 → #059669 → #047857)
- **Icon:** Material Icons `account_tree`
- **Shape:** Rounded square with shadows
- **Size:** 1024x1024px

This matches your landing page perfectly! ✨

---

## 🚀 After Icon is Generated

The `flutter_launcher_icons` tool will automatically create:
- ✅ Android icons (all densities)
- ✅ iOS icons (all sizes)
- ✅ Web favicon
- ✅ Adaptive icons for Android

No manual work needed after placing your `app_icon.png`!
