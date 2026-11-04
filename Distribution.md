# Mac distribution

The app is self-contained. Customers install the app bundle and grant Input
Monitoring for system-wide sounds; developer tooling is not part of the installed
product. Signing and App Store distribution do not bypass that privacy choice.

## Direct download

`./release.sh` creates an Apple silicon ZIP, a DMG with an Applications shortcut,
and SHA256 files. Development builds use a local signature for testing.

For a production direct release:

1. Use an Apple Developer Program account and a valid **Developer ID Application**
   identity on the build Mac. `security find-identity -v -p codesigning` lists
   available identities; the reviewed seat currently has none.
2. Run `SIGN_IDENTITY='your Developer ID Application identity' ./release.sh`.
   This enables hardened runtime and a secure timestamp.
3. Store notarization credentials in an owner-controlled Keychain profile using
   Apple's instructions. Keep credentials outside this repository.
4. Intentionally run `NOTARY_PROFILE='your profile' ./Scripts/notarize.sh`.
   It requires a Developer ID signature, waits for Accepted, staples and validates
   the ticket, then repackages. Ordinary builds never submit to Apple.
5. Verify the downloaded archive and first-launch flow on a fresh Mac before
   publishing a release as notarized.

Apple's guides: [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
[custom workflows](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Mac App Store

The prepared build variant is:

```sh
DISTRIBUTION=app-store INCLUDE_PERSONAL_SOUNDS=0 \
  APP_DIR="$PWD/build/app-store/Typing Sounds.app" ./build.sh
```

It compiles the store variant, enables App Sandbox, includes user-selected
read-only file access for choosing quiet apps, and excludes legacy launch-agent
migration and the external donation button. It requests no network-client,
microphone, screen capture, Accessibility, raw HID or Full Disk Access privileges.

This is preparation, not a signed submission. The owner's Apple Developer account
is needed to register the existing bundle identifier, configure distribution and
installer identities and any provisioning, prepare App Store Connect metadata,
privacy/support URLs and screenshots, and upload a correctly signed package with
Xcode or Transporter. Test sandboxed first launch, persistence, login, preview and
global input on supported macOS versions, then complete Apple's review. A local
sandbox signature does not establish acceptance.

The bundled privacy manifest declares no tracking or collected data. Its required
API reasons cover app-private settings (CA92.1) and elapsed-time/timer calculations
(35F9.1), following [Apple's required-reason API list](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
Neither defaults nor timing information is transmitted by the app.

Apple requires [App Sandbox for store submissions](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox).
Apple DTS documents a [read-only event tap working in the sandbox after Input Monitoring approval](https://developer.apple.com/forums/thread/724608).
That establishes an API path, rather than approval of this app.

## Support and tips

About links to **https://sean.theinformed.org**. A direct build can include the
owner's verified HTTPS Buy Me a Coffee URL in the Info.plist `BuyMeACoffeeURL` key.
Do not substitute a guessed profile. The link opens the browser after a click.

The store build omits that external link. Store tips need real StoreKit consumable
products in App Store Connect and a validated purchase flow before a tip button
is enabled. No product or purchase is simulated. External payment-link rules vary
by storefront; check the current [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
for the submission regions. Tips must not silently unlock features.
