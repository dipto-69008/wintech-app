---
name: Flutter-Replit dev workflow
description: How to verify Flutter code changes in this project when no flutter/dart binary is available in the Replit shell.
---

This project (Salmon Developer, and likely other Flutter apps set up the same way) is coded on Replit but has no `flutter`/`dart` binary installed in the shell — confirmed via `which flutter dart` returning empty. There is no workflow or preview for it either.

**Why:** The user's own preference/setup is "code on Replit, test in VS Code, not run on Replit" (see replit.md). This is intentional, not a missing dependency to fix.

**How to apply:**
- Do not try to `flutter pub get` / `flutter run` / `flutter analyze` as a verification step — it will not work.
- Verify changes by: reading the exact model/service constructor signatures and field names before using them in new code, grepping for method names you call to confirm they exist with that exact name/signature, and re-reading edited files after multi-part edits to check brace/paren balance.
- Trust the user to do final runtime verification in VS Code.
