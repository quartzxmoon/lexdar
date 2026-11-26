---
title: Cost estimate and shopping list
type: subsystem
created: 2026-11-26
updated: 2026-11-26
sources:
  - code: Lexdar/Models/CostData.swift
  - code: Lexdar/Models/CostModel.swift
  - code: Lexdar/Models/CostService.swift
  - code: Lexdar/Views/CostEstimateView.swift
  - ext: https://www.bea.gov/data/prices-inflation/regional-price-parities-state-and-metro-area
  - ext: https://fred.stlouisfed.org/series/WPUSI012011
  - ext: https://fred.stlouisfed.org/series/CES2000000003
  - ext: https://zippopotam.us/
verified_at: 4a9f476
---

The renovation editor's menu opens "Cost Estimate & Shopping List". It prices everything in
the plan (finishes by area, removed and drawn walls, placed items by count, roofs and
foundations by area or length) and lists it as a shopping list, shareable as text or CSV.

## Where the numbers come from

1. **Starter prices** (`PriceBook`): the app's own US-average installed costs, set against
   October 2026 readings. They are estimates written by hand, not a published price list.
   The first keyword in the item id that matches wins.
2. **Location**: a ZIP code is looked up on Zippopotam.us (free, no key) for the state, then
   the state's BEA Regional Price Parities (2024) scale each line: the "Goods" index for the
   material share and "Services: Other" for the labor share (`CostData`, generated from BEA's
   SARPP download).
3. **Trend**: the app downloads two public FRED CSVs with no key, the construction-materials
   PPI (WPUSI012011) and construction average hourly earnings (CES2000000003), about weekly,
   and scales materials and labor by their change since the baseline in `CostData`.
4. **Local prices**: any line can be replaced with a real local price, remembered per ZIP
   (`CostService.overrides`). This is the "comps" mechanism; there is no free source of live
   retailer prices.

> ⚠️ BEA publishes state and metro price parities, not ZIP-level ones, so every ZIP in a
> state gets the same location factor. "Services: Other" is only a proxy for local labor
> rates. Say so wherever the estimate is shown; it is already in the view's notes.

> ⚠️ `CostData.regions` is a snapshot of BEA's 2024 values (next BEA release was listed as
> December 2026). The baseline readings `baseMaterialsIndex` and `baseWageDollars` are the
> values the starter prices were set against; if the starter prices are ever revised, move
> the baselines to the same month or the trend adjustment double counts.

> ⚠️ Retailer sites (Home Depot, Lowe's and similar) were deliberately not scraped: their
> terms forbid it and the pages change constantly. Do not add a scraper without checking
> that.

> ⚠️ Wall removal is priced as demolition and patching only. Structural beams, headers,
> rewiring, plumbing and permits are not included, and the view says so. Never describe a
> wall as safe to remove.

Compile-checked in CI only; never run on a device.
