# Typing Sounds

A small Mac menu-bar app that adds sound to your keyboard. Choose from mechanical
keyboards, vintage typewriters, music, bubbles and other effects.

## Install and open

1. Download `Typing-Sounds-1.2.0-universal.zip` from [Releases](https://github.com/theinformed/typing-sounds/releases).
2. Unzip it and drag **Typing Sounds.app** into **Applications**.
3. Open **Typing Sounds** from Applications or Spotlight (`⌘ Space`).
4. Allow **Input Monitoring** in System Settings → Privacy & Security. This lets
   the app notice key presses while you work in other apps.

Requires macOS 13 or later. The download contains Apple silicon and Intel code.
This initial release is locally signed, without Apple notarization. macOS may
block its first launch; after trying to open it, use **Open Anyway** in System
Settings → Privacy & Security if you trust this download. See
[Apple's instructions](https://support.apple.com/en-us/102445).

Opening the app shows its settings window. Closing the window leaves the app in
the menu bar. Click the **⌘ with sound waves** icon for quick controls, or open
Typing Sounds again to return to settings. Choose **Quit Typing Sounds** to exit.

## Controls

- Enable or pause sounds, select a profile, adjust volume, and preview the sound.
- Choose **Open at login** to start automatically through macOS Login Items.
- Use **Sound Library** to choose which profiles appear in the quick menu.
- Choose whether held keys repeat their sounds and select a menu-bar icon.

Fresh installations leave Open at login off. Existing installations migrate their
previous login preference to macOS's native login-item service.

## Privacy and performance

The app uses a read-only event tap. Numeric key codes and modifier flags choose a
sound; typed text is never collected or saved. There are no accounts, network
requests, analytics, microphone recordings, or keystroke logs. macOS can suppress
keyboard observation during secure input, including some password fields.

Decoded audio buffers are shared by eight reusable voices. The audio engine stops
shortly after the last sound finishes. Disabling sounds also stops keyboard
monitoring. The menu-bar icon stays still while you type.

## Build from source

Install Xcode Command Line Tools and `ffmpeg` (for example, `brew install ffmpeg`).
Then run:

```sh
./build.sh
```

The result is `build/Typing Sounds.app`. Drag it into Applications. The build is
universal by default; `ARCHS=arm64 ./build.sh` builds only for Apple silicon.
There are no package dependencies beyond Apple's system frameworks.

Run the resource and silent playback checks on a Mac with an audio output:

```sh
"build/Typing Sounds.app/Contents/MacOS/TypingSounds" --self-test
"build/Typing Sounds.app/Contents/MacOS/TypingSounds" --audio-test
"build/Typing Sounds.app/Contents/MacOS/TypingSounds" --benchmark --preset classicTypewriter
```

The benchmark generates key codes internally and prints process CPU use for idle,
12 key presses per second, settling, and idle again. It mutes only its own audio.
It does not record sound, generate system key events, or change system volume.

To create the shareable ZIP, run `./release.sh`. Tagged GitHub builds also produce
a release ZIP. Apple Developer ID signing and notarization are future work.

## Sounds and license

The code is MIT-licensed. The public app includes 21 profiles using MIT-licensed
and CC0 recordings. Full credits and license text are in
[ThirdPartyNotices.txt](Resources/ThirdPartyNotices.txt), also bundled with the app.

Two optional recordings from Typing.com and TypingClub are retained only in the
original personal installation. They are excluded from Git and public releases;
this repository does not claim permission to redistribute them. Their menu
entries appear only when those optional local files are present at build time.
