# Green Spoon 🥄

> Vorrat scannen, klug kochen.

**Green Spoon** ist eine Flutter-App, die Lebensmittel nach dem Einkauf per
Barcode + MHD-Texterkennung erfasst, sie in Supabase verwaltet und bei
drohendem Ablauf KI-generierte Rezepte vorschlägt – damit weniger im Müll
landet. Inklusive CO₂-Bilanz, lokalen Ablauf-Erinnerungen und Dark/Light-Theme.

---

## Features

- **Vorrat (Pantry)** – Lebensmittel anlegen, bearbeiten, nach Ablaufdatum
  sortiert; Warnung bei bald ablaufenden Produkten.
- **Scanner** – Barcode-Scan (mobile_scanner) + MHD-OCR (ML Kit) mit
  Produktabgleich über Open Food Facts.
- **KI-Rezepte** – Vorschläge passend zum aktuellen Vorrat, generiert über
  eine Supabase Edge Function (API-Key bleibt serverseitig).
- **Erinnerungen** – lokale Push-Benachrichtigungen, bevor etwas verdirbt.
- **CO₂-Bilanz** – geschätzte Einsparung & anschauliche Äquivalente, plus
  persönliche Statistiken.
- **Profil & Auth** – Email/Passwort-Login, Registrierung, In-App-Passwort-
  Reset per Code, lokal wählbares Profilbild.
- **Onboarding**, **Dark/Light-Mode**, Schriften Fraunces + Inter.

---

## Tech-Stack

| Bereich          | Technologie                                  |
|------------------|----------------------------------------------|
| Framework        | Flutter (Dart SDK ^3.5)                       |
| State-Management | Riverpod                                      |
| Navigation       | go_router (mit Auth-Guard)                    |
| Backend          | Supabase (Auth, Postgres, Edge Functions)     |
| Scanning         | mobile_scanner, google_mlkit_text_recognition |
| Notifications    | flutter_local_notifications, timezone         |

App-ID (Android): `de.greenspoon.app`

---

## Setup

### 1. Voraussetzungen

- Flutter SDK 3.27+ ([install](https://docs.flutter.dev/get-started/install))
- Android Studio / Android-SDK (API 21+)
- Ein (kostenloses) Supabase-Konto

### 2. Supabase-Projekt anlegen

1. Auf [supabase.com](https://supabase.com) ein Projekt erstellen (Region: EU).
2. Unter **Settings → API** kopieren:
   - **Project URL**
   - **anon / public key**

### 3. `.env` anlegen

Datei `.env` im Projekt-Root:

```env
SUPABASE_URL=https://dein-projekt.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

> Der `anon`-Key darf öffentlich in die App – die Daten schützt Row Level
> Security. KI-/Drittanbieter-Keys liegen **niemals** in der App, sondern als
> Secret in den Supabase Edge Functions (`supabase/functions/`).

### 4. Auth konfigurieren

Unter **Authentication → Providers** **Email** aktivieren. Für den
Passwort-Reset per Code muss die Reset-Email-Vorlage den Platzhalter
`{{ .Token }}` enthalten.

### 5. Starten

```bash
flutter pub get
flutter run
```

---

## Projektstruktur

```
lib/
├── main.dart            Init: dotenv, Supabase, ProviderScope
├── app.dart             MaterialApp.router + Theme
├── core/                Theme, Router, Supabase-Client, Widgets, Utils
└── features/
    ├── auth/            Login, Signup, Passwort-Reset
    ├── onboarding/
    ├── pantry/          Vorrat-CRUD + Screens
    ├── scanner/         Barcode + MHD-OCR
    ├── recipes/         KI-Rezepte (Edge Function)
    ├── notifications/   lokale Ablauf-Erinnerungen
    ├── profile/         Profil, CO₂-Statistiken
    ├── settings/
    └── main_shell.dart  Bottom-Navigation

supabase/
└── functions/
    ├── generate-recipes/   KI-Rezeptgenerierung
    └── scan-groceries/     Produktabgleich
```

---

## Tests

```bash
flutter test
```

Unit-Tests u.a. für CO₂-Schätzung, CO₂-Äquivalente und Nutzer-Statistiken.

---

*Studienprojekt · Flutter + Supabase*
