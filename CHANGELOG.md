# Changelog

## Unreleased
### Added
- Reproducible release pipeline script: `scripts/release_pipeline.sh`
- Release checklist document: `RELEASE_CHECKLIST.md`
- Release logs/checksum outputs under `release/`

### Changed
- Added explicit release baseline docs and reproducible release script.

### Known Issues
- Some unit tests currently fail in `FrameOpsTests` (release blocker).
- Existing legacy artifacts in `release/` use inconsistent name prefix (`JocungCam` vs `JochungCam`).