# AnokiX Trader — iOS

Native **SwiftUI** port of the AnokiX Trader app, built to mirror the Android app
(`Android/AnokiXTraderV2`) and the Trader Portal (`http://155.117.20.51:5720/`).
Same purple brand (`#7C3AED`), same modules, same mock-first data.

## Requirements
- **Xcode 16+** (the project uses file-system-synchronized groups, `objectVersion = 77`).
- iOS 16.0+ deployment target. Universal (iPhone + iPad).
- No third-party dependencies — pure SwiftUI + Foundation.

## Open & run
```
open AnokiXTrader.xcodeproj
```
Select the **AnokiXTrader** scheme and run on a simulator. Any non-empty email/password
signs in (mock auth — see below).

> Built on Windows, so it has **not been compiled against Xcode yet**. The first build on
> a Mac may surface minor adjustments. The asset catalog ships an empty `AppIcon` set —
> drop a 1024×1024 icon in to silence the icon warning.

## Architecture
Every Swift file lives under `AnokiXTrader/` and is auto-included via the synchronized
group, so adding files needs no `.pbxproj` edits.

```
App/            App entry + RootView (splash → welcome → login → main switch)
Theme/          Brand palette, Color(hex:), Card, chips, badges, button styles
Models/         Structs ported 1:1 from com.anokix.trader.model.*
Data/           MockData (verbatim portal data), Cart, Session, Money helper
Components/     Charts (line/sparkline/donut), generic rows, stat tiles, toast
Features/
  Auth/         Splash, Welcome, Login
  Main/         MainTabView (5 tabs), Router, Drawer (12-item sidebar), More
  Dashboard/    KPIs, quick actions, sales chart, recent orders, top products…
  Sell/         POS grid + cart + Checkout (VAT, payment method, receipt)
  Orders/       Order list + tracking-timeline detail
  Wallet/       Balance card, action grid, transactions
  Inventory/    Stat cards, filters, stock bars, adjust-qty sheet
  Marketplace/  Hero, distributors, promos, bestsellers + order cart
  Modules/      Payments, Customers, Offers (list screens)
  Airtime/      Service/provider/number/amount → voucher
  Rewards/      Limes points, vouchers, VAS, points activity
  Analytics/    KPIs, revenue line, category donut, health, insights
  Reports/      Stats, report-type grid, recent reports
  Notifications/Filter chips + read state
  Settings/     Status cards, 8 section cards, danger zone
  Support/      Atlas AI, contacts, device health, KB, tickets
```

### Navigation
- `Router` (ObservableObject) holds the selected `Tab`, the drawer open state, and the
  currently `presented` secondary `Module`.
- The 5 bottom tabs (Home / Sell / Orders / Wallet / More) are `NavigationStack`s.
- Secondary modules (Inventory, Marketplace, Analytics, …) open as a `fullScreenCover`
  hosted by `ModuleHost`, mirroring the Android Activities reached from the drawer / More.
- The left **Drawer** mirrors the portal sidebar exactly (12 items + profile/logout footer).

## Mock-first (same constraint as Android)
There is **no trader API yet** (`api/trader/*` 404s) and **no real trader account** — the
only working backend login is a *distributor*. So all data is served from `MockData.swift`,
which is copied verbatim from the Android `MockData.java` (itself extracted from the portal).
When the trader API ships, add an `ApiTraderRepository` feeding the same view models.
