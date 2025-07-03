# 🌐 iBrowsy

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0+-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-Open%20Source-green.svg)](#license)

A modern, AI-powered web browser for macOS that reimagines web browsing with intelligent features, privacy-first design, and seamless user experience. Built with SwiftUI and WebKit, iBrowsy combines traditional browsing with cutting-edge AI assistance and productivity tools.

## ✨ Key Features

### 🤖 AI-Powered Browsing Assistant
- **Intelligent Chat Assistant**: Built-in AI powered by OpenAI GPT-4 with webpage context awareness
- **Voice Input**: Dictate queries using native macOS speech recognition
- **Screen Capture Integration**: Take screenshots and ask AI questions about images
- **Webpage Interaction**: AI can highlight text, navigate to sites, and bookmark pages
- **Price Comparison**: Smart product price analysis across major retailers
- **Trip Planning**: AI-assisted travel planning with integrated search links

### 🎯 Advanced Productivity Tools
- **Screen Annotation**: System-wide drawing and annotation over any content
- **Screen Recording**: Integrated video recording with annotation overlay
- **Split-View Analysis**: Real-time AI analysis when viewing two sources side-by-side
- **Picture-in-Picture**: Automatic video PiP with focus-loss detection
- **Citation Manager**: Academic-style citation collection and management

### 🛡️ Privacy & Security
- **AI Privacy Manager**: Machine learning-powered ad and tracker blocking
- **Enhanced YouTube Blocking**: Specialized protection for YouTube ads
- **Smart Performance Modes**: Aggressive, Balanced, or Minimal blocking options
- **Non-Persistent Browsing**: Data cleared when app closes (configurable)
- **No Telemetry**: Your data stays on your device

### 🎨 Modern User Experience
- **Liquid Glass Design**: Beautiful, modern interface with glass morphism
- **Dark/Light Mode**: Seamless macOS appearance integration
- **Customizable Toolbar**: Drag-and-drop AI action buttons
- **Tab Management**: Intelligent tab overview and search
- **Smart Bookmarking**: Organized bookmark system with folders

## 🚀 Quick Start

### Prerequisites

- **macOS 14.0** or later
- **Xcode 15.0** or later
- **64-bit processor**
- **4GB RAM** minimum (8GB recommended)
- **OpenAI API Key** (for AI features)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/iBrowsy.git
   cd iBrowsy
   ```

2. **Open in Xcode**
   ```bash
   open iBrowsy.xcodeproj
   ```

3. **Configure Build Settings**
   - **IMPORTANT**: Update the bundle identifier for your use:
     - Select the project in Xcode navigator
     - Choose your target (iBrowsy)
     - In the "Signing & Capabilities" tab, change the Bundle Identifier from `com.yourcompany.iBrowsy` to your own (e.g., `com.yourname.iBrowsy`)
   - Select your development team in the project settings
   - Ensure the deployment target is set to macOS 14.0+

4. **Build and Run**
   - Press `Cmd + R` or click the Run button in Xcode
   - The app will launch automatically

> 📖 **Detailed Setup Guide**: For comprehensive build instructions and troubleshooting, see [BUILD_SETUP.md](BUILD_SETUP.md)

### 🔑 API Key Setup

iBrowsy requires an OpenAI API key for AI features to work:

1. **Get an OpenAI API Key**
   - Visit [OpenAI Platform](https://platform.openai.com/api-keys)
   - Create an account or sign in
   - Generate a new API key

2. **Configure in iBrowsy**
   - Launch iBrowsy
   - Go to **Settings** → **Browser** tab
   - Find the **OpenAI API Key** section
   - Enter your API key and click **Save**

3. **Verify Setup**
   - Try asking the AI assistant a question
   - If configured correctly, you should receive a response

> **⚠️ Important**: Keep your API key secure and never commit it to version control. The app stores it locally in your macOS user preferences.

## 📱 Usage

### Basic Browsing
- **New Tab**: `Cmd + T`
- **Close Tab**: `Cmd + W`
- **Refresh**: `Cmd + R`
- **Navigate**: Type URLs or search terms in the address bar

### AI Assistant
- Click the **AI Assistant** button in the toolbar
- Ask questions about the current webpage
- Use voice input with the microphone button
- Take screenshots for visual questions

### Privacy Features
- Go to **Settings** → **Privacy** tab
- Configure blocking levels and performance modes
- View real-time blocking statistics

## 🏗️ Architecture

iBrowsy is built using modern Swift and SwiftUI patterns:

```
iBrowsy/
├── Core/                   # Core services and coordinators
├── Features/               # Feature-specific modules
│   ├── AIAssistant/       # AI chat and interaction
│   ├── WebBrowsing/       # Browser engine and UI
│   ├── BookmarkSystem/    # Bookmark management
│   ├── PictureInPicture/  # Video PiP functionality
│   ├── PriceComparison/   # Price analysis tools
│   └── ...               # Other features
├── UI/                    # Shared UI components
├── Models/                # Data models
├── Privacy/               # Privacy and security features
└── Resources/             # Assets and localizations
```

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **WebKit**: Web rendering engine
- **Combine**: Reactive programming
- **Swift Concurrency**: Async/await for modern concurrency
- **Core Animation**: Smooth animations and transitions
- **AVFoundation**: Text-to-speech and media handling

## 🤝 Contributing

We welcome contributions to iBrowsy! Here's how you can help:

### Getting Started
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly on macOS
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines
- Follow Swift style guidelines
- Write clear, self-documenting code
- Add appropriate tests for new features
- Update documentation for significant changes
- Ensure backwards compatibility when possible

### Areas for Contribution
- 🐛 **Bug Fixes**: Help us squash bugs
- ✨ **New Features**: Add new browsing capabilities
- 🎨 **UI/UX**: Improve the user experience
- 🛡️ **Privacy**: Enhance privacy and security features
- 📚 **Documentation**: Improve guides and documentation
- 🌍 **Localization**: Add support for new languages

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

```
MIT License

Copyright (c) 2024 iBrowsy Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 🆘 Support

Need help? Here are your options:

- 🐛 **Bug Reports**: [Open an issue](../../issues/new?template=bug_report.md)
- 💡 **Feature Requests**: [Request a feature](../../issues/new?template=feature_request.md)
- 💬 **Discussions**: Join our [GitHub Discussions](../../discussions)

### Common Issues

**Q: Build fails with signing errors**  
A: Make sure you've updated the bundle identifier from `com.yourcompany.iBrowsy` to your own unique identifier in Xcode project settings.

**Q: AI features aren't working**  
A: Make sure you've configured your OpenAI API key in Settings → Browser → OpenAI API Key.

**Q: Picture-in-Picture not working**  
A: Ensure you've granted screen recording permissions to iBrowsy in System Preferences → Security & Privacy.

## 🙏 Acknowledgments

- **OpenAI** for providing the GPT API that powers our AI features
- **Apple** for the excellent WebKit and SwiftUI frameworks
- **The Swift Community** for continuous inspiration and support
- **All Contributors** who help make iBrowsy better

---

<p align="center">
  <b>Built with ❤️ for the macOS community</b><br>
  <sub>Star ⭐ this repository if you find it helpful!</sub>
</p> 
