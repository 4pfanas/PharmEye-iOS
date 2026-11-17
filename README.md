# PharmEye

**Every medicine, explained plainly.**

PharmEye is an iOS app that keeps track of every medicine you take: what it is, when to take it, whether you took it, and whether it's safe with everything else in your cabinet. Your cabinet and health details stay on your iPhone, reminders work offline, and you don't need an account to use it.

Built with SwiftUI for iOS 26.

---

## Contents

- [Features](#features)
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Optional setup](#optional-setup)
- [Project structure](#project-structure)
- [Architecture](#architecture)
- [Privacy](#privacy)
- [Accessibility](#accessibility)
- [Design](#design)
- [Contributing](#contributing)
- [Security](#security)
- [Medical disclaimer](#medical-disclaimer)
- [License](#license)

---

## Features

### Medicine cabinet
- **Add a medicine by hand:** name, strength, amount per dose, how often (once, twice, three times daily or as needed), reminder times and repeat days.
- **Cabinet overview:** every medicine as a card with a status stripe, reminder times and a badge (Active, Due soon, Missed, Course done, doses left), plus a count of how many need attention today.
- **Medicine details:** what it treats, how to take it, common side effects, course progress (for example "day 3 of 7"), doses per day and doses left.
- **Search:** find a medicine by name, ingredient, category or what it treats, or start a symptom check from what you typed.

### Daily dose tracking
- **Next-dose card** on Home with a live countdown, the time, the amount, the instruction (for example "after food") and one-tap **Mark Taken**.
- **Pinned medicines:** tap any medicine to show its dose in the card. As-needed medicines get **Log a dose** instead.
- **"Doses left today"** headline that counts down as you log doses.
- **Missed-dose rules:** each dose counts as on time from 30 minutes before to 60 minutes after its scheduled time. After that it's marked missed and can still be logged late. As-needed medicines are never marked missed, and the app never suggests doubling a dose.
- **Daily reset:** yesterday's logs clear and reminders move onto today automatically.
- **Running-low alerts** when about five doses are left.

### Reminders & alerts
- **Offline reminders:** scheduled on the device with `UserNotifications` the moment a medicine is saved, so they fire without internet and with the app closed.
- **Notifications screen** with two tabs. **Alerts** shows due now, missed, running low and taken today, with Mark Taken, Snooze 15 min and Log it late actions. **Reminders** lists every scheduled time, each with an on/off switch, plus a master switch.

### Dynamic Island & Lock Screen
- A **Live Activity** shows the next dose as a countdown in the Dynamic Island and on the Lock Screen.
- **Mark Taken** works straight from the expanded Island or the Lock Screen card, using a `LiveActivityIntent`.

### Siri & Shortcuts
Built with App Intents, and also available in the Shortcuts app:

| Say | What happens |
| --- | --- |
| "Log my Metformin in PharmEye" | Logs the next dose and says how many are left today |
| "What's my next dose in PharmEye" | Names the medicine, amount and time |
| "Did I take my Augmentin in PharmEye" | Says how many of today's doses are logged |

### Safety checks
- **Allergy warnings** based on the allergies in your profile, shown separately from interaction warnings.
- **Cabinet interaction check:** each medicine is checked against the rest of your cabinet with a built-in rule set.
- When nothing conflicts, the app says so ("No conflicts found…") instead of showing nothing.
- Allergies are asked for after the first scan rather than at sign-up.

### Symptom check (bring your own AI key)
- Describe how you feel or tap symptom chips, and get 2–4 possible causes with a match percentage, a label (Most likely, Possible, Less likely, Needs a test, See a doctor) and a short explanation.
- Red-flag symptoms show a **Get help now** banner.
- Works with **Gemini, Claude or OpenAI** using the user's own key, stored in the iOS Keychain. Only the typed symptoms are sent, never the cabinet or profile.
- Always presented as "not a diagnosis".

### Health profile
- Conditions and allergies, a care team with one-tap calling, personal details, and today's stats (medicines, taken today, active reminders).

### Accounts (optional)
- **Sign in with Apple** (including Hide My Email), **Google**, or **email and password** with password reset, using Supabase Auth.
- Every feature works without an account.

### Privacy & security controls
- **Face ID / passcode lock** when the app opens.
- **Export** all data as a JSON file, or **delete everything** after a confirmation.

---

## How it works

```
                    ┌──────────────────────────┐
  SwiftUI screens ─▶│       CabinetStore        │◀─ Siri / Shortcuts (App Intents)
                    │ (single source of truth)  │◀─ Live Activity "Mark Taken"
                    └────────────┬─────────────┘
                                 │ save()
          ┌──────────────────────┼───────────────────────┐
          ▼                      ▼                       ▼
  cabinet.json (on device)  ReminderScheduler      DoseLiveActivity
                            (local notifications)  (Dynamic Island)
```

Everything that changes a dose goes through `CabinetStore`, so Home, Notifications, Siri and the Dynamic Island always agree.

---

## Requirements

- macOS with **Xcode 26.1** or later
- **iOS 26.1** or later (simulator or device)
- An Apple ID added to Xcode for signing. Sign in with Apple on a real device needs a paid Apple Developer Program membership.

There are no third-party Swift packages. The networking for auth and the symptom check uses `URLSession`.

---

## Getting started

```bash
git clone https://github.com/<your-account>/PharmEye-iOS.git
```

```bash
cd PharmEye-iOS && open PharmEye.xcodeproj
```

1. In Xcode, select the **PharmEye** project, then for both the **PharmEye** and **PharmEyeWidget** targets open **Signing & Capabilities** and choose your **Team**.
2. If you're building to a device, change the bundle identifiers to ones you own (for example `com.yourname.PharmEye` and `com.yourname.PharmEye.PharmEyeWidget`). The widget's ID must start with the app's ID.
3. Pick an iPhone simulator and press **⌘R**.

Debug builds start with a small demo cabinet on first launch so every screen has something to show. Release builds start empty.

---

## Optional setup

The app runs without any of this. Each item turns on one extra feature.

### Accounts (Supabase)

1. Create a project at [supabase.com](https://supabase.com).
2. Copy the example config and fill it in:

   ```bash
   cp Config/Supabase.example.plist PharmEye/Supabase.plist
   ```

   Set `SupabaseURL` (for example `https://abcdefgh.supabase.co`) and `SupabaseAnonKey`. Use the **publishable** (`sb_publishable_…`) or legacy **anon** key, from Project Settings → API Keys.
   > `PharmEye/Supabase.plist` is git-ignored. Never commit it, and never use the service-role / secret key in the app.
3. In the Supabase dashboard:
   - **Authentication → Providers → Email:** enable it. "Confirm email" can be on or off; the app handles both.
   - **Authentication → Providers → Apple:** enable it and add your app's bundle ID under **Client IDs**.
   - **Authentication → Providers → Google:** enable it with a **Web application** OAuth client ID and secret from Google Cloud Console. The Google client's authorized redirect URI is `https://<your-project-ref>.supabase.co/auth/v1/callback`.
   - **Authentication → URL Configuration → Redirect URLs:** add `pharmeye://auth-callback`.

Until `Supabase.plist` is present, the sign-in buttons are disabled and the app explains why.

### Symptom check

Nothing to configure in code. Each user adds their own key in the app under **Profile → AI provider key**. It's stored in the iOS Keychain.

### Live Activities

Users can switch them on or off in iOS **Settings → PharmEye → Live Activities**. A countdown starts when the app is opened with a dose due within the next 8 hours.

---

## Project structure

```
PharmEye-iOS/
├── PharmEye/                    # App target (folder-synced in Xcode)
│   ├── PharmEye.swift           # @main app entry, font registration, app lock, day rollover
│   ├── CabinetStore.swift       # Data store: medicines, doses, profile, export/delete
│   ├── Models/
│   │   ├── Medicine.swift       # Medicine, ReminderTime, CareContact, DoseStatus, demo data
│   │   └── MissedDoseEngine.swift  # Grace-window and missed-dose rules (pure functions)
│   ├── Screens/                 # SwiftUI screens (Home, Cabinet, Detail, Notifications,
│   │   ├── Onboarding/          #   Symptoms, Search, Add medicine, Profile…)
│   │   └── Profile/             # Profile sub-pages, account, legal, licences, Siri
│   ├── Components/              # Medicine cards and rows
│   ├── Services/
│   │   ├── ReminderScheduler.swift   # Local notification scheduling
│   │   ├── SymptomAI.swift           # Gemini / Claude / OpenAI symptom check
│   │   ├── Keychain.swift            # Keychain wrapper
│   │   └── Auth/                     # Supabase Auth over REST (Apple, Google, email)
│   ├── Intents/                 # Siri & Shortcuts (App Intents)
│   ├── LiveActivity/            # Starts/updates/ends the dose Live Activity
│   ├── Theme/Theme.swift        # Design tokens, hand-drawn shapes, buttons, badges
│   └── Fonts/                   # Poppins + Lora (SIL OFL 1.1)
├── PharmEyeWidget/              # Widget extension: Dynamic Island + Lock Screen UI
├── Shared/                      # Code compiled into both targets (activity model, Mark Taken intent)
├── Config/Supabase.example.plist
├── PharmEye.entitlements        # Sign in with Apple
├── PharmEyeWidget-Info.plist
├── LICENSE
└── SECURITY.md
```

---

## Architecture

| Piece | What it does |
| --- | --- |
| `CabinetStore` | `@MainActor` `ObservableObject` shared by the UI, App Intents and the Live Activity (`CabinetStore.shared`). Saves to `Documents/cabinet.json`. Every `save()` refreshes the Live Activity. |
| `MissedDoseEngine` | Pure functions for dose status: `.dueSoon` inside the −30/+60 minute window, `.missed` after it, as-needed medicines exempt. |
| `ReminderScheduler` | One repeating `UNCalendarNotificationTrigger` per reminder (daily, or weekly per chosen day), rebuilt whenever a medicine changes. |
| `DoseLiveActivity` | Starts, updates or ends a single `Activity<DoseActivityAttributes>` for the next upcoming dose. |
| `PharmEyeWidget` | `ActivityConfiguration` with compact, minimal and expanded Dynamic Island layouts and a Lock Screen view. |
| `MarkDoseTakenIntent` | `LiveActivityIntent` in `Shared/`. It runs in the app process; the widget build only draws the button (`WIDGET_EXTENSION` compilation flag). |
| `PharmEyeIntents` | `LogDoseIntent`, `NextDoseIntent`, `CheckTakenIntent`, a `MedicineEntity` with search, and an `AppShortcutsProvider`. |
| `AuthStore` | Supabase Auth via REST: email sign-up/sign-in/reset, Sign in with Apple (nonce + ID token exchange), Google via `ASWebAuthenticationSession`. The session is stored in the Keychain and refreshed when the app becomes active. |
| `SymptomAI` | Sends the symptom text to the chosen provider and decodes a fixed JSON shape (causes, match %, label, urgency). Uses structured output on Claude and JSON mode on Gemini and OpenAI. |
| `Theme` | Colour tokens for light (paper) and dark (night) modes, Poppins/Lora type, a wobbly hand-drawn `PESketchRect` shape, paper grain, and shared button/badge styles. |

The project uses Swift's `MainActor` default isolation and approachable concurrency. Types used off the main actor are marked `nonisolated`.

---

## Privacy

- **On device:** the medicine cabinet, schedule, dose history, allergies, conditions and care team are stored only in the app's container on the iPhone.
- **No analytics or tracking.**
- **Accounts are optional.** When used, the sign-in provider (Supabase) stores the account's email and a sign-in record.
- **Symptom check:** only the symptoms the user types are sent, and only to the AI provider they chose, using their own key.
- **Keychain** stores the sign-in session and the AI key. They are never written to `UserDefaults` or included in exports.
- **Users control their data:** export as JSON or delete everything from inside the app.

---

## Accessibility

- **VoiceOver:** icon buttons have spoken names, medicine and result cards are read as single elements, screen titles are headings, toggle chips report "selected", and day pickers read full day names.
- **Dynamic Type:** text scales with the system text-size setting.
- **Contrast:** text colours meet WCAG AA on their backgrounds in both themes, and status is shown with words and icons as well as colour.
- **Light and dark themes** follow the system setting.

---

## Design

A calm, hand-drawn paper look: maroon, cream and gold, flat fills with slightly wobbly ink outlines, a faint paper grain, **Poppins** for headings and interface text, and **Lora** for friendlier explanatory text. All colours and type live in `Theme/Theme.swift`.

---

## Contributing

Issues and pull requests are welcome.

1. Fork the repo and create a branch.
2. Keep to the existing style: SwiftUI, tokens from `Theme.swift`, no hard-coded colours, and accessibility labels on new controls.
3. Make sure both targets build (`PharmEye` and `PharmEyeWidget`).
4. Don't commit secrets, `Supabase.plist`, signing files or personal data.

---

## Security

Please report vulnerabilities privately. See [SECURITY.md](SECURITY.md).

---

## Medical disclaimer

PharmEye is an informational tool. It does not diagnose, treat or prevent any condition, and it does not replace advice from a doctor or pharmacist. Interaction and allergy warnings are not exhaustive, and the symptom check gives rough matches, not a diagnosis. In an emergency, call your local emergency number (998 in the UAE).

---

## License

PharmEye is free software released under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).

Copyright © 2026 Anas Aslam.

The bundled **Poppins** and **Lora** typefaces are licensed under the **SIL Open Font License 1.1** (`PharmEye/Fonts/OFL-*.txt`).
