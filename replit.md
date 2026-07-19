# ORIENT ERP — Flutter Mobile App

## What This Project Is
**ORIENT ERP** is a Flutter (Dart) mobile application for Bengali-speaking business users. It is a role-based ERP system with POS order entry, sales analytics, target tracking, commission management, and customer credit management. The UI is in Bengali (Hind Siliguri font) with a maroon/gold theme.

**This is a Flutter project — it cannot run directly on Replit.** Development and builds happen locally or via CI (e.g. GitHub Actions, Codemagic). On Replit, you can read and edit code; use a local Flutter environment or CI to run/build it.

## Package & Bundle IDs
| Platform | ID |
|----------|----|
| Dart package | `orient_app` |
| Android namespace / applicationId | `com.example.orient_erp` |
| iOS bundle ID | `com.example.orientErp` |

## Tech Stack
- **Framework**: Flutter 3.x / Dart SDK ^3.12.2
- **Storage**: SharedPreferences (fully local, no backend/server)
- **Key packages**: `google_fonts`, `shared_preferences`, `intl`, `image_picker`, `geolocator`, `video_player`
- **App icon**: `assets/images/moon.jpeg`

## User Roles & Demo Credentials

| Role | Demo Email | OTP | Password |
|------|-----------|-----|----------|
| অ্যাডমিন (Admin) | admin@gmail.com | 123456 | any |
| এস.আর. (Sales Rep) | sr@orient.com | 123456 | any |
| কাস্টমার (Customer) | customer@gmail.com | 123456 | any |
| সুপার অ্যাডমিন | superadmin@orient.com | 123456 | any |

## Project Structure

```
lib/
├── main.dart                        # Entry point → OrientErpApp widget
├── home_shell.dart                  # Role-based tab routing
├── config/theme.dart                # AppTheme (maroon #8A252C / gold)
├── models/                          # User, Order, Target, Commission, etc.
├── services/local_storage_service.dart  # SharedPreferences persistence
├── screens/
│   ├── splash_screen.dart
│   ├── auth/                        # login, otp, signup
│   ├── onboarding/                  # employee_type_screen (role picker)
│   ├── admin/                       # admin_dashboard, all_employees
│   ├── employee/                    # dashboard, pos_order, order_list, target_achievement
│   ├── customer/                    # dashboard, notifications, settings
│   ├── dashboard/                   # super_admin_dashboard (CEO view)
│   ├── commission/, withdrawal/, target/, support/
│   ├── notifications/
│   └── settings/                    # profile, edit_profile, settings
└── widgets/                         # StatCard, GradientHeader, CustomTextField, CustomBottomNav
```

## Role Routing (home_shell.dart)
- **Admin** → Admin dashboard + employee management tabs
- **SR/Employee** → Employee dashboard, POS, order list, target tracking tabs
- **Customer** → Customer dashboard, notifications, settings tabs
- **Super Admin** → `SuperAdminDashboard` (CEO analytics, no regular tabs)

## Key Conventions
- All UI strings are in Bengali
- No backend — all data seeded and stored via `LocalStorageService` (SharedPreferences)
- Role is determined at login and stored locally; `home_shell.dart` reads it to route
- Theme colors are defined in `lib/config/theme.dart` — do not hardcode colors in screens
- Widget class name for the root app: `OrientErpApp` (in `lib/main.dart`)

## How to Run (Local Machine)
```bash
flutter pub get
flutter run                  # needs connected Android/iOS device or emulator
flutter build apk --release  # release APK
```

## User Preferences
- Bengali UI throughout — keep Hind Siliguri font, do not switch to English
- Keep existing file and folder structure unless explicitly asked to change it
- This is ORIENT ERP — no references to "Salmon", "Salmon Developer", or old branding anywhere in code, strings, or comments
- Do not add a backend or online database unless the user explicitly requests it
- No team management system, no referral codes, no digital ID card — these features are removed
