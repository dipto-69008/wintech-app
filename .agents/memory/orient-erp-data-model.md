---
name: Orient ERP data model
description: User roles, data models, and storage conventions for the ORIENT ERP Flutter app.
---

# Orient ERP — Data Model & Storage Conventions

## User Roles
Four roles determined at login, stored locally, read by `home_shell.dart`:
- **Admin** — `admin@gmail.com` — sales reporting, SR performance, employee management
- **SR/Employee** — `sr@orient.com` — POS, order list, target tracking, commissions
- **Customer** — `customer@gmail.com` — credit limit, purchase history
- **Super Admin** — `superadmin@orient.com` — CEO analytics (routes to `SuperAdminDashboard`, no regular tabs)

## Demo Credentials
- OTP: `123456`, Password: any value

## Storage
- All data is local via `SharedPreferences` through `lib/services/local_storage_service.dart`
- No backend or server; demo data is seeded on first run via `LocalStorageService.seedDemoData()`

## Key Models (`lib/models/`)
- `UserModel` — role, creditLimit, creditUsed, targetAmount, achievedAmount
- `OrderModel` + `OrderItem` — POS orders
- `LeadModel`, `FollowUpModel` — lead tracking
- `TargetModel`, `InvestmentModel`, `PropertyModel`, `TutorialModel`

## Theme Convention
- Colors defined in `lib/config/theme.dart`; primaryAccent = `#8A252C` (maroon)
- Do not hardcode colors in screen files — always reference AppTheme
