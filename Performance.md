# Code and performance review

Reviewed on an Apple M3 Max running macOS 27.0.1, 4 November 2026.

## CPU measurements

A paired local run used the installed 1.3.0 app and the 2.0.0 candidate, with Classic
Typewriter at 12 virtual key presses per second for ten seconds. CPU is process
CPU time divided by elapsed time; 100% is one CPU core.

| Phase | 1.3.0 | 2.0.0 |
| --- | ---: | ---: |
| Typing, 120 keys | 2.80% | 2.29% |
| Idle after sounds settled | 0.25% | 0.18% |

The new Cream pack measured 2.89% while typing and 0.22% in the idle phase in an
earlier candidate run. Separate runs ranged from 0.99% to 2.80% for the old app,
so these figures describe this machine and test rather than a universal saving.
The benchmark includes a 12 Hz pacing loop, which adds idle overhead. The audio
test separately verifies that the engine actually stops after the final sample.

Tests mute their own audio and record nothing. These CPU measurements do not
establish battery runtime or whole-system energy consumption.

## Changes reviewed

- Key handling uses one in-memory configuration, static key sets and a cached
  resource catalog; there are no per-key defaults or file reads.
- Eight player voices and decoded buffers are shared across sounds.
- One rescheduled monotonic idle timer releases the audio hardware after sounds
  finish. A system-clock change cannot extend that interval indefinitely.
- Pausing, sleep, user-session changes, excluded apps and optional Low Power Mode
  stop audio and keyboard observation. Resume follows the user's on/off choice.
- App and power changes use notifications; no polling daemon or helper process
  runs behind the application.
- Delayed typewriter bells are cancelled across configuration and audio resets.
- Event-tap recovery resets modifier state; left/right releases and duplicate
  events are handled without extra modifier clicks.

## Verification

The candidate passed 51 isolated routing/profile checks, decoding of 181 public
audio resources, playback/restart/stop/idle tests for 26 public profiles, and native
settings control/persistence tests. Settings views were inspected in light and
dark appearance. Pinned source hashes cover all forty new recorded samples.

Still required before a production App Store submission: real distribution
signing, first-install and sandboxed global-input checks on fresh supported Macs,
longer battery observations, and Apple's review. See [Distribution.md](Distribution.md).
