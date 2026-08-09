---
name: Wintech Agro data model
description: User roles, data models, and storage conventions for the Wintech Agro Flutter ERP app.
---

# Wintech Agro — Data Model & Storage Conventions

## User Roles
- **Super Admin** — `superadmin@gmail.com` — CEO analytics (routes to `SuperAdminDashboard`, no regular tabs)
- **Admin** — `admin@gmail.com` — Sales reporting, SR performance
- **SR/Employee** — `sr@wintech.com` — POS, order list, target tracking, commissions; dashboard shows branch name
- **Customer** — `customer@gmail.com` — Credit limit, purchase history

Demo OTP: `123456` | Demo password: any value

## Key Models (`lib/models/`)
- `UserModel` — role, branch, creditLimit/Used, targetAmount/achievedAmount, totalSales, badge system
- `OrderModel` + `OrderItem` — POS orders stored in SharedPreferences under key `wintech_orders`
- `TargetModel`, `LeadModel`, `FollowUpModel`, `InvestmentModel`, `TutorialModel`

## Storage
- All data is local via `SharedPreferences` — no backend
- Service class: `lib/services/local_storage_service.dart`
- Orders key: `wintech_orders`
- Current user key: `currentUser`
- Demo data seeded on first launch via `seedDemoData()`

## Order Promotions
- Promotional/free units are stored as separate zero-price `OrderItem` entries with `isBonus: true`; the parent order total remains billable-only.
**Why:** This preserves backward compatibility with existing orders while letting order details and invoices distinguish charged products from free bonus products.
**How to apply:** When adding promotions, append bonus lines rather than changing the paid line quantity or order total; old item maps default to `isBonus: false`.

## SR Branch
- `UserModel.branch` (String, default `''`) — set in `_demoAccounts` map in local_storage_service
- Displayed in employee dashboard header: "Wintech Agro — [branch]"
