# Code Review: Issue Tracker

Working document. GitHub issues will be created once the list is finalized.

**Reference commit:** [`4f2834ddb`](https://github.com/divinevideo/divine-mobile/commit/4f2834ddb529487020333feea8e269c6fa19bfbc): `feat(feed): move captions control into more info (#3105)` (2026-04-16)

> **Note:** All file paths, line numbers, and code snippets in the issue files below were captured at the reference commit. Since `main` continues to evolve, some references may be outdated — files may have moved, lines shifted, or code changed. When acting on an issue, verify against the current state of the codebase.

## Summary

The codebase has strong foundations: a well-established BLoC pattern (42 directories, 61 test files), VGV CI infrastructure across 33 packages, consistent `VineTheme` adoption in 194 files, and solid security primitives for key storage. Repository packages like `videos_repository` and `comments_repository` demonstrate the target architecture cleanly.

The central finding is **incomplete migrations and inconsistent application of established rules**. The target architecture (BLoC-first, layered, co-located features) is well-documented and working where adopted, with an ongoing migration underway. However, 140 services bypass the layer model and three state management patterns still coexist. The same inconsistency shows up in error handling (~170 catch blocks with undocumented contracts), testing (223 skipped tests, non-functional golden suite), localization (hardcoded English strings alongside 1,251+ `context.l10n` usages), and accessibility (core screens invisible to screen readers despite semantic infrastructure in the video feed).

<!-- TODO: Add Recommendations section with consolidated prioritized list pulled from all issue files -->

| Theme | File | Issues |
|-------|------|--------|
| Architecture | [issues-architecture.md](issues-architecture.md) | 11 |
| Testing | [issues-testing.md](issues-testing.md) | 9 |
| Code Simplicity | [issues-simplicity.md](issues-simplicity.md) | 7 |
| UI/UX, Localization & Accessibility | [issues-ui-ux.md](issues-ui-ux.md) | 14 |
| Documentation | [issues-documentation.md](issues-documentation.md) | 2 |
| Error Handling | [issues-error-handling.md](issues-error-handling.md) | 6 |
| Code Quality | [issues-code-quality.md](issues-code-quality.md) | 6 |
| Navigation | [issues-navigation.md](issues-navigation.md) | 2 |
| Tooling & CI | [issues-tooling.md](issues-tooling.md) | 2 |
| CI/CD | [issues-ci-cd.md](issues-ci-cd.md) | 3 |
| Dependencies & Licenses | [issues-dependencies.md](issues-dependencies.md) | 19 |
| Security | [issues-security.md](issues-security.md) | 3 |
| Performance | [issues-performance.md](issues-performance.md) | 7 |

**Total: 91 issues**
