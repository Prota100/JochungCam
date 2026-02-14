# Release Checklist (Baseline / Production-safe)

## 0) Preconditions
- macOS 14+
- Xcode Command Line Tools installed
- Homebrew deps installed: `libimagequant gifski webp`

## 1) Clean reproducible pipeline
```bash
./scripts/release_pipeline.sh 1.0.1
```

## 2) Quality gates
- Build log: `release/logs/build-release.log`
- Test log: `release/logs/test-release.log`
- Smoke log: `release/logs/smoke.log`
- Must review:
  - `error:` lines == 0 in build/test logs
  - critical test failures == 0 for release approval

## 3) Artifacts
- Binary: `.build/arm64-apple-macosx/release/JochungCam`
- App bundle: `release/JochungCam.app`
- Zip package: `release/JochungCam-v<version>-macOS-arm64.zip`
- Checksums: `release/SHA256SUMS.txt`

## 4) Integrity & traceability
- Verify zip integrity: `unzip -t release/JochungCam-v<version>-macOS-arm64.zip`
- Verify checksum: `shasum -a 256 -c release/SHA256SUMS.txt`
- Build metadata: `release/release-metadata.env`

## 5) Manual go/no-go
- GO: all tests pass + smoke checks pass + checksums generated.
- NO-GO: any failing tests, missing artifacts, or checksum mismatch.