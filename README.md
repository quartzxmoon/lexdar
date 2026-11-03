# Lexdar

An original iPadOS/iOS app for LiDAR room scanning, floor plans, and
renovation planning — built on Apple's own **RoomPlan**, **ARKit**, and
**SceneKit** frameworks. Scan a room (or walk a whole house room by room),
get an editable 3D model and 2D floor plan with dimensions, then use the
built-in renovation tools to knock down walls, swap flooring/wall finishes,
and furnish the space from a bundled catalog — all to plan real renovations
before committing to them.

This is your own codebase, with no license server, subscription, or paywall.
Every feature below is unlocked by default because you own the app.

## Requirements

- **Hardware:** an iPad Pro or iPhone Pro with a LiDAR scanner (your iPad
  Pro 12.9" is covered) to *capture* scans. Any iPad/iPhone can *browse,
  edit, and export* scans someone else captured.
- **Xcode 15.4+** on a Mac, targeting **iOS/iPadOS 17.0+**.
- No external dependencies, CocoaPods, or SPM packages — everything is
  first-party Apple frameworks (RoomPlan, ARKit, SceneKit, QuickLook,
  PDFKit).

## Building and installing without a Mac

Xcode only runs on macOS, but you don't need to own a Mac to build or
install this app — `.github/workflows/build-ios.yml` builds it on a
GitHub Actions macOS runner, and once signing secrets are configured it
produces a signed `.ipa` you can sideload from Windows with
[Sideloadly](https://sideloadly.io/). Full step-by-step setup (certificate,
provisioning profile, GitHub secrets — all done via OpenSSL and the Apple
Developer web portal, no Xcode/Keychain Access needed) is in
[`docs/operations/ios-signing-and-sideloading.md`](docs/operations/ios-signing-and-sideloading.md).

## Opening and running

```bash
open Lexdar.xcodeproj
```

1. In Xcode, select the **Lexdar** scheme and your iPad as the run
   destination (RoomPlan requires a physical device — it does not run in
   Simulator).
2. Under the target's **Signing & Capabilities** tab, set your own Team so
   Xcode can code-sign for your device.
3. Build & run (⌘R). On first launch, allow camera access when prompted —
   that's what RoomPlan uses for scanning.

## What's implemented

- **LiDAR room capture** (`Scanning/`) — live AR capture view with on-screen
  guidance ("move closer to the wall", "slow down", etc.), start/finish/save
  flow, powered by `RoomCaptureView`/`RoomCaptureSession`.
- **Persistence** (`Models/ScanStore.swift`) — each scan is saved to
  `Documents/Scans/<id>/` as the exported `.usdz` 3D model, the raw
  `CapturedRoom` JSON (for later re-export or floor-plan regeneration), and
  metadata.
- **3D model viewing** — AR Quick Look preview of the exported USDZ
  (`Views/USDZPreviewView.swift`), including placing it in AR in the real
  room.
- **2D floor plan** (`Views/FloorPlanView.swift`) — top-down render of
  walls/doors/windows/openings with pan, pinch-zoom, and per-wall dimension
  labels in feet/inches or meters.
- **Renovation plans** (`Models/RenovationPlan.swift`) — multiple named
  "what if" plans per scan, each independently tracking:
  - walls marked **removed** (open-concept preview, toggled by tapping the
    wall in either the 2D floor plan or the 3D editor)
  - **floor and wall material swaps** (hardwood, tile, LVP, carpet, paint
    colors, subway tile, shiplap, etc.)
  - **placed catalog items** — fixtures, appliances, furniture, lighting,
    outdoor items — each with position, rotation, and scale
  - free-form notes
- **3D renovation editor** (`Scanning/RenovationSceneView.swift`,
  `Views/RenovationEditorView.swift`) — an interactive SceneKit view of the
  scanned space with a tool switcher:
  - **Select** — orbit the camera (built-in SceneKit camera control); tap a
    placed item to select it, then drag to move it across the floor, pinch
    to resize, twist to rotate.
  - **Remove Walls** — tap any wall to toggle it removed/restored.
  - **Floor Material** / **Wall Finish** — pick a swatch from the catalog,
    then tap the floor/wall to apply it.
  - **Place Item** — pick anything from the catalog, then tap a floor to
    drop it in.
- **Build-out catalog** (`Models/Catalog.swift`) — starter inventory across
  flooring, wall finishes, kitchen fixtures, bathroom fixtures, appliances,
  furniture, lighting, and outdoor items (decks, patios, pergolas, pools,
  fire pits, sheds, etc.). Items render as labeled, correctly-dimensioned
  primitive shapes by default — see "Swapping in real 3D assets" below to
  upgrade them to real models.
- **Renovation summary export** (`Views/RenovationSummaryView.swift`) — a
  generated PDF (via `PDFKit`/`UIGraphicsPDFRenderer`, no external deps)
  listing floor area, walls removed, material changes, and a full itemized
  furnish/fixture list with dimensions — shareable via the system share
  sheet (AirDrop, Mail, Files, print, hand to a contractor, etc.).

## Project layout

```
Lexdar/
  LexdarApp.swift              App entry point
  Info.plist                   Camera usage string, orientations, etc.
  Models/
    ScanProject.swift          Persisted scan metadata
    ScanStore.swift            Disk persistence for scans + renovation plans
    RenovationPlan.swift       Per-scan "what if" plan (walls/materials/items)
    CatalogItem.swift          Catalog item model + categories
    Catalog.swift               Starter inventory data
  Scanning/
    RoomCaptureCoordinator.swift   RoomPlan session lifecycle + delegate
    RoomCaptureRepresentable.swift SwiftUI wrapper for RoomCaptureView
    ScanCaptureView.swift          Full-screen capture flow UI
    RoomSceneBuilder.swift         CapturedRoom + RenovationPlan -> SCNScene
    RenovationSceneView.swift      Interactive 3D editor (gestures, tools)
  Views/
    ScanListView.swift             Root: list of saved scans
    ScanDetailView.swift           One scan: 3D preview, floor plan, plans
    FloorPlanView.swift            2D top-down renderer w/ wall-tap editing
    RenovationEditorView.swift     3D editor screen (toolbar + scene + sheets)
    CatalogBrowserView.swift       Searchable catalog grid
    RenovationSummaryView.swift    PDF generation + preview + share
    USDZPreviewView.swift          AR Quick Look wrapper
```

## Swapping in real 3D assets

Catalog items default to simple colored/labeled primitives (boxes,
cylinders, planes) sized to real-world dimensions — enough to judge scale
and layout. To use real-looking models instead:

1. Add `.usdz` files to a new `Resources/Models/` group in Xcode (drag them
   in, "Copy items if needed").
2. Set `assetName` on the relevant `CatalogItem` entries in `Catalog.swift`
   to match the filename (without extension).
3. In `RoomSceneBuilder.placedItemNode(for:)`, branch on
   `catalogItem.assetName != nil` to load
   `SCNScene(named: "\(assetName).usdz")`'s root node instead of calling
   `primitiveGeometry(for:)`.

Make sure any assets you add are ones you have the rights to use/distribute
(purchased/licensed asset packs, your own models, or assets under a license
that permits this use) — this scaffold intentionally ships with zero bundled
3D asset files to avoid any licensing questions.

## Known limitations / good next steps

- Wall "removal" and material swaps are visual-only, inside the app — they
  are a planning aid, not structural engineering. Any wall removal must be
  checked by a licensed contractor/engineer (load-bearing walls, plumbing
  and electrical routed inside walls, permits) before real work begins.
- Multi-room/whole-house scans rely on RoomPlan's own multi-room capture
  (walking between rooms in one continuous session); there's no custom
  room-stitching logic beyond what RoomPlan provides.
- The renovation summary PDF is intentionally simple (text + dimensions,
  two pages). Natural next step: render the 2D floor plan itself into the
  PDF alongside the text.
- No cloud sync/backup — everything lives in the app's local
  `Documents/Scans/` folder. Consider adding iCloud Drive or a Files
  document-based flow if you want scans to follow you across devices.
