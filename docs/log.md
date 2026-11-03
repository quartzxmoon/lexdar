# Work log

Append-only. Newest entries at the bottom.

---

## [2026-11-02] setup | docs/ wiki scaffolded

- Categories: concepts - architecture - subsystems - decisions - reference - operations - history
- Baseline commit: `fa5001d`
- Created: `docs/{CLAUDE,index,log}.md`, `raw/`, 4 `.claude/commands/docs-*`,
  and `.claude/scripts/docs-lint.py`
- Started in grow mode (`--lite`): added one architecture page,
  [[scan-to-renovation-flow]], covering the whole app (it was just written from
  scratch, so "the area worked in" is everything) -- RoomPlan capture ->
  ScanStore persistence -> RenovationPlan editing -> SceneKit editor -> PDF
  export, plus the two traps hit while writing `RoomSceneBuilder`/
  `RenovationPlan` (surface-identifier scoping, plane-rotation composition
  order). `verified_at: fa5001d`.

## [2026-11-03] grow | CI build/sign pipeline

- Added `.github/workflows/build-ios.yml` (unsigned validate job always runs;
  signed archive+export job gated on the `SIGNING_CONFIGURED` repo variable) and
  [[ios-signing-and-sideloading]] -- the whole cert/profile/secrets setup done via
  OpenSSL + the Apple Developer web portal + Sideloadly, with no Mac involved at any
  step. `verified_at: c31135c`.

## [2026-11-03] fix | first real CI run caught two bugs

- `project.pbxproj` had doubled file paths (groups already contribute their own
  subdirectory; file refs must be basenames) -- regenerated it and documented the
  rule as a trap on [[scan-to-renovation-flow]].
- The CI build step piped `xcodebuild | xcpretty` without `set -o pipefail`, so
  bug #1's real `BUILD FAILED` was reported as a green check -- fixed and
  documented as a trap on [[ios-signing-and-sideloading]].
- Both pages' `verified_at` moved to `4701aea`.

## [2026-11-03] fix | NSCoding conformance

- `RoomCaptureViewDelegate` inherits `NSCoding` (Apple's own doc page confirms
  it) -- missed when the delegate was first written and verified. CI's
  now-honest failure (post-pipefail-fix) caught it. Added a minimal
  `init?(coder:)`/`encode(with:)` pair to `RoomCaptureCoordinator`. Documented
  as a trap on [[scan-to-renovation-flow]]; `verified_at: b99e638`.
