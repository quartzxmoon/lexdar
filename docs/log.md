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

## [2026-11-03] fix | CI simulator runtime mismatch (ENABLE_PREVIEWS)

- The Swift compile itself succeeded this time -- all SwiftCompile/linking
  steps passed. The build then failed at CompileAssetCatalog: "No simulator
  runtime version ... available to use with iphonesimulator SDK version
  ...", a known GitHub Actions macOS runner-image issue
  (actions/runner-images#13317). `ENABLE_PREVIEWS=YES` makes Xcode compile a
  Simulator-targeted preview dylib even for a device-only build, pulling in
  the mismatched SDK. Added `ENABLE_PREVIEWS=NO` as a command-line override
  on both xcodebuild invocations (project setting itself untouched, so local
  Xcode Previews still work). Documented as a trap on
  [[ios-signing-and-sideloading]]; `verified_at: f643814`.

## [2026-11-03] fix | ENABLE_PREVIEWS=NO was a dead end -- Release config is the real fix

- The previous fix (`ENABLE_PREVIEWS=NO`) had zero effect: same "Linking
  __preview.dylib" + simulator-runtime-mismatch failure recurred unchanged.
  Root cause: Xcode 16 stopped honoring `ENABLE_PREVIEWS` for its new "XOJIT
  previews" system. Preview-dylib generation is still Debug-only though, so
  switching the `validate` job to `-configuration Release` (previously
  Debug) actually sidesteps it. `archive` was already Release and
  unaffected; removed its now-confirmed-useless `ENABLE_PREVIEWS=NO`.
  Corrected the trap on [[ios-signing-and-sideloading]] to say what
  actually works instead of what seemed plausible but wasn't; `verified_at:
  fb2d412`.

## [2026-11-03] fix | SUPPORTED_PLATFORMS=iphoneos is the real fix

- Release config (previous commit) dropped the preview-dylib link step but
  the exact same simulator-runtime-mismatch failure recurred unchanged at
  CompileAssetCatalog, disproving the "Debug-only preview dylib" theory.
  Actual cause: actool validates the asset catalog against every platform
  in `SUPPORTED_PLATFORMS` regardless of `-destination`, and this project
  lists `iphonesimulator` there (so local Xcode Simulator builds still
  work). Both xcodebuild invocations now override
  `SUPPORTED_PLATFORMS=iphoneos` for CI only. Rewrote the trap on
  [[ios-signing-and-sideloading]] to record this and the two dead ends
  tried first; `verified_at: 731690c`.

## [2026-11-03] fix | the real cause: a pinned Xcode copy wasn't fully provisioned

- Three earlier fix attempts (ENABLE_PREVIEWS=NO, -configuration Release,
  SUPPORTED_PLATFORMS=iphoneos alone) all treated symptoms of the same CI
  failure without touching the actual cause. Added a diagnostic step
  instead of guessing a fourth time: it showed this runner image carries
  several Xcode installs side by side, and the one pinned via `xcode-select
  -s .../Xcode_16.app/...` had an SDK matching no installed simulator
  runtime, and on another run its device platform wasn't registered as
  installed at all ("iOS 18.0 is not installed") -- not every Xcode copy on
  the image is fully provisioned, only whichever one `xcode-select` already
  defaults to. Removed the explicit Xcode pin from both jobs.
  `SUPPORTED_PLATFORMS=iphoneos` stays (still correct in principle, just
  wasn't sufficient alone). Rewrote the trap on
  [[ios-signing-and-sideloading]] with the real cause and a note to add a
  diagnostic step before guessing next time; `verified_at: 99e9763`.

## [2026-11-03] grow | RoomScan Pro feature-parity audit

- Audited against RoomScan Pro LiDAR's actual feature set (capture modes,
  export formats, annotation tools) and closed the real gaps with original
  code/UI: DXF export (hand-written AutoCAD R12 generator reusing
  BlueprintLayout), detected-fixture labels (surfacing RoomPlan's own ML
  object recognition that was already captured but not shown anywhere),
  a wall-area/ceiling-height summary, photo+note pins placed via a new
  BlueprintEditorView tool, and a separate PencilKit freehand markup layer
  over the finished blueprint.
- Explicitly documented what was *not* built and why (Bluetooth laser
  measure pairing -- no hardware to verify against; curved walls -- not in
  the model; point-cloud export -- RoomPlan data is parametric, not a
  point cloud; specialist CAD/estimating exports -- DXF covers the general
  need) on [[blueprint-production]], rather than leaving gaps undisclosed.
- Added PencilKit.framework and PhotosUI.framework; regenerated
  project.pbxproj for the 2 new files. Fixed a now-false claim on
  [[ios-signing-and-sideloading]] ("added no new frameworks") that this
  same change made incorrect. All three affected pages' `verified_at`
  moved to `d77a5d0`.

## [2026-11-03] fix | Swift 6 actor isolation in PhotosPicker label closure

- CI build succeeded but surfaced a real warning: `store.photoURL(...)`
  (ScanStore is `@MainActor`) called from inside `PhotosPicker`'s `label:`
  trailing closure in the annotation sheet, which isn't guaranteed
  MainActor-isolated under Swift 6 strict concurrency even though it's
  written inline inside a View's body. Resolved the URL as a plain `let`
  in the enclosing (MainActor-isolated) scope instead. Documented as a
  trap on [[blueprint-production]]; `verified_at: 416fb26`.

## [2026-11-03] feature | Property summary, PNG export, View in AR

- From the reference-app screenshots: added `PropertySummaryView` (plans
  grouped by property and floor with room areas and totals),
  `BlueprintPNGExportView`, and `FloorPlanARView`; `FloorPlan` gained optional
  `propertyName`/`floorLevel`. Regenerated project.pbxproj for 3 new files.
  Documented on [[blueprint-production]]; `verified_at: fd4a5fd`.

## [2026-11-03] feature | IFC / OBJ / PLY / XYZ export, AirPrint, ceiling height

- Added `FloorPlanMesh`, `FloorPlanIFCExport`, `ModelExportView`; printer
  button on the PDF screen; ceiling height field on the placement sheet.
  IFC output prototyped in Python and validated with IfcOpenShell before the
  Swift port. Recorded SDK findings for SketchUp / Xactimate on
  [[blueprint-production]]. `verified_at: 4dd2154`.

## [2026-11-03] feature | Door and window styles

- Added `OpeningStyle`, style picker in the editor, and style-aware symbols in
  `BlueprintLayout` (renderers only gained `drawsArc` / `extraLines`). Noted
  on [[blueprint-production]]; `verified_at: d070fbe`.
