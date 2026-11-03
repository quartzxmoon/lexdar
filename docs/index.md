# Lexdar -- documentation

LiDAR room-scanning + renovation-planning app for iPad/iPhone (RoomPlan + SceneKit).

This directory is a wiki maintained by an LLM: linked markdown pages, nothing outside the
repository. The rules are in [`CLAUDE.md`](CLAUDE.md).

## Start here

1. [[scan-to-renovation-flow]] -- the whole scan -> plan -> edit -> export pipeline
2. [[blueprint-production]] -- hand-drawn / LiDAR contractor-grade blueprints
3. [[ios-signing-and-sideloading]] -- building and installing the app with no Mac

---

## concepts

<!-- TODO: pages under Domain and product concepts. Mostly survive code changes. `- [[page-name]] -- one line` -->

## architecture

- [[scan-to-renovation-flow]] -- how a scan becomes a persisted CapturedRoom, how a
  RenovationPlan layers wall removals/materials/placed items on top, and how the 3D
  editor and PDF export both read that same plan

## subsystems

- [[blueprint-production]] -- hand-drawn + LiDAR-generated contractor-grade
  blueprints, built on an app-owned `FloorPlan` model independent of `CapturedRoom`
- [[ar-measure]] -- on-device AR tape measure (camera + LiDAR), no accessory needed

## decisions

<!-- TODO: pages under Why it was decided that way (ADRs, known defects). `- [[page-name]] -- one line` -->

## reference

<!-- TODO: pages under Schemas, APIs, env vars -- documents you look values up in. `- [[page-name]] -- one line` -->

## operations

- [[ios-signing-and-sideloading]] -- CI build/sign pipeline + Windows-based sideloading
  (no Mac needed to build or install)

## history

<!-- TODO: pages under Development history, lessons, migrated records. `- [[page-name]] -- one line` -->

---

## Using this wiki

```
/docs-sync     right after a deploy or release -- reads only what changed since verified_at
/docs-lint     integrity check (orphans, broken links, broken sources, stale, unverified)
/docs-query    ask the docs. If it is not there, the answer says so
/docs-status   commits not yet reflected, stale pages, recent work
```

Every page carries `verified_at`, the commit it was checked against. Change code, run
`/docs-sync`.
