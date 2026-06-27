# Changelog

## 0.0.1

- Initial scaffold: OS-backed background uploads.
- Dart API (`BackgroundUploader`, `BackgroundUploadRequest`,
  `BackgroundUploadEvent`) with method-channel + event plumbing.
- Darwin (iOS + macOS) background `URLSession` implementation.
- Android foreground-service implementation.
