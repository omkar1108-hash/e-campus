# E-Campus – Flutter College Management App

Capstone project for Mobile Computing (MCA, AIMTR). One app for students,
class representatives, teachers and administrators.

## Features

| Feature | Details |
|---|---|
| Email login | Firebase email + password. Accounts are **created by administrators** (no self sign-up). The new person gets a verification email and a "set your password" email |
| Nine roles | `student`, `classRep`, `teacher`, `hod` (head of department: a teacher who also picks class representatives), `libraryStaff`, `busDriver`, `adminStaff`, `grievanceCommittee`, `admin`. Rules live in `lib/utils/rbac.dart` and are enforced server-side in `firestore.rules` |
| Role-aware drawer | Menu entries are generated from the user's role |
| Account management | Admin / admin staff create, edit and **disable** accounts (Manage Users). Disabled people cannot sign in |
| Class representatives | Only the **head of department** picks them for their own department: at most 2 girls and 2 boys (4 per department) |
| E-Library | Search, read/download books (link-based) with **cover pictures** (picked from the gallery, or fetched from the ISBN via Open Library). Teachers' books go to a **verification queue**: library staff approve, or reject with a reason; the teacher sees the reason, fixes the book and resubmits. Library staff, admin staff and admin add books without approval |
| Bus tracking | Several buses, each with a driver and the departments allowed to track it. Drivers **start / end a trip** and share their phone's GPS. Google Maps on Android / iOS, OpenStreetMap map on Windows, macOS, Linux and web |
| Manage buses | Admin / admin staff add buses, assign a driver, choose the departments that can track each bus and set the **route**: a start and an end point (name + coordinates, picked on a map or typed) |
| Bus routes | Students, staff and the driver see the route on the map, its distance and travel time (road routing from OpenStreetMap data via the free OSRM server; a straight-line estimate is shown if it cannot be reached) and, while the bus runs, the time left to the next stop. When the driver's phone reaches the end point the bus **turns back automatically** to the start, and again at the start |
| Chat | One-to-one, real time. **Edit** (15 min), **delete for everyone**, **pin** messages; **unread dots** and a drawer badge; a **banner** when a message arrives while the app is open (no push notifications while it is closed - that needs a paid Firebase plan); **department filter** on the people list; links in messages are clickable |
| AI chatbot | Doubt-clearing assistant using the Google Gemini API |
| Tech news | Class reps / teachers / admin staff / admin post, optionally with a **poster picture** from the gallery; everyone but drivers reads their own department's news |
| Opening page | The screen before sign-in: college name and contacts (`lib/config/app_config.dart`), the sign-in form, what the app offers and any **public notices**. Two columns on desktop |
| Dashboard | Live cards per role: unread messages, notices, today's classes, assignments due, attendance %, books to verify, bus status, account counts, new complaints, activity... Each card opens its section |
| Notices | Announcements by admin / admin staff, optionally with a poster. Choose the **audience**: which branches (or all) and which groups (students, teachers, other staff, bus drivers, or everyone). Notices for everybody can also be **public** (shown on the opening page). Students and class reps cannot post |
| Timetable | One weekly timetable per department, **edited only by that department's head of department** (appointed by the administrator) and visible to the department's students and teachers (admin and admin staff can look at every department, read only). Teachers also get **My classes** |
| Attendance | Teachers mark a lecture (department, subject, date) and can correct it later; students see their percentage per subject and overall, with a warning under 75% |
| Assignments & notes | Teachers share assignments (with due date) and notes as **links** (Drive, OneDrive...); students see their department's items |
| Complaints | Anyone except the committee files a complaint (category, subject, details), **optionally anonymous**. Only the filer, the **Grievance Committee**, admin staff and admin can see it. The committee moves it *Sent -> Working on it -> Resolved*; the **person who filed it then confirms** (*Closed*) or sends it back (*Working on it* again). The committee may also reject it. The **administrator** (only) can see who filed an anonymous complaint |
| Role badges | Coloured role label next to every name in the chat list and chat header |
| Search | One search box across e-library books, department news and notices |
| Activity log | Admin only: who created, edited, disabled or re-enabled accounts, who deleted or reviewed books, deleted news / notices / buses, changed a complaint's status, sent or cleared an alert |
| Emergency alert | The administrator sends a message to the chosen branches and groups (drivers included if chosen); they get a red banner and a one-time pop-up. In-app only, no push notification. Students and class reps cannot send alerts |

### Permission matrix

| Capability | Student | Class Rep | Teacher | Library staff | Bus driver | Admin staff | Admin |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Chat | all students + teachers of own dept | same | students of own dept + all staff | staff only | staff only | staff only | staff only |
| Library, chatbot, read news | ✔ | ✔ | ✔ | ✔ | | ✔ | ✔ |
| Post news (own department) | | ✔ | ✔ | | | ✔ | ✔ (any) |
| Delete news | | own dept | own dept | | | any | any |
| Add books | | | ✔ (needs verification) | ✔ | | ✔ | ✔ |
| Verify (approve / reject) teachers' books | | | | ✔ | | | |
| Delete books | | | own | any | | any | any |
| Start / end a bus trip (share location) | | | | | ✔ (own bus) | | |
| Track buses | own dept | own dept | all | all | own bus | all | all |
| Add buses, assign drivers / departments | | | | | | ✔ | ✔ |
| Choose class reps (own dept) | | | | | | | |
| (head of department only) | | | `hod` | | | | |
| Create / edit / disable accounts | | | | | | all but admins | all but self |
| Create accounts of role | | | | | | committee, library, teacher, student, driver (not HOD) | any except class rep |
| Notices: read (those aimed at you) | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Notices: post / delete | | | | | | ✔ | ✔ |
| Timetable: view (own department) | ✔ | ✔ | ✔ | | | ✔ (all) | ✔ (all) |
| Timetable: edit (own department) | | | `hod` | | | | |
| Appoint / remove a head of department | | | | | | | ✔ |
| Mark attendance / post assignments (admin and staff do not see assignments) | | | ✔ | | | | |
| See own attendance | ✔ | ✔ | | | | | |
| File a complaint | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Read all complaints | | | | | | ✔ (read) | ✔ (read) |
| Grievance Committee: all complaints, reply, change status | (committee role) | | | | | | |
| See who filed an anonymous complaint | | | | | | | ✔ |
| Search | ✔ | ✔ | ✔ | ✔ | | ✔ | ✔ |
| Send emergency alert, read the activity log | | | | | | | ✔ |

## Run it right now (demo mode)

No setup is needed. If Firebase is not configured the app falls back to an
in-memory backend with seeded data (a driver can start a simulated trip):

```bash
flutter pub get
flutter run
```

Demo accounts (password `demo1234`): `admin@`, `staff@`, `library@`,
`teacher@`, `rep@`, `student@`, `student2@`, `student3@`, `driver@`,
`committee@` `ecampus.demo` (`meena@` is an MBA student, `iyer@` an MBA teacher). Accounts created inside the demo are active immediately.

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
     (*Manage Users -> Create account*). Create one person with the role
     **Grievance Committee** to handle complaints.
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
  models/                   AppUser (+roles), Book, NewsItem, ChatMessage, Bus,
                            campus.dart (notices, alerts, timetable, assignments,
                            attendance, complaints, activity log)
  services/
    backend.dart            Data-source interface
    firebase_backend.dart   Firebase Auth + Firestore implementation
    demo_backend.dart       In-memory implementation
    auth_controller.dart    Sign-in / sign-up state
    chatbot_service.dart    Gemini API client
  screens/                  login, otp, register, home (drawer), dashboard,
                            library, bus (+ manage buses), people, chat, chatbot, news, manage users,
                            notices, timetable, attendance, assignments, complaints,
                            search, alert, activity log
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

## Pictures

News posters and book covers are shrunk on the phone (max 800 px, JPEG,
usually 50-250 KB) and stored inside the Firestore document itself, so no
paid Firebase Storage is needed. Firestore documents are limited to 1 MB, so
very detailed pictures are refused with a message. Books added before the
approval flow existed need a one-time **"Approve books added before this
update"** (Library -> the menu next to the search box, as library staff, admin
staff or admin).

## Limits you should know about

- **Activity log** entries are written by the app on the person's behalf and
  the rules only check that someone logs as themselves, so it is a convenient
  record rather than tamper-proof evidence. A tamper-proof log needs Cloud
  Functions (paid Blaze plan).
- **Anonymous complaints** are kept anonymous from the committee by storing
  the filer's identity in a separate collection (`complaintIdentities`) that
  only the filer and the administrator can read. The administrator can always
  see who filed it - say so to students (the app does).
- **Attendance**: the rules make sure only teachers write records and that
  they are marked as that teacher, but they cannot check that a student really
  belongs to that teacher's class (Firestore rules can read only a few
  documents per request).
- **Emergency alerts** and chat banners appear only while the app is open;
  there are no push notifications on the free plan.
- The college address, phone and email on the opening page are placeholders.
- **Bus route times** come from the free public OSRM server, which has no
  guarantee of availability; without it the app shows a straight-line
  estimate (30 km/h, +30% detour) and says so. The automatic turn-back runs on
  the driver's phone, so it only works while the driver's app is open.
