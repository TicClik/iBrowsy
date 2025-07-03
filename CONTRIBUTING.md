# Contributing to iBrowsy

Thank you for your interest in contributing to iBrowsy! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have:
- macOS 14.0 or later
- Xcode 15.0 or later
- An OpenAI API key for testing AI features
- Git installed and configured

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/yourusername/iBrowsy.git
   cd iBrowsy
   ```
3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/originalowner/iBrowsy.git
   ```

### Development Setup

1. Open `iBrowsy.xcodeproj` in Xcode
2. **Configure Bundle Identifier**:
   - Select the project in Xcode navigator
   - Choose the iBrowsy target
   - Change Bundle Identifier from `com.yourcompany.iBrowsy` to your own unique identifier
3. Configure your development team in project settings
4. Set up your OpenAI API key in the app settings for testing
5. Build and run the project to ensure everything works

## 📋 How to Contribute

### Reporting Bugs

When reporting bugs, please:
- Use the bug report template
- Include detailed steps to reproduce
- Specify your macOS version and system configuration
- Include relevant screenshots or error messages
- Search existing issues to avoid duplicates

### Requesting Features

For feature requests:
- Use the feature request template
- Clearly describe the proposed feature
- Explain the use case and benefits
- Consider the scope and feasibility

### Submitting Code Changes

1. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**
   - Follow the coding standards below
   - Write clear, concise commit messages
   - Add tests for new functionality
   - Update documentation as needed

3. **Test Your Changes**
   - Build the project without warnings
   - Test on multiple macOS versions if possible
   - Verify all features work correctly
   - Test edge cases and error conditions

4. **Submit a Pull Request**
   - Push your branch to your fork
   - Create a pull request with a clear description
   - Reference any related issues
   - Be responsive to feedback and review comments

## 📝 Coding Standards

### Swift Style Guidelines

Follow these conventions to maintain code quality:

- **Naming**: Use descriptive names for variables, functions, and classes
- **Indentation**: Use 4 spaces (not tabs)
- **Line Length**: Keep lines under 120 characters when possible
- **Comments**: Write meaningful comments for complex logic
- **Documentation**: Use Swift documentation comments for public APIs

### Code Organization

- Place files in appropriate feature folders
- Use MARK comments to organize code sections
- Follow the established architecture patterns
- Keep functions focused and small
- Avoid massive view controllers/models

### Example Code Style

```swift
// MARK: - Properties

@State private var isLoading: Bool = false
@AppStorage("user_preference") private var userPreference: String = ""

// MARK: - Body

var body: some View {
    VStack(spacing: 16) {
        // UI components
    }
    .onAppear {
        setupInitialState()
    }
}

// MARK: - Private Methods

private func setupInitialState() {
    // Implementation
}
```

### SwiftUI Best Practices

- Use `@State` for local view state
- Use `@AppStorage` for user preferences
- Use `@ObservedObject` or `@StateObject` for complex state management
- Extract reusable components into separate views
- Use proper accessibility labels and hints

## 🧪 Testing

### Manual Testing

Always test your changes manually:
- Run the app in different scenarios
- Test with and without API keys configured
- Verify accessibility features work
- Test on different screen sizes and resolutions

### Automated Testing

If adding new core functionality:
- Add unit tests for business logic
- Add integration tests for complex workflows
- Ensure tests pass in CI/CD pipeline

## 📚 Documentation

### Code Documentation

- Document public APIs with Swift documentation comments
- Include parameter descriptions and return values
- Provide usage examples for complex functions

### README Updates

If your changes affect:
- Feature capabilities
- Installation instructions
- Usage guidelines
- System requirements

Please update the README.md accordingly.

## 🔍 Review Process

### What to Expect

1. **Automated Checks**: Your PR will be automatically checked for build success
2. **Code Review**: Maintainers will review your code for quality and compatibility
3. **Testing**: Changes will be tested across different macOS versions
4. **Feedback**: You may receive requests for changes or improvements
5. **Approval**: Once approved, your changes will be merged

### Review Criteria

We look for:
- ✅ Clean, readable code
- ✅ Proper error handling
- ✅ Good performance characteristics
- ✅ Accessibility compliance
- ✅ Security best practices
- ✅ Compatibility with supported macOS versions

## 🏷️ Issue Labels

We use these labels to categorize issues:

- `bug` - Something isn't working correctly
- `feature` - New feature request
- `enhancement` - Improvement to existing feature
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Community help needed
- `priority: high` - High priority issue
- `ai` - Related to AI features
- `privacy` - Privacy and security related
- `ui/ux` - User interface and experience

## 🎯 Areas of Contribution

We especially welcome contributions in these areas:

### 🐛 Bug Fixes
- Crash fixes and stability improvements
- Performance optimizations
- Memory leak fixes
- UI/UX bug fixes

### ✨ New Features
- AI assistant improvements
- Privacy and security enhancements
- New productivity tools
- Accessibility features

### 🎨 UI/UX Improvements
- Design refinements
- Animation improvements
- Dark mode enhancements
- Accessibility improvements

### 🛡️ Privacy & Security
- Ad/tracker blocking improvements
- Privacy feature enhancements
- Security vulnerability fixes
- Performance optimizations

### 📚 Documentation
- README improvements
- Code documentation
- User guides
- Developer documentation

### 🌍 Internationalization
- New language translations
- Localization improvements
- Right-to-left language support

## 💡 Development Tips

### Debugging
- Use Xcode's debugging tools effectively
- Add logging for complex operations
- Test with various data scenarios

### Performance
- Profile your changes with Instruments
- Watch for memory leaks and retain cycles
- Optimize image and resource usage

### Security
- Never commit API keys or secrets
- Use secure coding practices
- Validate user inputs properly

## 📞 Getting Help

If you need help:
- Check the existing documentation
- Look through past issues and discussions
- Ask questions in GitHub Discussions
- Reach out to maintainers

## 🙏 Recognition

Contributors will be:
- Listed in the project contributors
- Mentioned in release notes for significant contributions
- Invited to provide input on project direction

Thank you for helping make iBrowsy better! 🎉 