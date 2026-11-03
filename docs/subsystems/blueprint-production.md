---
title: Blueprint production (hand-drawn + LiDAR, contractor-grade output)
type: subsystem
created: 2026-11-03
updated: 2026-11-03
sources:
  - code: Lexdar/Models/FloorPlan.swift
  - code: Lexdar/Scanning/RoomPlanImporter.swift
  - code: Lexdar/Views/BlueprintLayout.swift
  - code: Lexdar/Views/BlueprintView.swift
  - code: Lexdar/Views/BlueprintEditorView.swift
  - code: Lexdar/Views/BlueprintPDFExportView.swift
  - code: Lexdar/Views/FloorPlanListView.swift
  - code: Lexdar/LexdarApp.swift
  - code: Lexdar/Views/ScanDetailView.swift
  - code: Lexdar/Scanning/FloorPlanSceneBuilder.swift
  - code: Lexdar/Views/FloorPlan3DPreviewView.swift
  - code: Lexdar/Views/BlueprintDXFExportView.swift
  - code: Lexdar/Views/BlueprintAnnotationView.swift
  - code: Lexdar/Models/ScanStore.swift
  - code: Lexdar/Views/BlueprintPNGExportView.swift
  - code: Lexdar/Views/FloorPlanARView.swift
  - code: Lexdar/Views/PropertySummaryView.swift
verified_at: fd4a5fd
---

A second, parallel subsystem to [[scan-to-renovation-flow]]'s
RoomPlan/SceneKit renovation pipeline: this one produces the formal,
dimensioned floor-plan *drawing* (walls to real thickness, dimension
lines, door swing arcs, window symbols, room square footage, scale bar,
PDF export at a real architectural scale) rather than an editable 3D
scene. It exists because the renovation pipeline is deliberately tied to
RoomPlan's `CapturedRoom`, which can only ever be produced by a LiDAR
scan — but a floor plan should also be produceable **by hand**, with no
scan at all.

## Why a separate `FloorPlan` model

`CapturedRoom` has no public initializer; it's only ever handed to you by
RoomPlan's own processing. There is no way to construct one from a
hand-drawn sketch. So `FloorPlan` (own model: `FloorPlanWall`,
`FloorPlanOpening`, `FloorPlanRoom`) exists as the thing **both** a LiDAR
scan and a hand-drawn sketch can produce, so every downstream consumer
(the blueprint renderer, the PDF exporter) works on one shape of data
regardless of where the plan came from:

- `RoomPlanImporter.makeFloorPlan(from:scanID:name:)` — one-shot, one-way
  conversion of a `CapturedRoom` into a `FloorPlan`, called when the user
  taps "Generate Contractor-Grade Floor Plan" on a scan's detail screen.
  Reuses `CapturedRoom.Surface.identifier` as the `FloorPlanWall`/
  `FloorPlanOpening` id and pulls room boundaries straight from
  `CapturedRoom.floors[].polygonCorners` (RoomPlan already computes these
  — no need to reimplement room-boundary detection for the LiDAR path).
- `BlueprintEditorView` — hand-drawing tools (grid + angle snapping, an
  editable length confirm after each wall drag, tap-to-place doors/
  windows/openings, tap-to-trace room boundaries, drag-to-correct
  endpoints with connected corners moving together) that build a
  `FloorPlan` directly, with no LiDAR/ARKit involved at all.

Once either path produces a `FloorPlan`, it's edited and rendered
identically — in particular, `BlueprintEditorView` also works on a
LiDAR-generated plan, for hand-correcting a wall RoomPlan judged wrong.

> ⚠️ A `FloorPlan` generated from a scan is a **snapshot, one-way
> conversion** — it is not kept in sync with the `CapturedRoom` it came
> from. Re-generating after a re-scan creates a brand new `FloorPlan`
> (see `ScanStore.generateFloorPlan`) rather than updating the old one, so
> hand-corrections made to a previous generation are never silently
> discarded; the user deletes the stale one explicitly.

## Shared layout, two renderers

`BlueprintLayout.build(from:)` is the one place that turns a `FloorPlan`
into drawing primitives — dimension lines with their extension-line
offsets already computed, door swing arcs, window break symbols, room
label positions. Two renderers draw the *same* `BlueprintLayout`:

- `BlueprintView` — SwiftUI `Canvas`/`GraphicsContext`, on-screen, pan/zoom.
- `BlueprintPDFRenderer` (in `BlueprintPDFExportView.swift`) — raw
  `CGContext` calls inside `UIGraphicsPDFRenderer`, for the exported PDF.

This keeps the dimensioning math in one place; only the "draw a line" /
"draw text" calls are duplicated between the two (SwiftUI `Path`/
`GraphicsContext.stroke` vs. `CGContext.move/addLine/strokePath`).

> ⚠️ `BlueprintPDFRenderer.chooseScale` only picks a **standard**
> architectural scale (1/4", 3/16", 1/8", 1/16" per foot) when the plan
> actually fits the page at that scale; otherwise it falls back to a
> custom fit-to-page scale **and labels it "NOT TO SCALE"** rather than
> silently mislabeling it as one of the standard ratios. If a future
> change adds more page sizes or scales, keep that honesty — a blueprint
> labeled with a scale a ruler can't actually use against it is worse
> than no scale notation at all.

> ⚠️ LiDAR dimensional accuracy is generally within a few centimeters —
> good for planning, not survey- or stamped-drawing-grade precision. The
> PDF title block says so ("preliminary planning drawing — not for
> construction or permitting without review... by a licensed
> professional") on purpose; don't strengthen that language to imply
> these exports are permit-ready without an actual licensed review step
> backing that claim.

> ⚠️ There is no true-north calibration. The PDF/on-screen north arrow is
> the conventional architectural fallback ("plan north") used when true
> north hasn't been established — it always points the same direction on
> the page regardless of the room's real-world orientation. Adding real
> calibration would mean capturing a heading via `CLLocationManager` at
> scan/draw time and storing it, which this pass deliberately left out of
> scope (see `FloorPlan` — no `northAngleRadians` field exists yet).

## Live 2D/3D toggle

`BlueprintEditorView` can flip between the drafting `Canvas` and a live 3D
preview (`FloorPlan3DPreviewView` → `FloorPlanSceneBuilder`) in the same
screen — draw a wall, tap the 3D button, see it standing up immediately.
This is a separate, lighter builder from `RoomSceneBuilder` (which needs a
RoomPlan `CapturedRoom` + `RenovationPlan` for the furnishing workflow):
`FloorPlanSceneBuilder` only ever needs a `FloorPlan`, so it works equally
for a hand-drawn plan or an imported LiDAR one.

> ⚠️ `FloorPlanSceneBuilder.wallNode` does **not** perform a true geometric
> boolean cut for door/window openings — like `RoomSceneBuilder`, it draws
> solid wall segments between openings (sorted along the wall, gaps left
> where each opening's width falls) plus a translucent colored box marking
> each opening. A door/window very close to a wall's end, or two openings
> closer together than their combined half-widths, can produce a
> zero-or-negative-length segment; the `where segEnd - segStart > 0.02`
> guard in `wallNode` drops those rather than crashing, but the wall will
> visually show one continuous gap instead of two separate openings in
> that case.
>
> ⚠️ The floor/wall coordinate mapping (`FloorPlanSceneBuilder`'s `-90°`
> X-rotation for `SCNShape` floors, `-angle` Y-rotation for wall boxes) was
> derived by hand from SceneKit's rotation conventions, not copied from
> `RoomSceneBuilder` (which uses `CapturedRoom.Surface.transform` directly
> instead of deriving rotations from a 2D direction vector). If either
> renderer's coordinate convention changes, re-derive this one
> independently rather than assuming they still match.

> ⚠️ `GraphicsContext.draw(_:at:anchor:)` requires an actual `Text` value,
> not `some View`. `Text` has its own `Text`-returning overrides for
> `.font(_:)` and `.foregroundStyle(_:)` (confirmed against Apple's docs),
> so those chain safely — but `.multilineTextAlignment(_:)` has **no**
> `Text`-returning override, only the `View` one, so chaining it onto a
> `Text` passed to `context.draw` silently produces `some View` and breaks
> the call with a confusing "no exact matches" error. This broke the
> first build after the 2D/3D toggle landed. Before chaining any further
> `Text` modifier here, check it has a `Text`-returning overload — not
> just a `View` one — the same way `.font`/`.foregroundStyle` do.

## Feature-parity additions (DXF, detected objects, notes, markup)

Added after an explicit audit against RoomScan Pro LiDAR's feature set
(capture modes, exports, annotation tools) — own code/UI throughout, not
copied from that app:

- **`BlueprintDXFExportView.swift`** (`BlueprintDXFExporter`) — hand-written
  AutoCAD R12 ASCII DXF generator, reusing `BlueprintLayout` (the same
  geometry the PDF/on-screen views draw). Walls are double lines + end
  caps (not a single centerline), doors get a real `ARC` entity for the
  swing, dimensions are plain `LINE`+`TEXT` (not associative AutoCAD
  `DIMENSION` objects — see trap below), everything is on separate layers
  (WALLS/DOORS/WINDOWS/OPENINGS/ROOMS/DIMENSIONS/TEXT).
- **Detected-object labels** (`CapturedRoom.Object.Category` extension in
  `RoomPlanImporter.swift`, surfaced in `ScanDetailView`) — RoomPlan's own
  ML object classification (toilet, bathtub, sink, appliances, furniture)
  was already being captured and rendered as translucent ghosts by
  `RoomSceneBuilder`; this just lists it by name/count, matching the kind
  of "recognizes toilets & baths" feature other LiDAR floor-plan apps
  market, without needing any new recognition logic of our own.
- **Wall area / ceiling height summary** (`ScanDetailView.scanSummaryRows`)
  — contractor-oriented stats (total wall area, ceiling height or range,
  door/window/room counts) computed from the same `CapturedRoom` data
  already loaded.
- **Photo + note annotations** (`PlanAnnotation` in `FloorPlan.swift`,
  placed via the `.note` tool in `BlueprintEditorView`, rendered as
  numbered pins in both the editor and `BlueprintView`) — the "take
  photos and type notes, see them positioned on the plan" survey/inventory
  workflow. Photos are stored as separate JPEG files
  (`ScanStore.savePhoto`/`photoURL`), referenced by filename only, so the
  `FloorPlan` JSON stays small.
- **`BlueprintAnnotationView.swift`** — a separate, PencilKit-based
  freehand markup layer over the *finished* blueprint (circle a problem,
  write a note directly on the drawing), distinct from
  `BlueprintEditorView`'s precision wall-drafting. Saved as a `PKDrawing`
  (`ScanStore.markupURL`), independent of the wall/door/room geometry.

> ⚠️ The DXF exporter's dimension lines are **not** true AutoCAD
> `DIMENSION` entities — they're plain `LINE` + `TEXT`, positioned
> correctly but not "live" (won't recompute if a wall is dragged inside
> the CAD tool). Said explicitly in the export screen's description text;
> don't let that wording drift toward implying associative dimensions.

> ⚠️ DXF R12 (`$ACADVER` = `AC1009`) was chosen specifically for broad
> import compatibility and predates the `$INSUNITS` header variable, so
> there's no reliable way to declare "these coordinates are meters" in the
> header — a `TEXT` entity in the drawing says so instead. If a reader
> doesn't check that note and assumes a different unit, the drawing will
> import at the wrong scale; this is a real, disclosed limitation of
> picking R12 over a newer DXF version, not a bug.

> ⚠️ Photo/note annotations and the Pencil markup layer are **not**
> included in the PDF or DXF exports yet — they're visible in-app
> (`BlueprintEditorView`, `BlueprintView`) only. Adding them to the
> formal exports is a reasonable next step, not an oversight to "fix"
> without reading this: it was deliberately scoped out to keep this pass
> bounded.

> ⚠️ Resolve any `ScanStore` call (it's `@MainActor`) in the view body
> itself, never inside a trailing closure passed to a SwiftUI API like
> `PhotosPicker`'s `label:` — those closures aren't guaranteed
> MainActor-isolated under Swift 6 strict concurrency, even though they're
> written inline inside a View's `body`. CI caught exactly this
> (`store.photoURL(...)` called from inside `PhotosPicker`'s label
> closure in the annotation sheet) as a warning, not yet an error under
> this project's settings — fix is to capture the resolved value as a
> plain `let` in the enclosing scope and reference that inside the
> closure instead of calling the actor-isolated method from within it.

## Property roll-up, PNG export, View in AR (second RoomScan screenshot audit)

Reviewing screenshots of the reference app surfaced three more functional
gaps, closed with original code:

- **Property summary** (`PropertySummaryView`): plans grouped by
  `FloorPlan.propertyName`, then `FloorPlan.floorLevel`, with a per-room
  area list and per-floor / per-property totals in m² and sq ft. Plans are
  assigned via the "Property & Floor..." menu item (`PlanPlacementSheet`).
- **PNG export** (`BlueprintPNGExportView`): renders `BlueprintView` through
  SwiftUI `ImageRenderer` at a fixed 1600x1200 pt frame, 2x scale.
- **View in AR** (`FloorPlanARView`): builds the extruded model with
  `FloorPlanSceneBuilder`, writes it with `SCNScene.write(to:)` as a
  `.usdz`, and opens it in `USDZPreviewView` (AR Quick Look).

> ⚠️ `FloorPlan.propertyName` and `floorLevel` are deliberately **optional**.
> Plans already saved to disk lack these keys, and synthesized `Codable`
> only tolerates missing keys for optionals; making them non-optional would
> make every existing saved plan fail to decode and silently vanish from
> `ScanStore.reload`.

> ⚠️ Not verified on device: whether `SCNScene.write` to USDZ keeps the
> day/night lights and the wall/floor materials, and how the PNG looks when
> `BlueprintView`'s Canvas is rendered via `ImageRenderer`. Both compile in
> CI but need a hands-on check on the iPad.

## Explicitly not built (checked against RoomScan Pro LiDAR, scope cut on purpose)

- **Bluetooth laser measure pairing** (Bosch/Leica, which RoomScan Pro
  supports) — would need real hardware to test a hand-rolled BLE GATT
  protocol implementation against; claiming working hardware support
  without that verification would be dishonest. Not started.
- **Curved wall support** — `FloorPlanWall` is a straight segment only;
  RoomScan Pro supports curved walls via its own capture/editing model.
  Would need a real model change (an arc/spline wall type), not a quick
  addition.
- **Point cloud export** (PLY/OBJ/XYZ) — RoomPlan's `CapturedRoom` is
  parametric surfaces, not a raw point cloud; a real point cloud would
  need capturing `ARMeshAnchor` geometry during the scan session
  separately, which `RoomCaptureCoordinator` doesn't currently do.
- **Bluetooth/ML-assisted curved or non-vertical wall scanning**, exterior/
  plot-specific capture UI, and CAD-system-specific exports (Xactimate
  ESX, Symbility FML, IFC/BIM) — all real RoomScan Pro features, all
  skipped for now; DXF covers the general CAD-interchange need those
  specialist formats exist to serve.

## Not yet built

- No multi-floor/multi-sheet PDF output — one `FloorPlan` is one page.
- No freehand sketch vectorization (tracing a raster Pencil stroke into
  wall segments). `BlueprintEditorView` is precision drafting (drag to
  place a snapped, length-confirmed wall) rather than sketch-to-vector,
  which is the same approach real CAD/floor-plan tools use for "drawn by
  hand" — Apple Pencil input works through it with full precision since
  SwiftUI's gestures don't distinguish Pencil from touch.
