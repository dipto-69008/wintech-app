# Wintech Agro Flutter App — Agent / Editor Guide

> **Flutter cannot run on Replit.** This repl is used only for reading and editing source code. All `flutter pub get`, `flutter analyze`, and `flutter build` commands must be run in a local VS Code / Android Studio environment or CI pipeline.

---

## Project Identity

- **Package name:** `wintech_agro` (in `pubspec.yaml`)
- **Root class:** `WintechAgroApp` (in `lib/main.dart`)
- **Test import:** `import 'package:wintech_agro/main.dart';`
- **DO NOT** use `package:orient_app/...` — that was a previous project name and is now wrong everywhere.

---

## ERP Connection

- **Production ERP URL:** `https://wintech.dawatit.online`
- **Auth:** JWT Bearer (`SESSION_SECRET` env var on ERP side)
- **API client:** `lib/services/api_service.dart` — all HTTP calls go here
- Every screen falls back to local/demo data when offline; no screen should crash if the ERP is unreachable.

---

## File Structure Overview

```
lib/
  main.dart                        ← entry point, WintechAgroApp, named routes
  home_shell.dart                  ← bottom-nav shell (role-aware)
  config/theme.dart                ← light/dark theme, brand colors
  models/
    user_model.dart
    order_model.dart
    target_model.dart
  services/
    api_service.dart               ← all ERP API calls (JWT)
    local_storage_service.dart     ← SharedPreferences: user, orders, targets
    offline_queue_service.dart     ← offline order/transfer upload queue
  screens/
    auth/                          ← login, signup, otp
    onboarding/employee_type_screen.dart
    employee/
      employee_dashboard_screen.dart   ← SR home tab (live ERP stats)
      pos_order_screen.dart            ← POS order, online + offline queue
      order_list_screen.dart
      order_detail_screen.dart
      stock_transfer_screen.dart       ← native stock-transfer (tab 4)
      target_achievement_screen.dart   ← target tab in HomeShell
    target/
      target_screen.dart               ← full /target route
    commission/commission_screen.dart
    admin/
      admin_dashboard_screen.dart
      all_employees_screen.dart
    notifications/notification_screen.dart
    support/support_screen.dart
    settings/
      edit_profile_screen.dart
      digital_id_card_screen.dart
test/
  widget_test.dart                 ← smoke test; uses package:wintech_agro/main.dart
```

---

## Named Routes

| Route | Screen class |
|-------|-------------|
| `/` | SplashScreen |
| `/login` | LoginScreen |
| `/signup` | SignupScreen |
| `/otp` | OtpScreen |
| `/employee-type` | EmployeeTypeScreen |
| `/home` | HomeShell |
| `/pos-order` | PosOrderScreen |
| `/notifications` | NotificationScreen |
| `/support` | SupportScreen |
| `/edit-profile` | EditProfileScreen |
| `/digital-id` | DigitalIdCardScreen |
| `/all-employees` | AllEmployeesScreen |
| `/target` | TargetScreen |
| `/commission` | CommissionScreen |
| `/order-detail` | OrderDetailScreen (args: `OrderModel`) |

---

## SR HomeShell Tabs

| Index | Label | Screen |
|-------|-------|--------|
| 0 | হোম | EmployeeDashboardScreen |
| 1 | অর্ডার | OrderListScreen |
| 2 | কমিশন | CommissionScreen |
| 3 | টার্গেট | TargetAchievementScreen |
| 4 | ট্রান্সফার | StockTransferScreen |

`_switchTab(index)` in HomeShell switches tabs. `onGoToOrders` → tab 1, `onGoToTargets` → tab 3.

---

## Offline Queue

`lib/services/offline_queue_service.dart`:
- `enqueueOrder(Map)` — stores order to SharedPreferences
- `enqueueStockTransfer(Map)` — stores transfer to SharedPreferences
- `syncAll()` — POSTs queued items to ERP; retries up to 5× on network error; drops on business error

HomeShell triggers `syncAll()` on:
1. App startup
2. App resume (WidgetsBindingObserver)
3. Every 2 minutes (Timer.periodic)

---

## Target Module

The target module has **two separate entry points** — both pull from the ERP:

1. **`TargetScreen`** — standalone full-screen (`/target` route), navigated from the main menu. Located at `lib/screens/target/target_screen.dart`.
2. **`TargetAchievementScreen`** — embedded as tab 3 in `HomeShell`. Located at `lib/screens/employee/target_achievement_screen.dart`.

Both call `ApiService.targets()` which hits `GET /api/mobile/targets`. ERP data takes priority; local `TargetModel` is the offline fallback.

`TargetModel` is in `lib/models/target_model.dart`.

---

## Hard Rules for Any Agent Working on This Project

1. **Package name is `wintech_agro`** — never write `orient_app`, `wintech_app`, or any other name.
2. **No withdrawal screen** — `withdrawal_screen.dart` was deleted deliberately. Never recreate it without an explicit user request.
3. **No silent fallbacks** — if an API call fails, show a visible error or the offline banner; never hide failures.
4. **All mutations are API-driven** — orders, stock transfers, targets go to the ERP. Local storage is for fallback display only.
5. **Offline-first for writes** — if a mutating API call fails due to network, enqueue it via `OfflineQueueService`; never silently drop user data.
6. **Branch list** — always load from `/api/mobile/branches` (16 canonical branches). Fallback hardcoded list must match `lib/party-zone-mapping.json` in the ERP parent project.
7. **`flutter analyze` before every build** — run locally; Replit has no Flutter SDK.

---

## User Preferences

- Bengali UI throughout (Hind Siliguri font)
- App is developed locally (VS Code / Android Studio), not run on Replit
- Keep existing Flutter project structure — do not rename packages or restructure folders without explicit request
- Do not add commission withdrawal functionality without explicit request
- All major mutations (orders, transfers) must be ERP API-driven, not local-only
