# Contributing to CatchStalker

Thank you for your interest in contributing to CatchStalker! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Basic knowledge of Swift and SwiftUI

### Setting Up the Development Environment

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/catch-stalker-macos.git
   cd catch-stalker-macos
   ```
3. Open `CatchStalker.xcodeproj` in Xcode
4. Build and run to verify everything works

## How to Contribute

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates.

When reporting a bug, include:
- macOS version
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- Screenshots if applicable
- Console logs if relevant

### Suggesting Features

Feature requests are welcome! Please:
- Check existing issues for similar suggestions
- Provide a clear description of the feature
- Explain the use case and benefits
- Consider potential implementation approaches

### Pull Requests

1. Create a new branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the code style guidelines below

3. Test your changes thoroughly:
   - Build succeeds without warnings
   - Existing functionality still works
   - New features work as expected

4. Commit your changes with clear messages:
   ```bash
   git commit -m "Add: brief description of changes"
   ```

5. Push to your fork and create a Pull Request

## Code Style Guidelines

### Swift

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and concise

### SwiftUI

- Use `@StateObject` for owned observable objects
- Use `@ObservedObject` for injected observable objects
- Prefer composition over large monolithic views
- Use `private` for internal view properties

### Project Structure

```
CatchStalker/
├── App/           # Application entry and lifecycle
├── Core/          # Core services (Database, Settings, Permissions)
├── Modules/       # Feature modules (Keystroke, Mouse, Screenshot, etc.)
├── UI/            # User interface components
├── Models.swift   # Shared data models
└── Resources/     # Assets and resources
```

### Commit Messages

Use prefixes:
- `Add:` for new features
- `Fix:` for bug fixes
- `Update:` for improvements to existing features
- `Refactor:` for code restructuring
- `Docs:` for documentation changes
- `Chore:` for maintenance tasks

## Testing

- Test on both macOS 13 and the latest macOS version if possible
- Verify permission flows work correctly
- Test with various system configurations

## Security

CatchStalker handles sensitive user data. When contributing:
- Never log sensitive information
- Ensure all data stays local to the device
- Follow secure coding practices
- Report security vulnerabilities privately

## Questions?

If you have questions about contributing, feel free to open an issue for discussion.

## License

By contributing to CatchStalker, you agree that your contributions will be licensed under the MIT License.
