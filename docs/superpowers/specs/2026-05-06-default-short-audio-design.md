# Default Short Audio Design

## Goal

Add the audio from `https://www.youtube.com/shorts/kcEM8xNVyiU` as a bundled default sound users can pick from the existing sound library.

## Approach

Use the existing bundled-sound path. Store the extracted audio file under `mobile/assets/sounds/` and add a single entry to `mobile/assets/sounds/sounds_manifest.json`.

The manifest entry will use a stable id, title, duration, search tags, `sourceUrl`, and explicit public-domain license metadata. `SoundLibraryService` already parses these fields into `VineSound`, so no production service changes are expected.

## Data Flow

`SoundLibraryService.loadSounds()` loads `assets/sounds/sounds_manifest.json`, parses it into `VineSound` records, and returns the bundled sounds to picker/search UI. The new sound will follow that path and be searchable by title and tags.

## Testing

Add a focused test that parses the real manifest and verifies the new default sound exists, points at a bundled asset, includes the YouTube source URL, and carries public-domain metadata. Run the focused service test from `mobile/`.
