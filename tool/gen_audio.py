"""Generate original, tiny UI/SFX WAV assets for Neon Maze (no third-party samples)."""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = "/Users/pulicharagiridhar/Projects/neon-maze/assets/audio"
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = 0.82 / peak
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


def env(i, n, attack=0.01, decay=3.2):
    a = int(SR * attack)
    if i < a:
        return i / max(1, a)
    return math.exp(-decay * (i - a) / max(1, n - a))


def tone(freq, dur, decay=3.2, harmonic=0.25, glide=0.0):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = freq * (1.0 + glide * t / dur)
        phase += 2 * math.pi * f / SR
        s = math.sin(phase) + harmonic * math.sin(phase * 2) + 0.08 * math.sin(phase * 3)
        out.append(s * env(i, n, 0.004, decay))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


# Soft UI tap: short filtered click with a pitch drop.
click = tone(880, 0.07, decay=9.0, harmonic=0.15, glide=-0.35)
write("ui_tap.wav", click)

# Wall bump: low thud + noise burst.
thud_n = int(SR * 0.16)
thud = []
for i in range(thud_n):
    t = i / SR
    body = math.sin(2 * math.pi * (120 - 220 * t) * t) * math.exp(-26 * t)
    noise = (random.random() * 2 - 1) * math.exp(-55 * t) * 0.35
    thud.append(body + noise)
write("wall_bump.wav", thud)

# Orb pickup: rising two-note sparkle.
orb = mix(tone(660, 0.16, decay=7.0, harmonic=0.3), [0.0] * int(SR * 0.055) + tone(990, 0.18, decay=6.0, harmonic=0.35))
write("orb_pickup.wav", orb)

# Exit unlock / level complete: major arpeggio.
gap = [0.0] * int(SR * 0.075)
win = mix(
    tone(523.25, 0.5, decay=4.0, harmonic=0.25),
    gap + tone(659.25, 0.45, decay=4.0, harmonic=0.25),
    gap + gap + tone(783.99, 0.42, decay=4.0, harmonic=0.25),
    gap + gap + gap + tone(1046.5, 0.7, decay=3.0, harmonic=0.3),
)
write("level_clear.wav", win)

# Fall into a hole: descending "womp".
fall_n = int(SR * 0.62)
fall = []
phase = 0.0
for i in range(fall_n):
    t = i / SR
    f = 420 * math.exp(-2.4 * t)
    phase += 2 * math.pi * f / SR
    s = math.sin(phase) * 0.7 + math.sin(phase * 0.5) * 0.25
    fall.append(s * math.exp(-3.0 * t))
write("fall.wav", fall)

# Star tick: bright ping.
write("star.wav", tone(1318.5, 0.34, decay=5.0, harmonic=0.2))

print("wrote", sorted(os.listdir(OUT)))
