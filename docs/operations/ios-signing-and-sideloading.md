---
title: Building + installing without a Mac (CI signing & sideloading)
type: operation
created: 2026-11-03
updated: 2026-11-03
sources:
  - code: .github/workflows/build-ios.yml
  - code: README.md
  - ext: https://developer.apple.com/account
verified_at: 8a76d91
---

No Mac is required to get `Lexdar` onto an iPad: Xcode itself only runs on
macOS, but a GitHub Actions **macOS runner** can build and sign the app for
you, and a Windows tool can install the resulting `.ipa` over USB. Every
step below runs from the Apple Developer *website* and OpenSSL — neither
needs Xcode or Keychain Access.

Requires an **Apple Developer Program** membership ($99/yr). The free
tier's web portal does not expose certificate/profile creation — that's an
Apple restriction on the free tier, not something this workflow can route
around.

## 1. Generate a certificate request with OpenSSL (Windows or any OS)

```bash
openssl genrsa -out ios_distribution.key 2048
openssl req -new -key ios_distribution.key -out ios_distribution.csr \
  -subj "/CN=Your Name/[email protected]"
```

This produces `ios_distribution.csr` — upload it at
developer.apple.com → **Certificates, Identifiers & Profiles → Certificates
→ +**, choosing **Apple Development**. Download the resulting `.cer`.

## 2. Convert to a `.p12` (still no Mac needed)

```bash
openssl x509 -in development.cer -inform DER -out development.pem -outform PEM
openssl pkcs12 -export \
  -inkey ios_distribution.key \
  -in development.pem \
  -out development.p12 \
  -passout pass:CHOOSE_A_P12_PASSWORD
```

## 3. Register the iPad and create an App ID + provisioning profile

All in the web portal, under **Certificates, Identifiers & Profiles**:

- **Devices → +** — register the iPad's UDID (Settings → General → About
  on the iPad, or `xcodebuild -showdestinations` if a Mac is ever handy;
  otherwise several UDID-lookup web tools can read it from a browser once
  the device is plugged in and trusted).
- **Identifiers → +** — create an App ID matching `com.lexdar.app`
  (see `PRODUCT_BUNDLE_IDENTIFIER` in `Lexdar.xcodeproj/project.pbxproj`).
- **Profiles → +** — **iOS App Development**, select the App ID, the
  certificate from step 1, and the registered device. Download the
  `.mobileprovision` file and note the **profile name** you gave it.

## 4. Add repository secrets and variables

In the GitHub repo: **Settings → Secrets and variables → Actions**.

**Secrets** (base64-encode the two binary files first —
`base64 -i development.p12 | tr -d '\n'`, same for the `.mobileprovision`):

| Secret | Value |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | base64 of `development.p12` |
| `P12_PASSWORD` | the password chosen in step 2 |
| `BUILD_PROVISION_PROFILE_BASE64` | base64 of the `.mobileprovision` |
| `KEYCHAIN_PASSWORD` | any throwaway password — only used for the CI run's temporary keychain |

**Variables** (Variables tab, not Secrets — these aren't sensitive):

| Variable | Value |
|---|---|
| `SIGNING_CONFIGURED` | `true` (gates the archive job in [[scan-to-renovation-flow]]'s CI — see `.github/workflows/build-ios.yml`) |
| `APPLE_TEAM_ID` | your 10-character Team ID, shown on the Membership page |
| `PROVISIONING_PROFILE_NAME` | the exact profile name from step 3 |
| `EXPORT_METHOD` | `development` (leave as-is for a personal-device install) |

> ⚠️ `SIGNING_CONFIGURED` is a repository **variable**, not a secret, and
> the archive job's `if:` reads it as the literal string `'true'` — setting
> it to `True`/`1`/anything else leaves the job silently skipped.

## 5. Run it

Push to the branch, or trigger manually from the **Actions** tab
(`workflow_dispatch`). The `archive` job uploads a `Lexdar-ipa` artifact —
download and unzip it to get `Lexdar.ipa`.

## 6. Install on the iPad from Windows

[Sideloadly](https://sideloadly.io/) (free, Windows-native): plug the iPad
in over USB, point Sideloadly at `Lexdar.ipa`, sign in with the same Apple
ID used for the certificate. No Mac touches this step either.

> ⚠️ A **Development** profile only installs on devices registered in step
> 3. Adding a second test device means re-creating the provisioning
> profile (include the new UDID) and re-running step 4's base64 encode for
> `BUILD_PROVISION_PROFILE_BASE64` — the old profile's device list doesn't
> update itself.

> ⚠️ Apple Development certificates expire after about a year; when the
> `archive` job starts failing with a signing/profile error, it's usually
> this — repeat steps 1-4 with a fresh certificate and profile.
