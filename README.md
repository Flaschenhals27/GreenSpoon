# Green Spoon

> Vorrat scannen, klug kochen.

Flutter-App, die nach dem Einkauf Lebensmittel via Barcode + MHD-OCR
einscannt, sie in Supabase speichert und bei drohendem Ablauf
KI-generierte Rezepte vorschlägt.

---

## Status

**Phase 1: Fundament — abgeschlossen.**

Enthalten:
- Projektstruktur (feature-first)
- Theme (Light + Dark) mit Fraunces & Inter
- Supabase-Client-Initialisierung
- Auth: Email/Passwort-Login + Registrierung
- Router mit Auth-Guard (go_router)
- Riverpod-Setup
- Platzhalter-Home nach erfolgreichem Login

Folge-Phasen siehe Abschnitt **Roadmap** unten.

---

## Setup

### 1. Voraussetzungen

- Flutter SDK 3.24+ ([install](https://docs.flutter.dev/get-started/install))
- Android Studio mit Android-SDK (API 21+)
- Ein Supabase-Konto (kostenlos)

### 2. Supabase-Projekt anlegen

1. Auf [supabase.com](https://supabase.com) registrieren / anmelden.
2. Neues Projekt erstellen (region: am besten EU).
3. In **Settings → API** die folgenden Werte kopieren:
   - **Project URL**
   - **anon / public key**

### 3. `.env` anlegen

Datei `.env` im Projekt-Root erstellen (Vorlage: `.env.example`):

```env
SUPABASE_URL=https://dein-projekt.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

### 4. Supabase-Auth konfigurieren

In deinem Supabase-Projekt unter **Authentication → Providers**:
- **Email** aktivieren (ist Default).
- Für die Entwicklungsphase empfiehlt sich, **"Confirm email"** unter
  **Authentication → Sign In / Up → Email Auth** **abzuschalten** — sonst
  musst du jeden Test-Account per Email bestätigen.
  Für die Abgabe kannst du es wieder aktivieren.

### 5. Abhängigkeiten installieren & starten

```bash
flutter pub get
flutter run
```

---

## Projektstruktur

```
lib/
├── main.dart                     Init: dotenv, Supabase, ProviderScope
├── app.dart                      MaterialApp.router + Theme
├── core/
│   ├── theme/                    Farben, Typografie, Light+Dark
│   ├── router/                   go_router mit Auth-Guard
│   ├── supabase/                 Supabase-Client-Wrapper
│   ├── widgets/                  (für Phase 2: GSAppBar, ExpiryDot, …)
│   └── utils/
└── features/
    ├── auth/
    │   ├── data/                 AuthRepository (Supabase-Calls)
    │   ├── presentation/         LoginScreen, SignupScreen
    │   └── providers/            Riverpod-Provider
    ├── home_placeholder.dart     wird in Phase 2 ersetzt
    ├── pantry/                   (Phase 2)
    ├── scanner/                  (Phase 3)
    ├── recipes/                  (Phase 4)
    └── profile/                  (Phase 5)
```

---

## Roadmap

| Phase | Inhalt | Status |
|------:|--------|:------:|
| 1 | Fundament: Auth + Theme + Routing | ✅ |
| 2 | Supabase-Schema + Vorrat-CRUD + Pantry-Screen | ⬜ |
| 3 | Scanner: Barcode + MHD-OCR + Open Food Facts | ⬜ |
| 4 | KI-Rezepte via Supabase Edge Function (Gemini) | ⬜ |
| 5 | Profil-Screen + lokale Push-Notifications | ⬜ |
| 6 | iOS-Build (optional) | ⬜ |

---

## Architektur-Notizen

- **State-Management:** Riverpod (mit `ConsumerWidget` / `ConsumerStatefulWidget`).
- **Navigation:** `go_router` mit zentralem Auth-Guard. Der Router lauscht
  auf `authStateChangesProvider` und leitet automatisch um.
- **Auth:** Sessions werden von `supabase_flutter` automatisch persistiert
  (`flutter_secure_storage` als Hintergrund-Speicher).
- **API-Keys:** Der Supabase `anon`-Key gehört in die App (öffentlich
  unbedenklich, RLS schützt die Daten). Der **KI-API-Key** (kommt in Phase 4)
  liegt **nicht** in der App, sondern als Secret in einer Supabase Edge
  Function — das ist wichtig fürs Uni-Projekt, sonst ist der Key im APK
  extrahierbar.

---

## Nächster Schritt (Phase 2)

In Phase 2 werden wir:
1. SQL-Schema für `pantry_items` und `profiles` mit RLS schreiben (als
   Migration in `supabase/migrations/`).
2. `PantryRepository` mit CRUD-Operationen bauen.
3. Den echten `PantryScreen` aus dem Design-Entwurf umsetzen
   (Liste, Filter-Chips, Ablauf-Indikator, Warn-Card).
4. Manuelles Hinzufügen von Items (für jetzt — Scanner kommt in Phase 3).
