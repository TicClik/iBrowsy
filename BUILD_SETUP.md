# Build Setup Guide

This guide walks you through setting up iBrowsy for development or personal use.

## 📋 Prerequisites

- **macOS 14.0** or later
- **Xcode 15.0** or later  
- **Apple Developer Account** (free account is sufficient for personal use)
- **OpenAI API Key** (for AI features)

## 🔧 Project Configuration

### 1. Bundle Identifier Setup

**⚠️ CRITICAL**: You must change the bundle identifier before building.

1. Open `iBrowsy.xcodeproj` in Xcode
2. Select the **iBrowsy** project in the navigator (top item)
3. Select the **iBrowsy** target from the target list
4. Go to the **Signing & Capabilities** tab

5. **Change Bundle Identifier**:
   - Current: `com.yourcompany.iBrowsy`
   - Change to: `com.yourname.iBrowsy` (replace "yourname" with your identifier)
   - Must be unique across the App Store

6. **Repeat for test targets** (if needed):
   - Select **iBrowsyTests** target → change `com.yourcompany.iBrowsyTests`
   - Select **iBrowsyUITests** target → change `com.yourcompany.iBrowsyUITests`

### 2. Development Team Setup

1. In the same **Signing & Capabilities** tab
2. Select your **Team** from the dropdown
   - If you don't see your team, sign in to Xcode with your Apple ID (Xcode → Preferences → Accounts)
   - Free Apple Developer accounts work fine for personal use

### 3. Deployment Target

- Verify **Deployment Target** is set to **macOS 14.0** or later
- Found in **Build Settings** → **Deployment** → **macOS Deployment Target**

## 🔑 API Key Configuration

After building the app successfully:

1. Launch iBrowsy
2. Go to **iBrowsy** → **Settings** (or `Cmd + ,`)
3. Click the **Browser** tab
4. Find **OpenAI API Key** section
5. Enter your API key (starts with `sk-`)
6. Click **Save**

### Getting an OpenAI API Key

1. Visit [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign in or create an account
3. Click **"Create new secret key"**
4. Copy the key (starts with `sk-`)
5. **Important**: Store it securely - you won't be able to view it again

## 🛠️ Build Process

### Method 1: Xcode GUI
1. Select your scheme (iBrowsy)
2. Choose your destination (My Mac)
3. Press `Cmd + R` to build and run

### Method 2: Command Line
```bash
# Build for development
xcodebuild -project iBrowsy.xcodeproj -scheme iBrowsy -configuration Debug

# Build for release
xcodebuild -project iBrowsy.xcodeproj -scheme iBrowsy -configuration Release -archivePath ./build/iBrowsy.xcarchive archive
```

## 🔍 Troubleshooting

### Common Build Issues

**❌ "No signing certificate found"**
- Solution: Make sure you're signed in to Xcode with your Apple ID
- Go to Xcode → Preferences → Accounts → Add Apple ID

**❌ "Bundle identifier already in use"**
- Solution: Change the bundle identifier to something unique
- Try: `com.yourname.iBrowsy.dev` or `com.yourname.iBrowsy.local`

**❌ "Development team not found"**
- Solution: Select your personal team in Signing & Capabilities
- If using a free account, you might see your name instead of a team name

**❌ "Provisioning profile doesn't match"**
- Solution: Let Xcode manage signing automatically
- Check "Automatically manage signing" in Signing & Capabilities

### Build Settings Issues

**❌ "Deployment target too low"**
- Solution: Update macOS Deployment Target to 14.0
- Build Settings → Deployment → macOS Deployment Target

**❌ "Swift version mismatch"**
- Solution: Ensure Swift Language Version is set to Swift 5
- Build Settings → Swift Compiler Language → Swift Language Version

## 📱 Distribution (Optional)

### For Personal Use
- Build and run directly from Xcode
- The app will be signed with your personal certificate

### For Sharing (Advanced)
- You'll need a paid Apple Developer account ($99/year)
- Archive the app and export for distribution
- Notarization required for distribution outside App Store

## 🔒 Security Notes

- **Never commit** your bundle identifier changes to public repositories
- **Keep API keys secure** - they're stored locally in macOS preferences
- **Use different bundle identifiers** for development vs. release builds

## 📞 Need Help?

If you encounter issues:
1. Check this troubleshooting section first
2. Search existing [GitHub Issues](../../issues)
3. Create a new issue with:
   - Your macOS version
   - Xcode version
   - Error messages
   - Steps you've tried

---

**Happy Building!** 🎉 