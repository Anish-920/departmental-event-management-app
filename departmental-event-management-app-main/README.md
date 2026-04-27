# 🎓 Departmental Event Management App

A Flutter-based mobile application for managing departmental events, with role-based dashboards for **Admins**, **Organizers**, **Teachers**, and **Participants**. Built with Firebase (Firestore + Auth) as the backend.

---

## 📱 Features

| Role | Capabilities |
|------|-------------|
| **Admin** | Manage users, approve organizers, oversee all events |
| **Organizer** | Create & manage events, generate QR codes, view attendance |
| **Teacher** | Monitor attendance, generate class reports |
| **Participant** | Register for events, scan QR codes for check-in/check-out |

---

## 🚀 Getting Started — Run on Your Device

### Prerequisites

Make sure you have the following installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.0+)
- [Android Studio](https://developer.android.com/studio) OR [VS Code](https://code.visualstudio.com/) with Flutter extension
- A physical Android device **or** Android Emulator

---

### Step 1 — Clone the Repository

```bash
git clone https://github.com/Anish-920/departmental-event-management-app.git
cd departmental-event-management-app/departmental-event-management-app-main
```

---

### Step 2 — Install Dependencies

```bash
flutter pub get
```

---

### Step 3 — Connect a Device

**Option A — Physical Android Device:**
1. Enable **Developer Options** on your Android phone
2. Enable **USB Debugging**
3. Connect phone via USB
4. Run `flutter devices` to confirm it's detected

**Option B — Android Emulator:**
1. Open Android Studio → Device Manager
2. Create & start a virtual device (API 30+)

---

### Step 4 — Run the App

```bash
flutter run
```

> The app will automatically connect to the shared Firebase project — no extra configuration needed.

---

## 🏗️ Project Structure

```
lib/
├── main.dart                   # App entry point + Firebase init
├── firebase_options.dart       # Firebase configuration
├── models/
│   ├── event_model.dart
│   ├── user_model.dart
│   └── timetable_model.dart
├── screens/
│   ├── login_screen.dart       # Login & Registration
│   ├── dashboard_screen.dart   # Role router
│   ├── admin_dashboard.dart
│   ├── organizer_dashboard.dart
│   ├── teacher_dashboard.dart
│   ├── participant_dashboard.dart
│   ├── qr_generator_screen.dart
│   ├── qr_scanner_screen.dart
│   ├── report_screen.dart
│   └── admin_timetable_screen.dart
└── services/
    ├── auth_service.dart       # Firebase Auth
    └── firestore_service.dart  # Firestore operations
```

---

## 🔥 Firebase Backend

This app uses a **shared Firebase project**. The config files (`google-services.json` and `firebase_options.dart`) are already included in the repo — teammates do **not** need to set up Firebase separately.

### Firestore Collections:
- `users` — User profiles with roles
- `events` — Event data
- `attendance` — QR scan check-in/out logs
- `timetables` — Class timetable data

---

## 🧪 Test Accounts

Contact the project admin (Anish-920) to get test login credentials for each role, or register a new account in the app and ask the Admin to approve your role.

---

## 🛠️ Troubleshooting

| Issue | Fix |
|-------|-----|
| `flutter pub get` fails | Run `flutter clean` then `flutter pub get` |
| Build fails on Android | Make sure `minSdkVersion` is 21+ in `android/app/build.gradle` |
| Firebase connection error | Check your internet connection |
| QR scanner not working | Grant Camera permission in device settings |
| Emulator too slow | Use a physical device or increase emulator RAM |

---

## 📦 Tech Stack

- **Framework:** Flutter (Dart)
- **Backend:** Firebase (Firestore + Authentication)
- **QR Code:** `mobile_scanner` package
- **PDF Reports:** `pdf` + `printing` packages
- **State:** `setState` + Streams

---

## 👥 Team

- **Repository:** [Anish-920/departmental-event-management-app](https://github.com/Anish-920/departmental-event-management-app)
