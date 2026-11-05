# Audio origins and redistribution review

Reviewed 4 November 2026. A sound may be copyrighted and still have a license
allowing redistribution. The question is the permission attached to the exact
recording, including any attribution and commercial-use conditions.

The current candidate is **not cleared for public or App Store distribution**.
Keep the GitHub release a draft while the unresolved rows below are resolved or
replaced. No permission request has been sent to any author.

| Sound family | Source and evidence | Distribution status |
| --- | --- | --- |
| Typing.com | The previous download record identifies `https://www.typing.com/dist/student/extras/sounds/keysprite.mp3`. [Typing.com terms](https://www.typing.com/termsofservice), Software section, reserve content rights; no separate open audio license was found. | Private asset, ignored by Git and excluded by the release build. Original recording author remains unidentified. Get written permission or replace it. |
| TypingClub | The previous download record identifies `https://static.edclub.com/m/audio/typewriter.mp3`. [EdClub terms](https://www.edclub.com/terms), Restrictions on Use or Access, identify the content as proprietary and restrict copying and distribution. The local file's Adobe Audition metadata does not identify an author or license. | Private asset, ignored by Git and excluded by the release build. No open audio license established. Get written permission or replace it. |
| IBM Model M / Model F | Raymangold22's own recordings on [Wikimedia Model M](https://commons.wikimedia.org/wiki/File:Typing_-_Model_M_1986.ogg) and [Model F](https://commons.wikimedia.org/wiki/File:Typing_-_Model_F_122_1984.ogg) explicitly carry CC0. | Clear source-level permission for adaptation and commercial redistribution. Preserve source records. |
| Hard Clack cuts | [Cassie-OrbitGames typewriter recordings](https://opengameart.org/content/typewriter-sounds) identify the author and CC0. | Clear source-level permission. Confirm the checked-in cuts remain matched to that download before a production package. |
| Sharp Strike cuts | [Unicae Games Keyboard Soundpack 1](https://opengameart.org/content/keyboard-soundpack-1-typing-and-single-keystrokes) identifies its Cherry KC 1000 recording and CC0. | Clear source-level permission. The app's sharp typewriter style is a designed mix, not a claim that this recording is an actual typewriter. |
| Hermes Precisa 305 | [Joseph Sardin's key recording](https://bigsoundbank.com/typewriter-key-s2842.html) explicitly carries CC0. Space and bell use additional BigSoundBank files. | Key source verified; confirm exact space/bell source records individually before production distribution. |
| UI clicks, Bubble Pop and Casino Chips | [Kenney UI Audio](https://kenney.nl/assets/ui-audio), [Casino Audio](https://kenney.nl/assets/casino-audio), and [Kenney's commercial-use explanation](https://kenney.nl/support) explicitly provide CC0. | Clear source-level permission; preserve pack/file mapping. |
| Mechanical switches / Blue Alps | The [kbsim repository](https://github.com/tplai/kbsim) has an MIT license. The five newest packs have pinned URLs and SHA256 values in `Resources/KeyboardSources.json`. Some older copies arrived via Keyboard Sounds Pro. [Upstream issue 44](https://github.com/tplai/kbsim/issues/44) asks whether the recordings were made by the maintainer and whether MIT covers them; it was open with no replies at review time. | Repository-level permission is documented; original recording ownership is unresolved. Do not describe these as independently cleared recordings. Obtain confirmation or replace them before a cleared release. |
| Classic Typewriter, Music Box, Bright Chimes, Drum Kit, Electric Sparks and Duck Quacks | [Daktilo](https://github.com/orhun/daktilo) supplies these files under a repository MIT/Apache notice. Its preset config maps the samples, but the reviewed README/config did not identify the original recordist and license for each sound. Byte hashes match the local files to Daktilo; Chimes are its music-box notes 9–11. | Repository notice retained. Original recording provenance needs a per-file audit; a software license alone is insufficient evidence of ownership. |
| Developer Click | [VSCode Typing Sound](https://github.com/kpab/vscode-typing-sound) lists bundled MP3 files and MIT, but does not identify the original recording source in the reviewed README. The four local files match its file bytes. | Repository-level notice retained; original recording provenance still needs confirmation. |
| Fifteen new Designed packs | `Scripts/make_sound_designs.py` generates all waveforms deterministically from oscillators and seeded noise. No recordings, instrument soundfonts, sampled songs or network downloads are used. | Original project material under the project's MIT license. Five short variations per pack are generated at build time. |

## A rejected additional source

[AndrewRadev/typewriter.vim](https://github.com/AndrewRadev/typewriter.vim) is MIT
licensed, but its README identifies external Freesound recordings. The source of
its clicks, [tjandrasounds 201590](https://freesound.org/people/tjandrasounds/sounds/201590/),
currently states **Attribution NonCommercial 4.0**. Its carriage recording,
[ramsamba 318686](https://freesound.org/people/ramsamba/sounds/318686/), states CC0.
The click recording was not added. This is a concrete example of why the audio's
own source terms must be checked separately from a surrounding repository's license.

## File-level tracing performed

Git blob hashes were computed from local source-file bytes and matched against
the upstream repository trees. This establishes the immediate file source, not
the original recordist's permission:

| Local files | Byte-identical upstream files |
| --- | --- |
| `typewriter-key`, `-space`, `-backspace`, `-carriage`, `-bell` MP3s | Daktilo `keystroke`, `keyup`, `derase`, `newline`, `ding` MP3s, respectively |
| `musicbox-1` through `-8` MP3s | Daktilo `mbox1` through `mbox8` |
| `chime-1` through `-3` MP3s | Daktilo `mbox9` through `mbox11` |
| `drum-hat`, `drum-kick`, `drum-snare` | Daktilo `hat`, `kick`, `snare` |
| `spark-1` through `-6` | Daktilo `dspark1` through `dspark6` |
| `quack-1`, `quack-2` | Daktilo `quack1`, `quack2` |
| `developer-key`, `-return`, `-backspace`, `-space` | VSCode Typing Sound `key-press`, `enter`, `backspace`, `tab`, respectively |

Some presets share special-key samples. Hard Clack and Sharp Strike reuse
Daktilo's space/backspace/carriage/bell resources, so CC0 letter recordings alone
do not clear those entire presets. Sharp Strike also mixes in the optional
TypingClub pool when present; public builds use the existing fallback instead.

The two historical website download URLs returned HTTP 403 during the current
check. Their historical origin is documented, but a current byte comparison was
not possible. No new license or original-author identity is inferred from that.

## Clearance work before sharing

1. Map every existing source file to its original URL, author, license, hash and
   any required credit. Recheck the exact bundled derivative against that source.
2. For unresolved recordings, obtain an explicit written commercial redistribution
   grant covering the app and its source repository, or replace the recordings.
3. Keep Typing.com and TypingClub out of shared artifacts unless separate permission
   is obtained. Personal possession does not establish redistribution rights.
4. Rebuild and inspect the actual ZIP/DMG contents, include the required notices,
   then complete Apple distribution signing and first-install checks.

No git history was rewritten and no existing source files were deleted by this
review. Earlier public versions should not be represented as newly rights-cleared.
