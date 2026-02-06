# Contributing to error_boundary

Thank you for your interest in contributing to error_boundary! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and constructive in all interactions. We're all here to build something useful for the Flutter community.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/error_boundary.git
   cd error_boundary
   ```
3. **Install dependencies**:
   ```bash
   flutter pub get
   ```
4. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Running Tests

```bash
flutter test
```

With coverage:

```bash
flutter test --coverage
```

### Code Formatting

Format your code before committing:

```bash
dart format .
```

### Static Analysis

Ensure no analysis issues:

```bash
flutter analyze
```

### Verify Publishing

Check that the package is ready for publishing:

```bash
dart pub publish --dry-run
```

## Pull Request Guidelines

### Before Submitting

1. **Run all checks locally**:
   ```bash
   dart format .
   flutter analyze
   flutter test
   dart pub publish --dry-run
   ```

2. **Update documentation** if you've added or changed functionality

3. **Add tests** for new features or bug fixes

4. **Update CHANGELOG.md** with a description of your changes under `## Unreleased`

### PR Requirements

- Clear description of what the PR does
- Tests pass
- No analysis issues
- Code is formatted
- Documentation is updated (if applicable)

### Commit Messages

Use clear, descriptive commit messages:

```
Add retry delay configuration to RecoveryStrategy

- Add `delay` parameter to RetryRecovery
- Support exponential backoff with `backoff` flag
- Update tests and documentation
```

## Adding New Features

### New Error Reporter

1. Create a new file in `lib/src/reporters/`
2. Implement the `ErrorReporter` interface
3. Export it from `lib/error_boundary.dart`
4. Add tests in `test/reporters_test.dart`
5. Document usage in `README.md`

Example structure:

```dart
class MyServiceReporter implements ErrorReporter {
  @override
  Future<void> report(ErrorInfo info) async {
    // Implementation
  }

  @override
  void setUserIdentifier(String? userId) {
    // Implementation
  }

  @override
  void setCustomKey(String key, dynamic value) {
    // Implementation
  }
}
```

### New Recovery Strategy

1. Add a new sealed class variant in `lib/src/recovery_strategy.dart`
2. Handle it in `ErrorBoundaryState._attemptRecovery()`
3. Add tests
4. Document usage

## Reporting Issues

When reporting issues, please include:

- Flutter/Dart version (`flutter --version`)
- Package version
- Minimal reproducible example
- Expected vs actual behavior
- Stack trace (if applicable)

## Questions?

Feel free to open an issue for questions or discussions about potential features.

## License

By contributing, you agree that your contributions will be licensed under the BSD 3-Clause License.
