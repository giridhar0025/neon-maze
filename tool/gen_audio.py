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


# ---------------------------------------------------------------------------
# Background music: three short, seamlessly looped synthesised beds.
# ---------------------------------------------------------------------------

MUSIC_SR = 22050


def write_music(name, samples, peak=0.55):
    peak_now = max(1e-9, max(abs(s) for s in samples))
    norm = peak / peak_now
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32767)) for s in samples
    )
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(MUSIC_SR)
        w.writeframes(frames)


def loopify(samples, fade=0.6):
    f = int(MUSIC_SR * fade)
    n = len(samples) - f
    for i in range(f):
        t = i / f
        samples[i] = samples[i] * t + samples[n + i] * (1.0 - t)
    return samples[:n]


def note(freq, dur, amp=0.2, attack=0.02, release=0.35, harmonic=0.0):
    n = int(MUSIC_SR * dur)
    a = max(1, int(MUSIC_SR * attack))
    r = max(1, int(MUSIC_SR * release))
    out = []
    phase = 0.0
    for i in range(n):
        env = 1.0
        if i < a:
            env = i / a
        elif i > n - r:
            env = max(0.0, (n - i) / r)
        f = freq * (1.0 + 0.002 * math.sin(2 * math.pi * i / MUSIC_SR))
        phase += 2 * math.pi * f / MUSIC_SR
        s = math.sin(phase)
        if harmonic:
            s += harmonic * math.sin(phase * 2)
        out.append(s * amp * env)
    return out


def add_at(dst, src, start):
    for i, v in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += v


def menu_track():
    dur = 16.0
    out = [0.0] * int(MUSIC_SR * dur)
    chords = [
        (220.0, 261.63, 329.63),
        (174.61, 220.0, 261.63),
        (196.0, 246.94, 293.66),
        (164.81, 207.65, 246.94),
    ]
    for bar, chord in enumerate(chords):
        start = int(bar * 4.0 * MUSIC_SR)
        for f in chord:
            add_at(out, note(f, 4.2, amp=0.075, attack=0.3, release=0.8, harmonic=0.18), start)
        # slow arpeggio
        for k, f in enumerate(chord):
            add_at(out, note(f * 2, 1.4, amp=0.035, attack=0.04, release=0.5), start + int((0.4 + k * 0.9) * MUSIC_SR))
    return loopify(out)


def gameplay_track():
    dur = 12.0
    out = [0.0] * int(MUSIC_SR * dur)
    bpm = 112.0
    beat = 60.0 / bpm
    progression = [110.0, 110.0, 146.83, 130.81, 110.0, 110.0, 146.83, 164.81]
    for bar in range(8):
        start = int(bar * beat * 2 * MUSIC_SR)
        root = progression[bar]
        add_at(out, note(root / 2, beat * 1.8, amp=0.13, attack=0.01, release=0.25, harmonic=0.25), start)
        for step in range(8):
            f = root * (2 if step % 4 == 2 else 1) * (1.5 if step == 6 else 1)
            add_at(out, note(f * 2, 0.16, amp=0.045, attack=0.005, release=0.12, harmonic=0.35), start + int(step * beat / 4 * MUSIC_SR))
    return loopify(out)


def blackout_track():
    dur = 16.0
    out = [0.0] * int(MUSIC_SR * dur)
    for f, amp in [(55.0, 0.12), (82.41, 0.05), (110.0, 0.025)]:
        for i in range(int(dur * MUSIC_SR)):
            t = i / MUSIC_SR
            wobble = 1.0 + 0.006 * math.sin(2 * math.pi * 0.13 * t)
            out[i] += math.sin(2 * math.pi * f * wobble * t) * amp
    # sparse distant pings
    for i in range(8):
        start = int((1.0 + i * 1.9) * MUSIC_SR)
        add_at(out, note(660.0 * (1.0 if i % 2 == 0 else 0.75), 2.0, amp=0.04, attack=0.05, release=1.2), start)
    return loopify(out)


write_music("menu_loop.wav", menu_track())
write_music("game_loop.wav", gameplay_track())
write_music("blackout_loop.wav", blackout_track())

# Power-up acquired: rising charge shimmer.
power = mix(
    tone(523.25, 0.22, decay=3.0, harmonic=0.35),
    [0.0] * int(SR * 0.06) + tone(783.99, 0.26, decay=3.0, harmonic=0.4),
    [0.0] * int(SR * 0.12) + tone(1174.66, 0.38, decay=3.4, harmonic=0.45),
)
write("powerup.wav", power)

# Shield save: warm body hit plus a bright ding.
shield_n = int(SR * 0.45)
shield = []
for i in range(shield_n):
    t = i / SR
    body = math.sin(2 * math.pi * 150 * t) * math.exp(-8 * t) * 0.7
    ring = math.sin(2 * math.pi * 1046.5 * t) * math.exp(-6 * t) * 0.3
    shield.append(body + ring)
write("shield.wav", shield)

# Mission claim: two-step confirmation.
mission = mix(
    tone(659.25, 0.22, decay=4.0, harmonic=0.2),
    [0.0] * int(SR * 0.10) + tone(987.77, 0.42, decay=3.6, harmonic=0.25),
)
write("mission.wav", mission)

print("wrote", sorted(os.listdir(OUT)))
