# E-Campus – Flutter College Management App

Capstone project for Mobile Computing (MCA, AIMTR). One app for students,
class representatives, teachers and administrators.

## Features

| Feature | Details |
|---|---|
| OTP login & registration | Firebase phone authentication; first-time numbers complete a short profile (name, department) |
| Role-Based Access Control | `student`, `classRep`, `teacher`, `admin`. Permission matrix in `lib/utils/rbac.dart`, mirrored server-side in `firestore.rules` |
| Role-aware drawer | Menu entries are generated from the user's role (e.g. *Manage Users* only for admins) |
| E-Library | Search, read/download books (link-based); teachers/admins add and remove books |
| Bus tracking | Live bus marker on Google Maps; admin shares phone GPS as the bus position |
| Chat | One-to-one chat with teachers and friends (Cloud Firestore, real time) |
| AI chatbot | Doubt-clearing assistant using the OpenAI ChatGPT API |
| Tech news | Class reps/teachers/admins post news; students see their own department's news |

### Permission matrix

| Capability | Student | Class Rep | Teacher | Admin |
|---|:-:|:-:|:-:|:-:|
| Library, bus, chat, chatbot, read news | ✔ | ✔ | ✔ | ✔ |
| Post / delete news (own dept) | | ✔ | ✔ | ✔ (any) |
| Add / remove books | | | ✔ | ✔ |
| Publish bus location | | | | ✔ |
| Manage user roles | | | | ✔ |

## Run it right now (demo mode)

No setup is needed. If Firebase is not configured the app falls back to an
in-memory backend with seeded data and a moving simulated bus:

```bash
flutter pub get
flutter run
```

Demo OTP is always **123456**. Accounts: `9000000001` Admin,
`9000000002` Teacher, `9000000003` Class Rep, `9000000004` Student; any other
number registers as a new student.

## Production setup (Firebase, Maps, ChatGPT)

1. **Firebase** – create a project, add an Android app with package
   `com.example.e_campus`, add your SHA-1/SHA-256 debug fingerprints, enable
   *Authentication → Phone* and create a *Cloud Firestore* database. Download
   `google-services.json` into `android/app/` (git-ignored). The Gradle
   plugin is applied automatically once the file exists.
   - Deploy `firestore.rules` (Firebase console → Firestore → Rules).
   - For testing, add a fixed test phone number + code under
     *Authentication → Sign-in method → Phone → Phone numbers for testing*.
   - **First admin:** register once in the app, then in the Firestore console
     set that user's `users/<uid>.role` to `admin`. Admins can then promote
     others from *Manage Users*.
2. **Google Maps** – enable *Maps SDK for Android*, then put the key in
   `android/local.properties`:
   `MAPS_API_KEY=your_key`
3. **ChatGPT** – run with your OpenAI key (never commit it):
   `flutter run --dart-define=OPENAI_API_KEY=sk-... [--dart-define=OPENAI_MODEL=gpt-4o-mini]`

## Project structure

```
lib/
  main.dart                 Picks Firebase or demo backend
  app.dart                  Providers, theme, auth gate
  config/app_config.dart    Departments, OpenAI settings
  models/                   AppUser (+roles), Book, NewsItem, ChatMessage, BusLocation
  services/
    backend.dart            Data-source interface
    firebase_backend.dart   Firebase Auth + Firestore implementation
    demo_backend.dart       In-memory implementation
    auth_controller.dart    Login → OTP → register state machine
    chatbot_service.dart    OpenAI chat completions client
  screens/                  login, otp, register, home (drawer), dashboard,
                            library, bus, people, chat, chatbot, news, users admin
  utils/rbac.dart           Permission rules
firestore.rules             Server-side RBAC
test/                       RBAC, backend and widget-flow tests
```

## Tests

```bash
flutter analyze
flutter test
```
