# Security Policy

## 🔒 Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## 🚨 Reporting a Vulnerability

We take the security of iBrowsy seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### Where to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report security vulnerabilities by:
1. Opening a draft security advisory on GitHub
2. Emailing the maintainers directly (if contact info is available)

### What to Include

When reporting a vulnerability, please include:

- **Type of issue** (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
- **Full paths of source file(s)** related to the manifestation of the issue
- **The location of the affected source code** (tag/branch/commit or direct URL)
- **Any special configuration required** to reproduce the issue
- **Step-by-step instructions** to reproduce the issue
- **Proof-of-concept or exploit code** (if possible)
- **Impact of the issue**, including how an attacker might exploit the issue

### Response Timeline

We will respond to your report within **48 hours** and aim to:
- Confirm the problem and determine the affected versions
- Audit code to find any potential similar problems
- Prepare fixes for all releases still under maintenance
- Release patches as soon as possible

### Disclosure Policy

- We ask that you give us a reasonable amount of time to fix the issue before any disclosure
- We will acknowledge your responsible disclosure
- We will provide credit for your discovery (unless you prefer to remain anonymous)

## 🛡️ Security Best Practices

### For Users
- **API Keys**: Never share your OpenAI API keys publicly
- **Updates**: Keep iBrowsy updated to the latest version
- **Permissions**: Only grant necessary system permissions
- **Privacy**: Review privacy settings regularly

### For Developers
- **Secrets**: Never commit API keys, passwords, or other secrets to the repository
- **Dependencies**: Keep dependencies updated and audit for vulnerabilities
- **Input Validation**: Validate all user inputs
- **Secure Coding**: Follow secure coding practices
- **Code Review**: All security-related changes require review

## 🔐 Security Features

iBrowsy includes several security and privacy features:

### Privacy Protection
- **AI Privacy Manager**: Blocks ads and trackers using machine learning
- **Enhanced YouTube Blocking**: Specialized protection for YouTube
- **No Telemetry**: Your data stays on your device
- **Local Storage**: API keys stored securely in macOS Keychain equivalent

### Secure Communication
- **HTTPS Enforcement**: Prefers secure connections
- **Certificate Validation**: Validates SSL/TLS certificates
- **Secure API Calls**: All AI API calls use HTTPS

### Data Protection
- **Local Processing**: Most data processing happens locally
- **Minimal Data Collection**: We collect only necessary data
- **User Control**: Users control their data and privacy settings

## 📋 Security Checklist for Contributors

When contributing code, please ensure:

- [ ] No hardcoded secrets or API keys
- [ ] Input validation for user-provided data
- [ ] Proper error handling without information leakage
- [ ] Secure communication protocols
- [ ] Following principle of least privilege
- [ ] Regular dependency updates
- [ ] Code review for security implications

## 🔍 Security Audits

We encourage security researchers to:
- Review our code for potential vulnerabilities
- Test the application for security issues
- Report findings responsibly
- Suggest improvements to our security practices

## ⚖️ Safe Harbor

We support safe harbor for security researchers who:
- Make a good faith effort to avoid privacy violations
- Avoid destruction of data or interruption of services
- Do not access or modify data belonging to others
- Report vulnerabilities promptly and responsibly
- Follow this security policy

Thank you for helping keep iBrowsy and our users safe! 🙏 