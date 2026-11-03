---
title: AR tape measure (on-device, no extra hardware)
type: subsystem
created: 2026-11-03
updated: 2026-11-03
sources:
  - code: Lexdar/Views/MeasureView.swift
  - code: Lexdar/Views/FloorPlanListView.swift
verified_at: a76ce08
---

The app measures distances by itself, using the device's camera and (where
present) LiDAR, so no laser meter or other accessory is needed. It is
reached from the menu at the top left of the Floor Plans screen
(`Lexdar/Views/FloorPlanListView.swift`) and opens `MeasureView` full screen.

`MeasureView` runs an `ARSCNView` with plane detection, and scene
reconstruction when the device supports it. "Add point" raycasts from the
screen center (the crosshair) first against detected plane geometry and then
against estimated planes, appends the hit as a world-space point, and
`MeasureModel` redraws dots, cylinder lines, and billboarded distance labels.
The panel lists each segment and a running total in meters and feet-inches.
Undo removes the last point; Clear removes all.

> ⚠️ Measurements live only in memory for the open session; nothing is saved
> to a floor plan yet. Read the value off and type it into the editor's wall
> length field. Accuracy is limited by ARKit tracking, so measure slowly,
> aim at textured surfaces, and expect worse results on glass, mirrors, and
> featureless white walls, especially on devices without LiDAR.

> ⚠️ The raycast uses the screen center of the AR view, not the tap
> location, on purpose: it is steadier than a finger on a moving camera
> image. If the center ray finds no surface the point is not added and the
> panel says so; it does not guess a point in mid-air.

> ⚠️ Compile-checked in CI only. How the labels read at distance and how the
> mesh raycast behaves in a real room has not been tested on a device.

Related: [[blueprint-production]] for turning measurements into a drawn plan.
