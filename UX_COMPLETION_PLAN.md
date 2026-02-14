# JochungCam UI/UX Completion Plan (v1.0.2 target)

## Goal
완성형 사용자 흐름 고정: **Capture → Edit → Export**

## Current confirmed state
- Heavy MOV import/export E2E test exists (`MOVExportE2ETests`)
- MOV smoke test exists (`MOVImportSmokeTests`)
- Release v1.0.1 shipped

## Remaining product tasks

### P0 (must)
1. First-run onboarding
   - Screen Recording permission check
   - One-click open system settings guide
2. Long import UX
   - progress + ETA + cancel/retry
3. Export completion action bar
   - Preview / Open in Finder / Share

### P1 (should)
4. Home quick actions simplification
   - Quick Record / Import MOV / Recent
5. Export preset confidence
   - show predicted size vs actual delta

### P2 (nice)
6. Keyboard shortcut hint overlays
7. Batch export result summary table

## QA acceptance (release gate)
- 30~60s heavy MOV x3: import failure 0
- Presets (Light/Normal/Discord/HQ): export success 100%
- First-time user test (n>=5): first GIF under 60s for >=80%
- Blocking bug/crash: 0

## Evidence artifacts
- `release/mov-e2e/*.gif`
- `release/mov-e2e/report.csv`
- test command:
  - `swift test --filter MOVImportSmokeTests`
  - `swift test --filter MOVExportE2ETests`
