# Store submission content — v1.0.0

Listing copy, screenshots list, and questionnaire answer templates for
the first public release on Apple App Store and Google Play Console.
All text is canonical here; copy-paste into the respective console UI.

## File map

- [app-store-en.md](app-store-en.md) — App Store Connect listing, English
- [app-store-tr.md](app-store-tr.md) — App Store Connect listing, Turkish
- [play-console-en.md](play-console-en.md) — Play Console listing, English
- [play-console-tr.md](play-console-tr.md) — Play Console listing, Turkish
- [privacy-questionnaire.md](privacy-questionnaire.md) — App Privacy
  questionnaire answers (Apple) and Data Safety answers (Google)
- [whats-new.md](whats-new.md) — Release-notes copy pushed by
  `release.yml` to both stores via the annotated-tag message

## Checklist before submitting

### Apple App Store

1. [ ] Build uploaded to TestFlight via `release.yml` (internal testers
       can install within 10–15 min of the ipa job finishing)
2. [ ] App Store Connect → **App Information** — Primary Category:
       **Productivity** · Secondary: **Developer Tools**
3. [ ] App Store Connect → **Pricing and Availability** — Free ·
       Worldwide except countries you exclude manually
4. [ ] App Store Connect → **App Privacy** — answers from
       [privacy-questionnaire.md](privacy-questionnaire.md)
5. [ ] App Store Connect → **Version 1.0** — copy from
       [app-store-en.md](app-store-en.md) (and localized TR version)
6. [ ] Screenshots uploaded for each required device size
       (6.7" iPhone, 5.5" iPhone, 12.9" iPad, 11" iPad if iPad build)
7. [ ] Select build from TestFlight in the version's "Build" section
8. [ ] Export compliance answer: **No** (standard HTTPS + Keychain only,
       no custom cryptography) — the app's `ITSAppUsesNonExemptEncryption`
       key already declares this
9. [ ] Age Rating: **4+** (see [privacy-questionnaire.md](privacy-questionnaire.md))
10. [ ] Submit for review

### Google Play Console

1. [ ] Build uploaded to Play Console internal track via `release.yml`
       (draft release waiting to be rolled out)
2. [ ] Play Console → **Main store listing** — copy from
       [play-console-en.md](play-console-en.md) (and localized TR)
3. [ ] App icon already bundled in the AAB (no separate upload needed)
4. [ ] Feature graphic (1024×500) — to be designed; see note below
5. [ ] Screenshots (phone: min 2, tablet: optional) — captured from
       the device or Android emulator
6. [ ] Play Console → **App content** — all nine sections:
       - Privacy policy URL:
         `https://cemililik.github.io/markdown-viewer-mobile/privacy.html`
       - App access: **All functionality available without special access**
       - Ads: **No, my app does not contain ads**
       - Content rating: complete the IARC questionnaire
         (see [privacy-questionnaire.md](privacy-questionnaire.md))
       - Target audience: **18 and over**
       - News apps: **No**
       - Data safety: answers from
         [privacy-questionnaire.md](privacy-questionnaire.md)
       - Government apps: **No**
       - Financial features: **No**
7. [ ] Promote the internal-track release → Closed testing → Production
8. [ ] Publishing overview → **Send for review**

## Assets still to produce (user task — not generatable via CLI)

- **iPhone screenshots** (6.7" and 5.5" required):
  - Library (populated recents)
  - Viewer (a document with a mermaid diagram visible)
  - TOC drawer open
  - Settings screen
  - Source picker drawer with at least one synced repo
- **iPad screenshots** (12.9" if iPad build ships):
  - Same five surfaces rendered on a tablet canvas
- **Android phone screenshots** (same five surfaces)
- **Android tablet screenshots** (optional but recommended)
- **Play Store feature graphic** 1024×500 (brand hero image)

Tooling suggestion: `flutter drive` + `screenshots` package, or manual
captures from a simulator/emulator with the device frames added in
a design tool.
