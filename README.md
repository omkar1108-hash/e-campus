# E-Campus – Flutter College Management App

Capstone project for Mobile Computing (MCA, AIMTR). One app for students,
class representatives, teachers and administrators.

## Features

| Feature | Details |
|---|---|
| Email login | Firebase email + password. Accounts are **created by administrators** (no self sign-up). The new person gets a verification email and a "set your password" email |
| Seven roles | `student`, `classRep`, `teacher`, `libraryStaff`, `busDriver`, `adminStaff`, `admin`. Rules live in `lib/utils/rbac.dart` and are enforced server-side in `firestore.rules` |
| Role-aware drawer | Menu entries are generated from the user's role |
| Account management | Admin / admin staff create, edit and **disable** accounts (Manage Users). Disabled people cannot sign in |
| Class representatives | Teachers pick them for their own department: at most 2 girls and 2 boys |
| E-Library | Search, read/download books (link-based); teachers, library staff, admin staff and admin add and remove books |
| Bus tracking | Several buses, each with a driver and the departments allowed to track it. Drivers **start / end a trip** and share their phone's GPS. Google Maps on Android / iOS, OpenStreetMap map on Windows, macOS, Linux and web |
| Manage buses | Admin / admin staff add buses, assign a driver and choose the departments that can track each bus |
| Chat | One-to-one, real time. **Edit** (15 min), **delete for everyone**, **pin** messages; **unread dots** and a drawer badge; a **banner** when a message arrives while the app is open (no push notifications while it is closed - that needs a paid Firebase plan); **department filter** on the people list; links in messages are clickable |
| AI chatbot | Doubt-clearing assistant using the Google Gemini API |
| Tech news | Class reps / teachers / admin staff / admin post; everyone but drivers reads their own department's news |

### Permission matrix

| Capability | Student | Class Rep | Teacher | Library staff | Bus driver | Admin staff | Admin |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Chat | all students + teachers of own dept | same | students of own dept + all staff | staff only | staff only | staff only | staff only |
| Library, chatbot, read news | ✔ | ✔ | ✔ | ✔ | | ✔ | ✔ |
| Post news (own department) | | ✔ | ✔ | | | ✔ | ✔ (any) |
| Delete news | | own dept | own dept | | | any | any |
| Add / remove books | | | ✔ | ✔ | | ✔ | ✔ |
| Start / end a bus trip (share location) | | | | | ✔ (own bus) | | |
| Track buses | own dept | own dept | all | all | own bus | all | all |
| Add buses, assign drivers / departments | | | | | | ✔ | ✔ |
| Choose class reps (own dept) | | | ✔ | | | | |
| Create / edit / disable accounts | | | | | | all but admins | all but self |
| Create accounts of role | | | | | | library, teacher, student, driver | any except class rep |

## Run it right now (demo mode)

No setup is needed. If Firebase is not configured the app falls back to an
in-memory backend with seeded data (a driver can start a simulated trip):

```bash
flutter pub get
flutter run
```

Demo accounts (password `demo1234`): `admin@`, `staff@`, `library@`,
`teacher@`, `rep@`, `student@`, `student2@`, `student3@`, `driver@`
`ecampus.demo`. Accounts created inside the demo are active immediately.

## Production setup (Firebase, Maps, Gemini)

1. **Firebase** - create a project, enable *Authentication -> Email/Password*
   and create a *Cloud Firestore* database. Run
   `dart pub global run flutterfire_cli:flutterfire configure` to generate
   `lib/firebase_options.dart` (required to build; commit it).
   - Publish `firestore.rules` (Firestore -> Rules).
   - **First admin:** there is no self sign-up, so create the very first
     administrator by hand: in *Authentication -> Users* add a user, then in
     *Firestore -> users* create a document named with that user's UID and the
     fields `email`, `name`, `department` (strings), `role` = `admin` and
     `active` = `true` (boolean). Everyone else is created from the app
     (*Manage Users -> Create account*).
2. **Google Maps** – enable *Maps SDK for Android*, then put the key in
   `android/local.properties`:
   `MAPS_API_KEY=your_key`
3. **Gemini chatbot** - get a free key at Google AI Studio and run with
   `flutter run --dart-define=GEMINI_API_KEY=AIza... [--dart-define=GEMINI_MODEL=gemini-3.8-flash]`

## Project structure

```
lib/
  main.dart                 Picks Firebase or demo backend
  app.dart                  Providers, theme, auth gate
  config/app_config.dart    Departments, Gemini settings
  models/                   AppUser (+roles), Book, NewsItem, ChatMessage, Bus
  services/
    backend.dart            Data-source interface
    firebase_backend.dart   Firebase Auth + Firestore implementation
    demo_backend.dart       In-memory implementation
    auth_controller.dart    Sign-in / sign-up state
    chatbot_service.dart    Gemini API client
  screens/                  login, otp, register, home (drawer), dashboard,
                            library, bus (+ manage buses), people, chat, chatbot, news, manage users
  utils/rbac.dart           Permission rules
firestore.rules             Server-side RBAC
firestore_tests/            Rules tests (Firebase emulator): `cd firestore_tests && npm install && npm test`
test/                       RBAC, backend and widget-flow tests
```

## Tests

```bash
flutter analyze
flutter test
```
