---
name: Orient ERP rebranding complete
description: Documents the completed rebranding from Salmon Developer to ORIENT ERP — all IDs, package names, and file paths that were changed.
---

# Orient ERP Rebranding — Completed

## Rule
There must be zero "Salmon"/"salmon_app" references in code, config, strings, or comments. The app is ORIENT ERP only.

**Why:** The project was originally scaffolded as `salmon_app` but has been fully rebranded to ORIENT ERP. Any new agent should treat this as a green-field ORIENT ERP codebase.

**How to apply:** If you ever add a new platform config, test file, or package reference, use the ORIENT ERP identifiers below — never the old salmon ones.

## Canonical Identifiers
| Identifier | Value |
|-----------|-------|
| Dart package name | `orient_app` |
| Android namespace | `com.example.orient_erp` |
| Android applicationId | `com.example.orient_erp` |
| Android MainActivity path | `android/app/src/main/kotlin/com/example/orient_erp/MainActivity.kt` |
| iOS bundle ID | `com.example.orientErp` |
| iOS test bundle ID | `com.example.orientErp.RunnerTests` |
| Root Flutter widget class | `OrientErpApp` (in `lib/main.dart`) |
