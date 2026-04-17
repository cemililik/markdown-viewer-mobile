# Google Play Console — English listing

Copy-paste targets for the Play Console → **Main store listing**
(English, United States) and **App content** sections.

---

## App name
(30 character max)

```
MarkdownViewer
```

## Short description
(80 character max; shown under the app name in search results)

```
Offline markdown reader with mermaid, math, code highlight, and PDF export.
```

## Full description
(4000 character max; plain text, no markdown)

```
MarkdownViewer is a distraction-free reader for .md files on Android
phones and tablets. Open a file from your favourite file manager,
receive one through the system share sheet, or sync an entire
documentation repository from GitHub and read it offline.

RICH RENDERING
• Full CommonMark + GitHub Flavored Markdown
• Mermaid diagrams rendered inline
• LaTeX math (inline and display) via a KaTeX-compatible engine
• Syntax-highlighted code blocks across 190+ languages
• GFM tables, task lists, footnotes, strikethrough
• GitHub-style admonitions (NOTE, WARNING, TIP, CAUTION)

READING COMFORT
• Material 3 design with light, dark, and sepia themes
• Dynamic color support on Android 12+
• Adjustable font size, reading width, and line height
• Immersive scroll — the app bar fades away as you read
• Table of contents drawer with one-tap navigation
• In-document search with match counter
• Reading-position bookmark — resume exactly where you left off
• Keep-screen-on toggle for long-form reading
• Reading time estimate

BRING YOUR OWN DOCS
• Sync any public GitHub repository with a single URL
• Private repos supported via a personal access token (stored in the
  Android Keystore via EncryptedSharedPreferences — never in the
  app's database)
• Incremental re-sync — only changed files download
• Re-sync or remove a synced repo from the drawer

EXPORT AND SHARE
• Export any document to PDF with mermaid diagrams preserved
• Share the raw markdown or a rendered PDF via the system share sheet

STORAGE ACCESS FRAMEWORK
• Pick any folder on internal storage or SD card; the app remembers
  the permission across restarts
• Works with cloud-backed folders from Google Drive, Dropbox, etc.
  via their system providers

PRIVACY BY DESIGN
• No accounts, ever
• Zero telemetry by default
• Crash reporting is opt-in and excludes document content, file
  paths, and tokens
• The only network traffic is to GitHub when you explicitly sync

Made in the open on GitHub. Licensed under Apache-2.0.
```

## App category
**Productivity**

## Tags
(Play Console suggests tags from the description — accept
"Markdown", "Notes", "Productivity", "Documentation" if offered)

## Store listing contact details
- Email: `cemililik@outlook.com`
- Website: `https://cemililik.github.io/markdown-viewer-mobile/`
- Phone: (leave blank)

## External marketing opt-out
Per Google Play's 2024 policy, opt **in** to showing the app on
regional featured lists if comfortable, otherwise leave the default
(opt-out).

## App content answers
(Play Console → **App content**, nine sections)

### 1. Privacy policy
```
https://cemililik.github.io/markdown-viewer-mobile/privacy.html
```

### 2. App access
**All functionality is available without any special access**

### 3. Ads
**No, my app does not contain ads**

### 4. Content rating
Complete the IARC questionnaire per the answers in
[privacy-questionnaire.md](privacy-questionnaire.md). Expected
rating: **Everyone** (3+ in all regions).

### 5. Target audience
**18 and over** (conservative — the app's GitHub-sync feature
targets developers / technical users)

### 6. News apps
**No**

### 7. Data safety
Per [privacy-questionnaire.md](privacy-questionnaire.md), declare:
- Data collected: **None**
- Data shared: **None**
- Data encrypted in transit: **Yes** (HTTPS for GitHub sync)
- Users can request deletion: **Not applicable** (no accounts)

Optional crash-report category (if opt-in flow is declared separately):
- **Crash logs** — collected only with user consent, transmitted to
  Sentry, does not include PII / document content / file paths

### 8. Government apps
**No**

### 9. Financial features
**No**

---

## What's new in this version
See [whats-new.md](whats-new.md) — also inserted by `release.yml`
from the annotated tag message.
