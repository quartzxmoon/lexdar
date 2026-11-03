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
verified_at: 767a4af
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

## Not yet built

- No multi-floor/multi-sheet PDF output — one `FloorPlan` is one page.
- No freehand sketch vectorization (tracing a raster Pencil stroke into
  wall segments). `BlueprintEditorView` is precision drafting (drag to
  place a snapped, length-confirmed wall) rather than sketch-to-vector,
  which is the same approach real CAD/floor-plan tools use for "drawn by
  hand" — Apple Pencil input works through it with full precision since
  SwiftUI's gestures don't distinguish Pencil from touch.
