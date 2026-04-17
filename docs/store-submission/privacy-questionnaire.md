# Privacy + Data-Safety questionnaire answers

Canonical answers for the **Apple App Privacy** questionnaire and the
**Google Play Data Safety** form. Grounded in
[ADR-0014](../decisions/0014-logging-and-observability.md),
[docs/standards/security-standards.md](../standards/security-standards.md)
§Logs, and the public
[privacy policy](https://cemililik.github.io/markdown-viewer-mobile/privacy.html).

The short version: **the app collects nothing by default**. Opt-in
crash reports are the single exception and even they exclude document
content, file paths, and access tokens.

---

## Apple — App Privacy

In App Store Connect → **App Privacy**, answer each section as follows.

### Data Used to Track You
```
Does your app collect data that is used to track the user?

  → No
```

The app does not use any advertising SDKs, identifiers for
advertisers (IDFA), or analytics that cross app / website boundaries.

### Data Not Linked to You (only if crash reporting is declared)
```
Does your app collect any data that is NOT linked to the user's
identity?

  → Yes — if and only if the user has opted into crash reporting.
```

Declared categories for the **opt-in** path:
- **Crash Data** — purpose: **App Functionality**
- **Performance Data** — purpose: **App Functionality** (Sentry's
  navigation transactions record route names only; never PII)

Declare these with the option: **Data is not linked to the user's
identity** (Sentry is initialised with `sendDefaultPii: false` and no
user identifier is passed).

If you prefer the simpler path of **Data Not Collected**, that is
also defensible because Sentry only fires after an explicit user
toggle. Apple permits declaring the opt-in crash category either
way; the conservative choice is to declare it once the toggle exists
in the binary.

### Data Linked to You
```
Does your app collect any data that IS linked to the user's identity?

  → No
```

The app has no accounts, no login, no user identifier of any kind.

### App Functionality network calls
When the review team asks about network activity, point them at:
- `api.github.com` — GitHub's public REST API, used only when the
  user enters a URL and taps "Sync"
- `raw.githubusercontent.com` — raw file downloads, same gate
- `*.ingest.sentry.io` — crash reports, only when the user has
  opted into crash reporting in Settings

All three hosts are documented in the app's
[network access policy ADR](../decisions/0011-network-access-policy.md).

### Kids Category
**Not applicable.** The app is not designed for children and does
not target the Kids category.

---

## Google Play — Data Safety

In Play Console → **App content** → **Data safety**, answer each
section as follows.

### Does your app collect or share any of the required user data types?
```
  → No  (if crash reporting is declared via a separate, in-app toggle
         that Google does not require disclosure of)

  → Yes (if you want to declare the opt-in crash path for maximum
         transparency)
```

The **Yes** path — recommended for transparency — declares exactly
one category.

### Is all of the user data collected by your app encrypted in transit?
```
  → Yes
```

All network requests use HTTPS (`api.github.com`,
`raw.githubusercontent.com`, `*.ingest.sentry.io`). The Android
build's default-secure `usesCleartextTraffic` posture and the
standards document's "no TLS opt-out" rule are the evidence.

### Do you provide a way for users to request that their data be deleted?
```
  → No  (because we collect no account-linked data — there is nothing
         to delete at the user level; uninstall removes all local state)
```

### Declared data type (only if Yes was selected above)

Under **Crash logs**:
- **Purpose**: App functionality, Analytics
- **Optional**: yes (user controls via Settings → Send crash reports)
- **User can request deletion**: Handled by Sentry's per-event
  retention and project-level purge controls; individual user purge
  is not applicable because events are unlinked to a user identity.
- **Encrypted in transit**: yes
- **Data ephemerally processed**: no (Sentry retains events per
  project retention policy)

Do **not** declare any other categories:
- No **Personal info**, **Financial info**, **Health**, **Location**,
  **Contacts**, **Files and docs**, **Photos and videos**,
  **Messages**, **Audio**, **Calendar**, **Web browsing**,
  **App activity**, **Device IDs**, or **App info and performance**
  beyond Crash logs.

The user's own `.md` files do not count as "Files and docs collected
by the app" — the user opens them locally; the app does not upload,
back up, or transmit their contents.

---

## Apple — Age Rating

Answer each of the 11 questions as follows:

| Question | Answer |
|----------|--------|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content and Nudity | None |
| Alcohol, Tobacco, or Drug Use or References | None |
| Simulated Gambling | None |
| Contests | None |
| Unrestricted Web Access | **No**  (the app does not embed a browser view for arbitrary URLs)  |
| Gambling and Contests | None |

**Expected rating: 4+**

The `Unrestricted Web Access` answer is **No** because the mermaid
WebView is sandboxed (`blockNetworkLoads: true`, `allowFileAccess:
false`, CSP `default-src 'none'`, `javascript:` redirected) and the
markdown-link `launchUrl` path allow-lists the scheme to
`http`/`https`/`mailto` before invoking the system browser. The
in-app rendering never loads third-party web content.

---

## Google — IARC Content Rating

Play Console runs the IARC questionnaire (International Age Rating
Coalition). Answer as follows for a **3+ / Everyone** rating:

| Question | Answer |
|----------|--------|
| Violence | No |
| Sexuality / Nudity | No |
| Gambling | No |
| Language | No |
| Controlled substances | No |
| Fear / Horror | No |
| User-generated content | **No** (the app does not aggregate or share user content; it just renders local files) |
| Unrestricted Internet | **No** (same rationale as Apple's equivalent — mermaid sandbox + link allow-list) |
| Location sharing | No |
| Personal info sharing | No |
| Digital purchases | No |

**Expected rating: 3+ (Everyone)** across all regional boards
(PEGI, ESRB, USK, GRAC).

---

## FAQ — review team may ask

**Q: Why does the app require INTERNET permission on Android?**
A: Only the user-facing GitHub sync feature uses the network, and
only when the user enters a URL and taps "Sync". Sentry crash
reporting is gated behind an in-app toggle that defaults to off.
Both hosts are documented in ADR-0011.

**Q: Is the app free of third-party tracking SDKs?**
A: Yes. No ads SDKs, no Facebook SDK, no Google Analytics, no
Firebase Analytics. The only external service that may receive
anything is Sentry, and only after the user explicitly opts in.

**Q: Where are user files stored?**
A: Locally on the device. Repo-sync files are cached under the
app's Documents directory; share-intent files under the Cache
directory. Uninstall removes both. The app never uploads user
files.

**Q: How is the GitHub personal access token stored?**
A: iOS Keychain (via `flutter_secure_storage`'s
`kSecClassGenericPassword` path) and Android Keystore (via
`EncryptedSharedPreferences` with AES-256-GCM). The token never
touches the SQLite database, never appears in logs, and is never
forwarded to any host outside the GitHub allow-list.
