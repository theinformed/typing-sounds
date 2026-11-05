# Typing Sounds

A native Apple silicon Mac app for mechanical keyboard clicks, soft ASMR thock,
vintage typewriters, music and playful effects. It lives in the menu bar, with a
settings window when you want more control.

Version 2.0 is a development candidate. Read [AudioRights.md](AudioRights.md)
before redistributing recordings; the candidate release is held for clearance.

## Install

Download the DMG or ZIP from [Releases](https://github.com/theinformed/typing-sounds/releases).
Drag **Typing Sounds.app** into **Applications**, then open it. No Terminal, Python,
developer tools, helper services or account is needed to run the app.

Allow **Typing Sounds** in **System Settings → Privacy & Security → Input Monitoring**
for sounds in other apps. That is the only system-wide privacy permission the app
requests. The local keyboard preview works without it. Opening the app again shows
Settings; closing that window leaves the menu-bar controls running.

Requires an M-series Mac and macOS 13 or later. Development builds use a local
signature, so macOS may require **Open Anyway** on first launch. Developer ID
signing, notarization and Mac App Store preparation are in [Distribution.md](Distribution.md).
A successful local build does not establish notarization or App Store approval.

## Make it yours

- **Sounds & Profiles:** browse an expandable tree of Mechanical, Vintage,
  Typewriter, Musical, Playful and Electronic sounds. Optional search filters
  the tree; each pack has a preview that leaves your chosen sound unchanged.
  Adjust volume, save a named profile, or switch between ASMR, Focus, Vintage
  and Playful. Try sounds in the visual keyboard without saving typed text.
- **Floating Sound Picker:** open it from the menu bar or Settings. Keep it above
  other windows while typing in your own app. Choose a category, step through its
  sounds with Previous/Next, preview a click, adjust volume, or pause. Automatic
  previews can be turned off. Closing it leaves your chosen sound active.
- **Key Sounds:** keep defaults or customize Return, Space, Backspace, Tab, Escape,
  Shift, Control, Option, Command, Caps Lock, Fn/Globe, arrows and Forward Delete.
  Each can be silent, match typing, or use another pack, with its own volume.
- **Behavior:** choose repeats and shortcut sounds, pause in Low Power Mode, and
  select quiet apps. Sleep and user-session changes pause playback automatically.
- **Appearance & About:** choose a menu-bar icon, visit Sean's website, read credits,
  and use the support link when configured for a direct-download build.

The candidate catalog includes 41 sound packs, plus two optional personal packs.
Fifteen original designed packs expand Typewriters (8), Musical (7), Playful (6),
and Electronic & Retro (7). Mechanical (10) and Vintage (3) keyboards have separate
menus. Designed sounds are labeled in their descriptions and rendered to PCM
before packaging; typing never runs a synthesizer.

Five recorded switch packs are NovelKeys
Cream, Topre, Kailh Box Navy, Turquoise Tealios and Blue Alps. Source URLs, pinned
revision and hashes are in [KeyboardSources.json](Resources/KeyboardSources.json).
The names identify the recordings, rather than a promise that every physical
keyboard sounds the same.

Redistribution status is documented in [AudioRights.md](AudioRights.md). The
website packs are excluded from candidate downloads. Several other recordings
have repository-level MIT notices but incomplete original-recording provenance;
the candidate is not a cleared public or App Store release.

## Privacy and performance

A read-only event tap observes virtual key codes and modifier flags. Typed text
is not collected or saved. There are no keystroke logs, analytics, accounts,
microphone recordings or background network requests. Explicit links open in
your browser. Secure input can prevent sounds in password fields.

The app shares cached PCM buffers and eight player voices. Audio stops after the
last sound finishes; keyboard monitoring stops while paused. Routing reads an
in-memory configuration, with no preference or file reads on each key press.
Quiet apps, sleep and power-mode handling use notifications, not polling.
The keyboard display redraws only in response to input or focus changes; it has
no idle animation loop. Measurements and review findings are in [Performance.md](Performance.md).

Modifiers use softer clicks from the selected pack by default; customization can
mute them or choose a different sound. Left and right versions share a sound and
are tracked separately. Releases do not create extra clicks, and shortcut letters
stay quiet unless enabled. The menu-bar Keyboard submenu groups sounds by feel:
soft/thocky, tactile/balanced and crisp/clicky, with section dividers. Vintage
keyboards have their own submenu. The compact browser preserves your scroll
position and open categories when you move to the keyboard preview.
Settings changes cancel delayed sounds from the previous
configuration. Existing sound and volume choices survive upgrades.

## Build and check

Building requires Xcode Command Line Tools, Python 3 and ffmpeg; packaged-app users do not
need either. All sounds are bundled and normal builds need no downloads.

```sh
./build.sh
swiftc Sources/Models.swift Tests/ModelsTests.swift -o build/models-test
./build/models-test
"build/Typing Sounds.app/Contents/MacOS/TypingSounds" --self-test
"build/Typing Sounds.app/Contents/MacOS/TypingSounds" --settings-self-test
"build/Typing Sounds.app/Contents/MacOS/TypingSounds" --floating-self-test
"build/Typing Sounds.app/Contents/MacOS/TypingSounds" --audio-test
"build/Typing Sounds.app/Contents/MacOS/TypingSounds" --benchmark --preset nkCream
```

Audio tests and benchmarks mute only their own output. They do not record audio,
generate system key events, change system volume or alter your settings.
Settings tests use isolated preferences. `--render-settings OUTPUT_DIRECTORY`
renders the app's own views without screen-recording access.

Run `./release.sh` for the public ZIP and drag-to-Applications DMG. Public builds
exclude two optional personal Typing.com/TypingClub recordings. Their entries
appear only in personal builds that contain those files.

Code is [MIT-licensed](LICENSE). Audio retains the terms and credits in
[ThirdPartyNotices.txt](Resources/ThirdPartyNotices.txt), also bundled with the app.
