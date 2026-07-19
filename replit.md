# Wintech Agro — Flutter Mobile App

## What This Project Is
**Wintech Agro** is a Flutter (Dart) mobile application for Bengali-speaking business users. It is a role-based ERP system with POS order entry, sales analytics, target tracking, commission management, and customer credit management. The UI is in Bengali (Hind Siliguri font) with a Wintech blue theme.

**This is a Flutter project — it cannot run directly on Replit.** Development and builds happen locally or via CI (e.g. GitHub Actions, Codemagic). On Replit, you can read and edit code; use a local Flutter environment or CI to run/build it.

## Package & Bundle IDs
| Platform | ID |
|----------|----|
| Dart package | `wintech_agro` |
| Android namespace / applicationId | `com.example.orient_erp` |
| iOS bundle ID | `com.example.orientErp` |

## Tech Stack
- **Framework**: Flutter 3.x / Dart SDK ^3.12.2
- **Storage**: SharedPreferences (fully local, no backend/server)
- **Key packages**: `google_fonts`, `shared_preferences`, `intl`, `image_picker`, `geolocator`, `video_player`
- **App logo**: `assets/images/wintech.png`

## Brand Colors
- **Primary accent**: `#1B9DD9` (Wintech Blue)
- **Secondary accent**: `#56C1E8` (Light Blue)
- **Background**: `#F0F8FD` (Very light blue tint)
- Defined in `lib/config/theme.dart`

## User Roles & Demo Accounts
| Role | Demo Email | Features |
|------|-----------|----------|
| অ্যাডমিন (Admin) | admin@gmail.com | Sales reporting dashboard, SR performance, order analytics |
| এস.আর. (Sales Rep) | sr@wintech.com | Dashboard (shows branch), POS order entry, target/achievement tracking, commissions |
| কাস্টমার (Customer) | customer@gmail.com | Credit limit view, purchase history, monthly purchases |
| সুপার অ্যাডমিন (Super Admin) | superadmin@gmail.com | CEO-level analytics view |

**Demo OTP**: `123456` · **Demo Password**: any value

## SR Branch Display
SR users have a `branch` field on their profile (`UserModel.branch`). The employee dashboard header displays the branch name (e.g. "Wintech Agro — ঢাকা সেন্ট্রাল"). Set in `lib/services/local_storage_service.dart` demo data and `lib/models/user_model.dart`.

## Key Files
- **Entry point**: `lib/main.dart` → `WintechAgroApp`
- **Role routing**: `lib/home_shell.dart`
- **Theme**: `lib/config/theme.dart`
- **User model**: `lib/models/user_model.dart`
- **Storage/demo data**: `lib/services/local_storage_service.dart`
- **Screens**: `lib/screens/` (by role)

## Running Locally
```bash
flutter pub get
flutter run        # Android/iOS device or emulator
flutter build apk --release
```

## User Preferences
- Bengali UI throughout (Hind Siliguri font)
- App is developed locally (VS Code / Android Studio), not run on Replit
- Keep existing Flutter project structure
- Do not rename or restructure packages without explicit request
