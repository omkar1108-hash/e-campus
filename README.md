# E-Campus – Flutter College Management App

Capstone project for Mobile Computing (MCA, AIMTR). One app for students,
class representatives, teachers and administrators.

## Features

| Feature | Details |
|---|---|
| Email login & registration | Firebase email + password with a verification link; sign-up collects name and department |
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

Demo accounts (password `demo1234`): `admin@ecampus.demo`,
`teacher@ecampus.demo`, `rep@ecampus.demo`, `student@ecampus.demo`. New
sign-ups in demo mode are created as students and are usable immediately.

## Production setup (Firebase, Maps, ChatGPT)

1. **Firebase** - create a project, enable *Authentication -> Email/Password*
   and create a *Cloud Firestore* database. Run
   `dart pub global run flutterfire_cli:flutterfire configure` to generate
   `lib/firebase_options.dart` (required to build; commit it).
   - Publish `firestore.rules` (Firestore -> Rules).
   - **First admin:** register once in the app and verify the email, then in the
     Firestore console set that user's `users/<uid>.role` to `admin`. Admins can
     then promote others from *Manage Users*.
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
