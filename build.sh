#!/bin/zsh
# build.sh -- build a portable macOS app from the bundled sound sources.
# Created by LT Sean Egan, PhD 2026-08-19
# Modified: SDE 2026-10-15 portable paths, universal releases, optional personal assets.
set -euo pipefail

project_dir=${0:A:h}
app_dir=${APP_DIR:-"$project_dir/build/Typing Sounds.app"}
contents_dir="$app_dir/Contents"

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
rm -rf "$contents_dir/Resources/Sounds"
mkdir -p "$contents_dir/Resources/Sounds"

architectures=(${=ARCHS:-arm64})
objects=()
for arch in $architectures; do
  object="$project_dir/build/TypingSounds-$arch"
  mkdir -p "$project_dir/build"
  xcrun swiftc -swift-version 5 -O -target "$arch-apple-macos13.0" \
    -framework AppKit -framework CoreGraphics -framework AVFoundation \
    -framework ServiceManagement \
    "$project_dir/Sources/main.swift" -o "$object"
  objects+=("$object")
done
lipo -create $objects -output "$contents_dir/MacOS/TypingSounds"

rsync -a "$project_dir/Info.plist" "$contents_dir/Info.plist"
if [[ ${INCLUDE_PERSONAL_SOUNDS:-1} == 1 && -f "$project_dir/Resources/typing-com-keysprite.mp3" ]]; then
segment_starts=(0 0.750 1.584 2.399 3.203 4.012 4.798 5.628 6.435 7.237 8.050 8.893 9.682 10.525 11.257 12.069)
segment_lengths=(0.250 0.334 0.315 0.305 0.309 0.286 0.329 0.307 0.302 0.313 0.343 0.288 0.343 0.232 0.313 0.382)

for index in {1..16}; do
  filename_index=$(printf '%02d' $((index - 1)))
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/typing-com-keysprite.mp3" \
    -ss "${segment_starts[$index]}" -t "${segment_lengths[$index]}" \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/typing-com-$filename_index.wav"
done
fi

if [[ ${INCLUDE_PERSONAL_SOUNDS:-1} == 1 && -f "$project_dir/Resources/typingclub-typewriter.mp3" ]]; then
ffmpeg -hide_banner -loglevel error -y \
  -i "$project_dir/Resources/typingclub-typewriter.mp3" \
  -ar 48000 -ac 2 -c:a pcm_s16le \
  "$contents_dir/Resources/Sounds/typingclub-typewriter.wav"

fi

for name in typewriter-key typewriter-space typewriter-backspace typewriter-carriage typewriter-bell; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/$name.mp3" \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/$name.wav"
done

clacky_offsets=(0.028 0.044 0.119 0.032 0.160 0.037 0.004 0.044)
for index in {1..8}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/clacky-$index.wav" \
    -ss "${clacky_offsets[$index]}" -t 0.32 -af 'afade=t=out:st=0.22:d=0.10' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/clacky-$index.wav"
done

sharp_offsets=(0.004 0.015 0.003 0.007 0.043 0.023 0.033 0.009)
for index in {1..8}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/sharp-$index.wav" \
    -ss "${sharp_offsets[$index]}" -t 0.16 \
    -af 'highpass=f=120,volume=1.15,afade=t=out:st=0.11:d=0.05' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/sharp-$index.wav"
done

# Short, onset-aligned cuts from authentic buckling-spring keyboard recordings.
# Keeping these under 0.12 seconds makes rapid typing feel immediate instead of
# replaying portions of the original continuous typing performance.
vintage_audio_work=$(mktemp -d /private/tmp/typingsounds-vintage-audio.XXXXXX)
ffmpeg -hide_banner -loglevel error -y \
  -i "$project_dir/Resources/SoundSources/ibm-model-m-1986.ogg" \
  -ar 48000 -ac 2 -c:a pcm_s16le "$vintage_audio_work/model-m.wav"
ffmpeg -hide_banner -loglevel error -y \
  -i "$project_dir/Resources/SoundSources/ibm-model-f122-1984.ogg" \
  -ar 48000 -ac 2 -c:a pcm_s16le "$vintage_audio_work/model-f.wav"

model_m_offsets=(0.098 0.608 1.019 1.567 3.035 3.574 4.174 4.243)
for index in {1..8}; do
  if (( index <= 4 )); then
    output_name="model-m-letter-$index"
  else
    output_name="model-m-number-$((index - 4))"
  fi
  ffmpeg -hide_banner -loglevel error -y \
    -ss "${model_m_offsets[$index]}" -i "$vintage_audio_work/model-m.wav" \
    -t 0.105 -af 'highpass=f=95,volume=2.0,alimiter=limit=0.96:attack=0.5:release=8,afade=t=out:st=0.075:d=0.030' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/$output_name.wav"
done

model_m_special_offsets=(2.578 5.929 7.707)
model_m_special_names=(space backspace return)
for index in {1..3}; do
  ffmpeg -hide_banner -loglevel error -y \
    -ss "${model_m_special_offsets[$index]}" -i "$vintage_audio_work/model-m.wav" \
    -t 0.135 -af 'highpass=f=80,volume=1.7,alimiter=limit=0.96:attack=0.5:release=10,afade=t=out:st=0.095:d=0.040' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/model-m-${model_m_special_names[$index]}.wav"
done

model_f_offsets=(0.619 1.168 1.697 2.042 2.832 2.938 3.901 4.545)
for index in {1..8}; do
  if (( index <= 4 )); then
    output_name="model-f-letter-$index"
  else
    output_name="model-f-number-$((index - 4))"
  fi
  ffmpeg -hide_banner -loglevel error -y \
    -ss "${model_f_offsets[$index]}" -i "$vintage_audio_work/model-f.wav" \
    -t 0.110 -af 'highpass=f=85,volume=1.35,alimiter=limit=0.96:attack=0.5:release=8,afade=t=out:st=0.080:d=0.030' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/$output_name.wav"
done

model_f_special_offsets=(2.357 6.408 7.417)
model_f_special_names=(space backspace return)
for index in {1..3}; do
  ffmpeg -hide_banner -loglevel error -y \
    -ss "${model_f_special_offsets[$index]}" -i "$vintage_audio_work/model-f.wav" \
    -t 0.145 -af 'highpass=f=75,volume=1.25,alimiter=limit=0.96:attack=0.5:release=10,afade=t=out:st=0.100:d=0.045' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/model-f-${model_f_special_names[$index]}.wav"
done
rm -rf "$vintage_audio_work"

for name in key space; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/hermes-$name.mp3" \
    -af 'silenceremove=start_periods=1:start_threshold=-48dB,atrim=duration=0.45,afade=t=out:st=0.35:d=0.10' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/hermes-$name.wav"
done

ffmpeg -hide_banner -loglevel error -y \
  -i "$project_dir/Resources/SoundSources/hermes-bell.mp3" \
  -af 'silenceremove=start_periods=1:start_threshold=-48dB,atrim=duration=1.20,afade=t=out:st=0.95:d=0.25' \
  -ar 48000 -ac 2 -c:a pcm_s16le \
  "$contents_dir/Resources/Sounds/hermes-bell.wav"

for index in {1..5}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/bubble-$index.ogg" \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/bubble-$index.wav"
done

for index in {1..8}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/musicbox-$index.mp3" \
    -t 0.55 -af 'afade=t=out:st=0.35:d=0.20' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/musicbox-$index.wav"
done

for name in kick hat snare; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/drum-$name.mp3" \
    -t 0.35 -af 'afade=t=out:st=0.22:d=0.13' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/drum-$name.wav"
done

# Onset-aligned switch recordings. Each profile keeps distinct letter/number
# variations plus dedicated space, backspace and return samples.
for profile in mx-blue holy-panda mx-brown mx-black alpaca gateron-black-ink; do
  case "$profile" in
    holy-panda) gain=1.35 ;;
    mx-brown) gain=1.25 ;;
    alpaca) gain=3.0 ;;
    gateron-black-ink) gain=1.45 ;;
    *) gain=1.0 ;;
  esac
  for sample in key1 key2 key3 key4 key5 space backspace return; do
    ffmpeg -hide_banner -loglevel error -y \
      -i "$project_dir/Resources/SoundSources/kb-$profile-$sample.mp3" \
      -af "silenceremove=start_periods=1:start_duration=0:start_threshold=-62dB:start_silence=0.001,volume=$gain,apad=pad_dur=0.18,atrim=duration=0.18,alimiter=limit=0.96:attack=0.3:release=5,afade=t=out:st=0.135:d=0.045" \
      -ar 48000 -ac 2 -c:a pcm_s16le \
      "$contents_dir/Resources/Sounds/kb-$profile-$sample.wav"
  done
done

for index in {1..5}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/developer-key.mp3" \
    -af "asetrate=48000*$((96 + index * 2))/100,aresample=48000,silenceremove=start_periods=1:start_threshold=-60dB:start_silence=0.001,apad=pad_dur=0.15,atrim=duration=0.15,afade=t=out:st=0.11:d=0.04" \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/kb-developer-key$index.wav"
done
for sample in space backspace return; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/developer-$sample.mp3" \
    -af 'silenceremove=start_periods=1:start_threshold=-60dB:start_silence=0.001,apad=pad_dur=0.18,atrim=duration=0.18,afade=t=out:st=0.135:d=0.045' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/kb-developer-$sample.wav"
done

for index in {1..3}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/chime-$index.mp3" \
    -af 'silenceremove=start_periods=1:start_threshold=-58dB:start_silence=0.002,atrim=duration=0.52,afade=t=out:st=0.34:d=0.18' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/chime-$index.wav"
done

for index in {1..7}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/casino-chip-$index.ogg" \
    -af 'silenceremove=start_periods=1:start_threshold=-58dB:start_silence=0.001,apad=pad_dur=0.19,atrim=duration=0.19,afade=t=out:st=0.145:d=0.045' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/casino-chip-$index.wav"
done

for index in {1..5}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/retro-click-$index.ogg" \
    -af 'silenceremove=start_periods=1:start_threshold=-62dB:start_silence=0.001,apad=pad_dur=0.12,atrim=duration=0.12,afade=t=out:st=0.085:d=0.035' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/retro-click-$index.wav"
done

for index in {1..6}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/spark-$index.mp3" \
    -af 'silenceremove=start_periods=1:start_threshold=-58dB:start_silence=0.001,atrim=duration=0.20,afade=t=out:st=0.14:d=0.06' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/spark-$index.wav"
done

for index in {1..2}; do
  ffmpeg -hide_banner -loglevel error -y \
    -i "$project_dir/Resources/SoundSources/quack-$index.mp3" \
    -af 'silenceremove=start_periods=1:start_threshold=-62dB:start_silence=0.001,volume=2.8,atrim=duration=0.30,alimiter=limit=0.95:attack=0.5:release=8,afade=t=out:st=0.22:d=0.08' \
    -ar 48000 -ac 2 -c:a pcm_s16le \
    "$contents_dir/Resources/Sounds/quack-$index.wav"
done

rsync -a "$project_dir/Resources/ThirdPartyNotices.txt" "$contents_dir/Resources/ThirdPartyNotices.txt"
swift "$project_dir/Scripts/make_icon.swift" "$contents_dir/Resources/TypingSounds.icns"

codesign --force --deep --sign - \
  --requirements '=designated => identifier "com.seandegan.typingsounds"' \
  "$app_dir"

echo "$app_dir"
