#!/usr/bin/env python3
# make_sound_designs.py -- render original short sound designs before packaging.
# Created by LT Sean Egan, PhD 2026-11-04
import math
from pathlib import Path
import random
import struct
import sys
import wave

RATE = 48000
DESIGNS = (
    "mutedTypewriter", "ribbonTypewriter", "electricTypewriter", "deskTypewriter",
    "feltPiano", "marimba", "pluckedStrings", "glassBells", "waterDrops",
    "woodBlocks", "rubberBounce", "arcadeBlips", "terminalBeeps", "radarPings", "laserTicks",
)


def render(name, index):
    rng = random.Random(f"TypingSounds.original.v1.{name}.{index}")
    frequency = (261.626, 293.665, 329.628, 391.995, 440.0)[index - 1]
    duration = 0.28 if name in ("feltPiano", "glassBells", "radarPings") else 0.18
    samples = []
    for frame in range(int(RATE * duration)):
        t = frame / RATE
        sine = lambda ratio=1: math.sin(math.tau * frequency * ratio * t)
        if name == "feltPiano":
            value = (sine() + 0.28 * sine(2) + 0.09 * sine(3)) * math.exp(-20 * t)
        elif name == "marimba":
            value = (sine() * math.exp(-35*t) + 0.45*sine(4)*math.exp(-80*t))
        elif name == "pluckedStrings":
            value = sum(sine(h) * math.exp(-(15 + 9*h)*t) / h for h in range(1, 7))
        elif name == "glassBells":
            value = (sine(2) + 0.35*sine(5.36) + 0.18*sine(7.74)) * math.exp(-15*t)
        elif name == "waterDrops":
            value = math.sin(math.tau*(frequency*2*t + 2400*t*t)) * math.exp(-40*t)
        elif name == "woodBlocks":
            value = (sine(1.4) + 0.6*sine(2.13)) * math.exp(-65*t)
        elif name == "rubberBounce":
            value = math.sin(math.tau * frequency * 3 / 22 * (1-math.exp(-22*t))) * math.exp(-25*t)
        elif name == "arcadeBlips":
            phase = math.sin(math.tau*frequency*2*t)
            value = (1 if phase >= 0 else -1) * math.exp(-40*t) * (0.6 + 0.4*math.sin(math.tau*55*t))
        elif name == "terminalBeeps":
            value = sine(2.5) * math.exp(-36*t)
        elif name == "radarPings":
            value = sine(2)*math.exp(-24*t)
            if t > 0.075:
                value += 0.3*math.sin(math.tau*frequency*2*(t-0.075))*math.exp(-30*(t-0.075))
        elif name == "laserTicks":
            value = math.sin(math.tau*frequency*8/40*(1-math.exp(-40*t))) * math.exp(-40*t)
        else:
            noise = rng.uniform(-1, 1)
            tone = sine(0.8) + 0.25*sine(3.7)
            if name == "mutedTypewriter":
                value = (0.25*noise + tone)*math.exp(-90*t)
            elif name == "ribbonTypewriter":
                value = (noise + 0.35*tone)*math.exp(-65*t) + 0.15*sine(5)*math.exp(-30*t)
            elif name == "electricTypewriter":
                value = (noise + 0.3*sine(4))*math.exp(-110*t)
                if t > 0.022:
                    value += 0.6*(noise + sine(2))*math.exp(-110*(t-0.022))
            else:
                value = noise*math.exp(-95*t) + 0.4*sine(6.3)*math.exp(-38*t)
        attack = min(1.0, t / 0.0015)
        tail = min(1.0, max(0.0, (duration - t - 1/RATE) / 0.015))
        samples.append(value * attack * tail)
    peak = max(abs(value) for value in samples)
    pcm = bytearray()
    for value in samples:
        quantized = round(value / peak * 0.22 * 32767)
        pcm.extend(struct.pack("<hh", quantized, quantized))
    return pcm


def main():
    destination = Path(sys.argv[1])
    destination.mkdir(parents=True, exist_ok=True)
    for name in DESIGNS:
        for index in range(1, 6):
            with wave.open(str(destination / f"designed-{name}-{index}.wav"), "wb") as output:
                output.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
                output.writeframes(render(name, index))


if __name__ == "__main__":
    main()
