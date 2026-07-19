---
name: Wintech Agro rebranding
description: All changes made to rebrand from ORIENT ERP to Wintech Agro, including color palette, logo, SR branch feature, and naming conventions.
---

# Wintech Agro Rebranding

## Rule
The app is now called **Wintech Agro** (was ORIENT ERP). All branding must use Wintech blue, Wintech logo, and the new app name.

**Why:** User explicitly requested full rebranding with Wintech Agro Bangladesh logo.

## How to apply
- Brand color: `#1B9DD9` (Wintech Blue), defined as `AppTheme.primaryAccent` in `lib/config/theme.dart`
- Logo asset: `assets/images/wintech.png` (copied from uploaded logo)
- App title in MaterialApp: `'Wintech Agro'`
- Class names in main.dart: `WintechAgroApp` / `_WintechAgroAppState`
- Demo SR email: `sr@wintech.com` (was `sr@orient.com`)
- SharedPreferences order key: `wintech_orders` (was `orient_orders`)
- pubspec name: `wintech_agro`

## SR Branch Feature
- `UserModel` now has a `branch` field (String, default `''`)
- Demo SR user (`sr@wintech.com`) has `branch: 'ঢাকা সেন্ট্রাল'`
- Employee dashboard header shows: `'Wintech Agro — ${branch.isNotEmpty ? branch : 'সেলস রিপ্রেজেন্টেটিভ'}'`
- To add branch to any user: set `'branch': '<branch name>'` in `_demoAccounts` map in `local_storage_service.dart`
