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

## [2026-11-03] grow | contractor-grade blueprint production

- Added a second, parallel subsystem alongside the RoomPlan/SceneKit renovation
  pipeline: [[blueprint-production]] -- an app-owned `FloorPlan` model (since
  `CapturedRoom` has no public initializer and can't be hand-built), a LiDAR
  importer, a hand-drawing editor (grid/angle-snapped precision drafting, works
  with touch or Apple Pencil), a shared dimensioning layout, and two renderers
  (on-screen SwiftUI Canvas + a true-to-scale PDF exporter).
- New TabView root (Scans / Floor Plans) wires it into the app.
- Regenerated `project.pbxproj` for the 7 new files; updated
  [[scan-to-renovation-flow]] (pbxproj/scheme-id trap, now also covers
  `ScanStore.swift`'s new floor-plan persistence) and
  [[ios-signing-and-sideloading]] (README additions). All three pages'
  `verified_at` moved to `acf5af3`.

## [2026-11-03] fix | actor isolation + ShapeStyle typo

- The commit right after the blueprint-production push still failed CI:
  `RoomCaptureCoordinator`'s NSCoding methods needed `nonisolated` (Swift 6
  language mode error, `@MainActor` class vs. nonisolated protocol
  requirement), and `ScanListView.swift` used a nonexistent `.accent`
  ShapeStyle member (real build failure, not a warning) -- fixed to
  `Color.accentColor`. Documented the nonisolated requirement as a trap on
  [[scan-to-renovation-flow]]; `verified_at: aa79d02`.

## [2026-11-03] grow | live 2D/3D toggle + day/night

- `BlueprintEditorView` can now flip between the drafting `Canvas` and a live
  3D preview in the same screen (`FloorPlanSceneBuilder` + new
  `FloorPlan3DPreviewView`), with a day/night lighting toggle -- matches the
  workflow of reference floor-plan apps the user pointed to (own UI, not
  copied). `FloorPlanSceneBuilder` is deliberately separate from
  `RoomSceneBuilder`: it only needs a `FloorPlan`, no `CapturedRoom`/
  `RenovationPlan`, so it works for hand-drawn and LiDAR-imported plans
  alike. Documented the non-CSG wall-opening approach and the hand-derived
  rotation conventions as traps on [[blueprint-production]].
- Regenerated `project.pbxproj` for the 2 new files; both affected pages'
  `verified_at` moved to `edf889d`.

## [2026-11-03] fix | GraphicsContext.draw overload break

- `.multilineTextAlignment(.center)` chained onto a `Text` passed to
  `context.draw` has no `Text`-returning overload (only `View`'s), breaking
  overload resolution with a confusing "no exact matches" error -- caught
  by CI on the commit right after the 2D/3D toggle. Replaced the two-line
  label with two separate single-line draws. Verified every other
  `context.draw(Text(...)...)` call site in the app only chains methods
  that do have `Text`-returning overrides (`.font`, `.foregroundStyle`) before
  ruling them safe. Documented as a trap on [[blueprint-production]];
  `verified_at: 767a4af`.
