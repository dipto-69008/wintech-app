# ORIENT ERP — এন্টারপ্রাইজ রিসোর্স ম্যানেজমেন্ট সিস্টেম

## Project Overview
A Flutter-based ERP mobile application for Bengali-speaking users. Three distinct user roles with ERP-focused features including POS order entry, sales analytics, target tracking, and customer credit management.

## Stack
- **Framework**: Flutter (Dart)
- **Package name**: `orient_app`
- **Bundle ID (Android)**: `com.example.orient_erp`
- **Bundle ID (iOS)**: `com.example.orientErp`
- **Storage**: SharedPreferences (local, no backend)
- **Fonts**: Google Fonts — Hind Siliguri (Bengali)
- **Packages**: `google_fonts`, `shared_preferences`, `intl`, `image_picker`, `geolocator`, `video_player`

## User Roles

| Role | Demo Email | Features |
|------|-----------|----------|
| অ্যাডমিন (Admin) | admin@gmail.com | Sales reporting dashboard, SR performance, order analytics |
| এস.আর. (Sales Rep) | sr@orient.com | Dashboard, POS order entry, target/achievement tracking, commissions |
| কাস্টমার (Customer) | customer@gmail.com | Credit limit view, purchase history, monthly purchases |
| সুপার অ্যাডমিন (Super Admin) | superadmin@orient.com | CEO-level analytics view |

**Demo OTP**: `123456` · **Demo Password**: any value

## Key Screens

### Auth
- `lib/screens/auth/login_screen.dart` — Email/password login
- `lib/screens/auth/otp_screen.dart` — OTP verification
- `lib/screens/auth/signup_screen.dart` — Registration
- `lib/screens/onboarding/employee_type_screen.dart` — Role selection after signup

### Admin
- `lib/screens/admin/admin_dashboard_screen.dart` — Sales reporting, SR performance
- `lib/screens/admin/all_employees_screen.dart` — Employee list management

### Employee / SR
- `lib/screens/employee/employee_dashboard_screen.dart` — Today/month stats
- `lib/screens/employee/pos_order_screen.dart` — POS order entry
- `lib/screens/employee/order_list_screen.dart` — Order history with filters
- `lib/screens/employee/target_achievement_screen.dart` — Target setting and tracking

### Customer
- `lib/screens/customer/customer_dashboard_screen.dart` — Credit limit card, purchase history
- `lib/screens/customer/customer_notification_screen.dart` — Notifications
- `lib/screens/customer/customer_settings_screen.dart` — Settings

### Super Admin
- `lib/screens/dashboard/super_admin_dashboard.dart` — CEO analytics view

### Shared Screens
- `lib/screens/commission/commission_screen.dart`
- `lib/screens/withdrawal/withdrawal_screen.dart`
- `lib/screens/target/target_screen.dart`
- `lib/screens/support/support_screen.dart`
- `lib/screens/profile/profile_screen.dart`
- `lib/screens/settings/settings_screen.dart`
- `lib/screens/settings/edit_profile_screen.dart`
- `lib/screens/settings/digital_id_card_screen.dart`
- `lib/screens/follow_up/add_follow_up_screen.dart`
- `lib/screens/follow_up/follow_up_list_screen.dart`
- `lib/screens/notifications/notification_screen.dart`

## Models
- `lib/models/user_model.dart` — UserModel with role, creditLimit, creditUsed, targetAmount, achievedAmount
- `lib/models/order_model.dart` — OrderModel + OrderItem (POS orders)
- `lib/models/lead_model.dart` — Lead tracking
- `lib/models/follow_up_model.dart` — Follow-up entries for leads
- `lib/models/target_model.dart` — Target definitions
- `lib/models/investment_model.dart` — Investment records
- `lib/models/property_model.dart` — Property records
- `lib/models/tutorial_model.dart` — Tutorial content

## Architecture
- **Entry point**: `lib/main.dart` → root widget `OrientErpApp`
- **Role routing**: `lib/home_shell.dart` — checks role and renders correct tab set
  - Admin → admin tabs
  - SR/Employee → employee tabs
  - Customer → customer tabs
  - Super Admin → `SuperAdminDashboard` (CEO analytics)
- **Local storage**: `lib/services/local_storage_service.dart` (SharedPreferences)
- **Theme**: `lib/config/theme.dart` — maroon/gold palette (`primaryAccent = #8A252C`)
- **Widgets**: `lib/widgets/` — reusable `StatCard`, `GradientHeader`, `CustomTextField`, `LeadCard`, `CustomBottomNav`

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
