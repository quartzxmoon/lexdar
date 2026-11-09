---
title: Building + installing without a Mac (CI signing & sideloading)
type: operation
created: 2026-11-03
updated: 2026-11-09
sources:
  - code: .github/workflows/build-ios.yml
  - code: README.md
  - ext: https://developer.apple.com/account
verified_at: a13e0bb
---

No Mac is required to get `Lexdar` onto an iPad: Xcode itself only runs on
macOS, but a GitHub Actions **macOS runner** can build and sign the app for
you, and a Windows tool can install the resulting `.ipa` over USB. This
covers the whole app as it grows — [[blueprint-production]]'s DXF export
and annotation features added two more system frameworks (PencilKit,
PhotosUI), but those need no new CI steps, secrets, or build settings:
the project-generator script's `frameworks` list links them the same way as
RoomPlan/ARKit/SceneKit/QuickLook/PDFKit, so nothing here changes when
new frameworks are added that way. Every step below runs from the Apple
Developer *website* and OpenSSL — neither needs Xcode or Keychain Access.

The **signed** route (steps 1-6 below) requires an **Apple Developer Program**
membership ($99/yr). The free tier's web portal does not expose
certificate/profile creation — that's an Apple restriction on the free tier,
not something this workflow can route around. If you only want the app on
your own iPad, skip all of that and use the next section.

## Quickest path: unsigned .ipa + free Apple ID

The `validate` job in `.github/workflows/build-ios.yml` also packages the
compiled app as `Lexdar-unsigned.ipa` and uploads it as the workflow artifact
`Lexdar-unsigned-ipa` (kept 30 days). It needs no secrets and no paid
membership, because Sideloadly signs it with your own free Apple ID at install
time.

1. GitHub repo > **Actions** > open a green run on the branch > download the
   `Lexdar-unsigned-ipa` artifact and unzip it to get `Lexdar-unsigned.ipa`.
2. On Windows, install [Sideloadly](https://sideloadly.io/) (it needs Apple's
   device support from iTunes or the Apple Devices app).
3. Plug the iPad in, trust the computer, enter your Apple ID in Sideloadly, drag
   in `Lexdar-unsigned.ipa`, press Start.
4. On the iPad: turn on **Settings > Privacy & Security > Developer Mode**
   (restarts the iPad), then **Settings > General > VPN & Device Management**
   and trust your Apple ID's developer entry. Open Lexdar.

> ⚠️ A free Apple ID's install **expires after 7 days** (open Sideloadly and
> install again over the top; data inside the app is kept when the bundle id
> is unchanged) and a free ID is limited to a few sideloaded apps at once. If
> Sideloadly reports the bundle id `com.lexdar.app` is taken, let it
> rewrite it to a unique one. This path was written from Sideloadly's
> documented behavior; it has not been run end to end from this repository.

> ⚠️ The unsigned build packages whatever `build/Build/Products/Release-iphoneos/Lexdar.app`
> the compile step produced. The compile step must keep `-derivedDataPath
> build`, or the packaging step cannot find the app and fails.

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

> ⚠️ The `validate` job's build step runs `set -o pipefail` before piping
> `xcodebuild` into `xcpretty`. Without it, the step's exit status is
> `xcpretty`'s (which exits 0 as long as it could parse the input), so a
> real `BUILD FAILED` from `xcodebuild` reports as a green check — this is
> exactly what happened on the first CI run (the project.pbxproj bug noted
> in [[scan-to-renovation-flow]] built silently "successfully"). If this
> step is ever rewritten, keep `set -o pipefail` or drop the `xcpretty`
> pipe entirely.

> ⚠️ Neither job pins a specific Xcode version with `xcode-select` anymore
> — a prior version of this workflow did (`sudo xcode-select -s
> /Applications/Xcode_16.app/Contents/Developer`), which turned out to be
> the actual root cause of a long chain of CI failures. This runner image
> carries several Xcode installs side by side (16.0 through 16.4, plus
> 26.x); the specific one pinned here had an iOS SDK that matched **no**
> installed simulator runtime (failing `CompileAssetCatalog` with "No
> simulator runtime version ... available to use with iphonesimulator SDK
> version ...", [actions/runner-images#13317](https://github.com/actions/runner-images/issues/13317)),
> and on a later run its device-platform support wasn't even registered as
> installed ("iOS 18.0 is not installed") — i.e. **not every Xcode copy on
> the image is fully provisioned**, only whichever one `xcode-select`
> already defaults to. Just using that default (by not overriding it)
> fixed it. `SUPPORTED_PLATFORMS=iphoneos` (an earlier, narrower attempt at
> the same symptom) stays in place too — harmless, and still correct in
> principle (it keeps `actool` from validating against a platform the CI
> build doesn't target), but it was not sufficient on its own; the Xcode
> pin was the real culprit. If a future CI run needs a *specific* Xcode
> version again (e.g. to pin a known-good toolchain), add a diagnostic
> step first (`ls /Applications | grep -i xcode`,
> `xcrun simctl list runtimes`) rather than guessing a path — this took
> three wrong guesses before that diagnostic step actually settled it.

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
