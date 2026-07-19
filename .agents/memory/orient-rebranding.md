---
name: Wintech Agro — full rebranding history
description: This app was originally ORIENT ERP (and before that, salmon_app). It is now fully Wintech Agro. All future work must use Wintech Agro identifiers only.
---

# Wintech Agro — Rebranding History

## Rule
This app is **Wintech Agro**. Any new platform config, test file, or package reference must use Wintech Agro identifiers. There must be zero "ORIENT ERP", "orient_app", or "salmon" references in code, config, strings, or comments.

**Why:** Originally scaffolded as `salmon_app`, then rebranded to ORIENT ERP, then fully rebranded to Wintech Agro. Any new agent should treat this as a Wintech Agro codebase from the start.

## Current Identifiers
| What | Value |
|------|-------|
| Dart package name | `wintech_agro` |
| Android namespace | `com.example.wintech_agro` |
| Android applicationId | `com.example.wintech_agro` |
| iOS bundle ID | `com.example.wintechAgro` |
| iOS test bundle ID | `com.example.wintechAgro.RunnerTests` |
| Root Flutter widget class | `WintechAgroApp` (in `lib/main.dart`) |
| App logo | `assets/images/wintech.png` |
| Brand color | `#1B9DD9` (Wintech Blue) — `AppTheme.primaryAccent` |
| Demo SR email | `sr@wintech.com` |
| SharedPreferences order key | `wintech_orders` |
