# Wintech Agro — Flutter Mobile App

## Overview

**Wintech Agro** is a Flutter mobile app for Wintech Agro's sales representatives (SRs), admins, and customers. The UI is fully in Bengali (Hind Siliguri font). It connects live to the **Wintech ERP** at `https://wintech.dawatit.online` and falls back to local/demo data when offline.

> **This is a Flutter project — it cannot run on Replit.** All development, analysis, and builds must be done locally (VS Code / Android Studio) or via CI. On Replit, you can read and edit source code only.

---

## Quick Start (Local / VS Code)

```bash
cd wintech-app-main
flutter pub get
flutter analyze          # fix any errors before building
flutter run              # on emulator or physical device
flutter build apk --release
```

---

## Package & Bundle IDs

| Platform | ID |
|----------|----|
| Dart package name | `wintech_agro` |
| Android namespace / applicationId | `com.example.wintech_agro` |
| iOS bundle ID | `com.example.wintechAgro` |

> **Important:** The package is `wintech_agro`. Any import using `package:orient_app/...` or `package:wintech_app/...` is wrong — use `package:wintech_agro/...`.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x / Dart SDK ^3.12.2 |
| Local storage | `shared_preferences` |
| Remote API | Wintech ERP REST API (JWT Bearer auth) |
| Fonts | Google Fonts — Hind Siliguri |
| PDF | `pdf` + `printing` |
| Location | `geolocator` |

---

## Brand Colors

| Name | Hex | Usage |
|------|-----|-------|
| Wintech Blue | `#1B9DD9` | Primary accent |
| Light Blue | `#56C1E8` | Secondary |
| Background | `#F0F8FD` | App background |

Defined in `lib/config/theme.dart`.

---

## User Roles & Demo Accounts

| Role | Demo Email | Key Features |
|------|-----------|-------------|
| এস.আর. (SR) | `sr@wintech.com` | Dashboard, POS orders, targets, commissions, stock transfer |
| অ্যাডমিন | `admin@gmail.com` | Sales reporting, SR performance, order analytics |
| কাস্টমার | `customer@gmail.com` | Credit limit, purchase history |
| সুপার অ্যাডমিন | `superadmin@gmail.com` | CEO analytics |

**Demo password / OTP:** any value works (demo mode). ERP employees log in with real credentials.

---

## ERP Connection

All API calls go through `lib/services/api_service.dart`.

- **Base URL:** `https://wintech.dawatit.online` (`ApiService.defaultBaseUrl`)
- **Auth:** JWT Bearer token — obtained via `POST /api/mobile/auth/login`
- **Offline fallback:** every screen shows local/demo data when the ERP is unreachable

### Key API Endpoints Used by the App

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/mobile/auth/login` | POST | Employee login → JWT |
| `/api/mobile/dashboard` | GET | Today/month sales, targets, branch |
| `/api/mobile/products` | GET | Live product catalog |
| `/api/mobile/parties` | GET | Live customer/party list |
| `/api/mobile/orders` | GET / POST | Order list / create order |
| `/api/mobile/targets` | GET / POST | Target list / report progress |
| `/api/mobile/surveys` | GET / POST | Survey list / submit survey |
| `/api/mobile/stock-transfers` | GET / POST | Transfer list / create transfer |
| `/api/mobile/branches` | GET | Live 16-branch list |

---

## Offline Upload Queue

`lib/services/offline_queue_service.dart` — queues orders and stock transfers made while offline.

- **Trigger:** app start, app resume (lifecycle), every 2 minutes
- **Retry:** up to 5 times on network error; business errors (e.g. credit limit) are dropped
- **Storage:** `SharedPreferences` (`offline_order_queue` / `offline_transfer_queue`)

---

## Key Files

### Entry & Navigation
| File | Role |
|------|------|
| `lib/main.dart` | App entry point, `WintechAgroApp`, named routes |
| `lib/home_shell.dart` | Role-based bottom-nav shell; SR tabs: Dashboard, Orders, Commissions, Targets, **Transfer** |
| `lib/config/theme.dart` | Light / dark theme |

### Services
| File | Role |
|------|------|
| `lib/services/api_service.dart` | All ERP REST calls (JWT auth) |
| `lib/services/local_storage_service.dart` | SharedPreferences: user, orders, targets, etc. |
| `lib/services/offline_queue_service.dart` | Offline order/stock-transfer upload queue |

### Models
| File | Role |
|------|------|
| `lib/models/user_model.dart` | User / employee model |
| `lib/models/order_model.dart` | Order / sale model |
| `lib/models/target_model.dart` | Target model |

### Screens (by role)
| File | Role |
|------|------|
| `lib/screens/employee/employee_dashboard_screen.dart` | SR dashboard (live ERP stats) |
| `lib/screens/employee/pos_order_screen.dart` | POS order entry (online + offline queue) |
| `lib/screens/employee/order_list_screen.dart` | Order list (live ERP / local fallback) |
| `lib/screens/employee/order_detail_screen.dart` | Order detail |
| `lib/screens/employee/stock_transfer_screen.dart` | **Native stock transfer** (list + create, offline-safe) |
| `lib/screens/employee/target_achievement_screen.dart` | Target progress tab (live ERP) |
| `lib/screens/target/target_screen.dart` | Full target screen (`/target` route, live ERP) |
| `lib/screens/commission/commission_screen.dart` | Commission history (local) |
| `lib/screens/admin/admin_dashboard_screen.dart` | Admin dashboard (live ERP) |
| `lib/screens/admin/all_employees_screen.dart` | All employees list |
| `lib/screens/auth/login_screen.dart` | Login (ERP first, demo fallback) |

---

## Named Routes (main.dart)

| Route | Screen |
|-------|--------|
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
| `/order-detail` | OrderDetailScreen |

---

## SR Bottom Navigation Tabs (HomeShell)

| Index | Tab (Bengali) | Screen |
|-------|--------------|--------|
| 0 | হোম | EmployeeDashboardScreen |
| 1 | অর্ডার | OrderListScreen |
| 2 | কমিশন | CommissionScreen |
| 3 | টার্গেট | TargetAchievementScreen |
| 4 | ট্রান্সফার | StockTransferScreen |

---

## What Must NOT Be Added

- **`withdrawal_screen.dart` or any commission-withdrawal UI** — intentionally removed; do not recreate without explicit user request.
- **`package:orient_app/...` imports** — the package name is `wintech_agro`; any reference to `orient_app` is a leftover from a previous project and must be deleted.

---

## ERP (Next.js / Node) — Companion Project

The ERP backend lives in the **parent directory** (`../`), not in `wintech-app-main/`. It is a Next.js 14 App Router project with MongoDB. Mobile API routes are under `app/api/mobile/`. The ERP is deployed at `https://wintech.dawatit.online`.

Key ERP files relevant to the Flutter app:
- `lib/mobile-auth.ts` — JWT sign/verify (uses `SESSION_SECRET`)
- `middleware.ts` — CORS for `/api/mobile/*`
- `app/api/mobile/auth/login/route.ts`
- `app/api/mobile/orders/route.ts`
- `app/api/mobile/stock-transfers/route.ts`
- `app/api/mobile/branches/route.ts`
- `lib/party-zone-mapping.json` — canonical 16 operational branches (source of truth)

---

## Known Limitations / Next Steps

| Area | Status |
|------|--------|
| Employee passwords | Plain text in DB — must be bcrypt-hashed before production |
| Native survey screen | Not yet in Flutter; SRs use `/m/survey` web portal |
| Commission data | Local-only; not yet ERP-connected |
| ERP order auto-refresh | Manual refresh only; no SSE/WebSocket yet |
| Offline queue errors | Business errors silently dropped; no failed-queue UI |
| `flutter analyze` | Must be run locally; Replit has no Flutter SDK |
