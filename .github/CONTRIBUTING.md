# Contributing to unity_kit

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

1. Clone the repo and install dependencies:

```bash
git clone https://github.com/erykkruk/unity_kit.git
cd unity_kit/unity_kit
dart pub get
```

2. Run the checks:

```bash
dart analyze
dart format .
flutter test
```

## Making Changes

1. Fork the repo and create a branch from `main`.
2. Make your changes in `unity_kit/`.
3. Add tests for new functionality.
4. Run the full check suite:

```bash
dart analyze           # zero warnings
dart format .          # zero changes
flutter test           # all tests pass
dart pub publish --dry-run  # no errors
```

5. Update documentation if you changed the public API:
   - `CHANGELOG.md` — describe what changed
   - `README.md` — update usage examples if needed
   - `doc/api.md` — update class/method signatures

6. Open a PR against `main`.

## Code Style

- Follow existing patterns in the codebase
- Use `dart format` (no custom line length)
- No `dynamic` types — always explicit
- No `print()` — use `UnityKitLogger`
- Use constants for Unity message names (see `lib/src/utils/constants.dart`)
- Write doc comments (`///`) for all public APIs

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add gesture recognizer support
fix: prevent double initialization on Android
docs: update asset streaming guide
test: add lifecycle manager edge cases
chore: bump dependencies
```

## Tests

- Mirror the `lib/src/` structure in `test/`
- Use `mocktail` for mocking
- Follow AAA pattern (Arrange, Act, Assert)
- Test both success and error paths

## Reporting Issues

Use the GitHub issue templates:

- **Bug Report** — for bugs with reproduction steps
- **Feature Request** — for new functionality
- **Question** — for usage questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
