---
name: Salmon Developer super admin routing
description: How super admin role is routed in home_shell.dart vs regular staff
---

# Super Admin Routing

## Rule
Super admin (`UserModel.isSuperAdmin` → role == 'সুপার অ্যাডমিন') gets a 3-tab CEO-only nav shell: Analytics (SuperAdminDashboard), Property, Settings. They do NOT go through DashboardScreen (which has employee-specific sections like balance, commission, target, withdrawal, digital ID, team overview).

## Why
CEO wants analytics only: district-wise employee/lead/success breakdown, lead status chart, date/district/search filters. Not their own target or commission.

## How to apply
- `home_shell.dart`: `_isSuperAdmin` checked FIRST before customer/investor in `_pages` and `_navItems` getters.
- `_superAdminPages`: [SuperAdminDashboard, PropertyListScreen, SettingsScreen]
- `DashboardScreen` still has a fallback super admin check (shows SuperAdminDashboard as body) but super admin never reaches DashboardScreen from the shell anymore.
- `SuperAdminDashboard` (`lib/screens/dashboard/super_admin_dashboard.dart`) is the authoritative CEO view — do not add balance/commission/withdrawal sections there.
