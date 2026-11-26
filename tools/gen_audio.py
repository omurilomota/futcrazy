#!/usr/bin/env python3
"""Gera todos os sons do FutCrazy por síntese (nenhum asset externo).

Uso:
    python3 tools/gen_audio.py

Saída: assets/audio/*.wav (mono, 22050 Hz, 16 bits).
Depois de gerar, rode `godot --headless --path . --import` para o Godot
importar os arquivos novos.
"""

import math
import os
import random
import struct
import wave

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "audio"))
TAU = math.tau

random.seed(11)


# ------------------------------------------------------------------ utilidades

def silence(dur):
    return [0.0] * int(SR * dur)


def add(dst, src, at=0.0, gain=1.0):
    i0 = int(at * SR)
    for i, s in enumerate(src):
        j = i0 + i
        if 0 <= j < len(dst):
            dst[j] += s * gain


def noise(dur):
    return [random.uniform(-1.0, 1.0) for _ in range(int(SR * dur))]


def lowpass(sig, cutoff):
    a = 1.0 - math.exp(-TAU * cutoff / SR)
    y = 0.0
    out = []
    for s in sig:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    lp = lowpass(sig, cutoff)
    return [s - l for s, l in zip(sig, lp)]


def bandpass(sig, lo, hi):
    return highpass(lowpass(sig, hi), lo)


def env(dur, attack=0.005, decay=1.0, power=2.0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        a = min(1.0, t / attack) if attack > 0.0 else 1.0
        d = math.exp(-t / decay) if decay > 0.0 else 1.0
        out.append(a * (d ** power))
    return out


def apply_env(sig, e):
    return [s * ev for s, ev in zip(sig, e)]


def sine_sweep(dur, f0, f1, curve=1.0):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * (t ** curve)
        ph += TAU * f / SR
        out.append(math.sin(ph))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, s in enumerate(p):
            out[i] += s
    return out


def normalize(sig, target=0.85):
    peak = max(1e-9, max(abs(s) for s in sig))
    return [s * target / peak for s in sig]


def write(name, sig, loop=False):
    os.makedirs(OUT, exist_ok=True)
    if loop:
        # crossfade cabeça/cauda para o loop não estalar
        n = int(0.2 * SR)
        for i in range(n):
            a = i / n
            sig[i] = sig[i] * a + sig[len(sig) - n + i] * (1.0 - a)
        sig = sig[:-n]
    sig = normalize(sig, 0.55 if loop else 0.85)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in sig
        ))
    print("  %-14s %5.2fs" % (name, len(sig) / SR))


# --------------------------------------------------------------------- efeitos

def kick():
    body = apply_env(sine_sweep(0.22, 170.0, 52.0, 0.5), env(0.22, 0.002, 0.05, 1.0))
    slap = apply_env(bandpass(noise(0.07), 900.0, 5200.0), env(0.07, 0.001, 0.012))
    return mix(body, [s * 0.7 for s in slap])


def hit():
    thud = apply_env(sine_sweep(0.34, 125.0, 40.0, 0.6), env(0.34, 0.003, 0.07, 1.0))
    crack = apply_env(bandpass(noise(0.14), 350.0, 3200.0), env(0.14, 0.001, 0.022))
    return mix(thud, [s * 0.85 for s in crack])


def bounce():
    blip = apply_env(sine_sweep(0.12, 540.0, 230.0, 0.4), env(0.12, 0.001, 0.025))
    tick = apply_env(noise(0.02), env(0.02, 0.0005, 0.004))
    return mix(blip, [s * 0.5 for s in tick])


def whoosh():
    n = noise(0.3)
    out = []
    y = 0.0
    for i, s in enumerate(n):
        t = i / len(n)
        cut = 380.0 + 2600.0 * math.sin(math.pi * t)
        a = 1.0 - math.exp(-TAU * cut / SR)
        y += a * (s - y)
        out.append(y)
    return apply_env(out, env(0.3, 0.02, 0.09, 1.0))


def whistle(dur=0.7, f=2350.0):
    n = int(SR * dur)
    tone = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        vib = 1.0 + 0.018 * math.sin(TAU * 38.0 * t)
        ph += TAU * f * vib / SR
        tone.append(math.sin(ph) + 0.35 * math.sin(ph * 2.0) + 0.08 * math.sin(ph * 3.0))
    tone = apply_env(tone, env(dur, 0.03, 0.5, 1.4))
    air = apply_env(bandpass(noise(dur), 1500.0, 6000.0), env(dur, 0.05, 0.4, 1.0))
    return mix(tone, [a * 0.22 for a in air])


def beep():
    return apply_env(sine_sweep(0.14, 900.0, 900.0), env(0.14, 0.004, 0.06, 1.0))


def ui():
    return apply_env(sine_sweep(0.09, 1400.0, 1900.0, 0.5), env(0.09, 0.002, 0.03, 1.0))


def event_chime():
    out = silence(0.78)
    for at, f in [(0.0, 523.25), (0.11, 659.25), (0.22, 880.0)]:
        tone = apply_env(sine_sweep(0.42, f, f * 1.004), env(0.42, 0.006, 0.15, 1.0))
        add(out, [s * 0.55 for s in tone], at)
    sparkle = apply_env(bandpass(noise(0.5), 3200.0, 9500.0), env(0.5, 0.02, 0.14))
    add(out, [s * 0.18 for s in sparkle], 0.2)
    return out


def goal():
    roar = apply_env(bandpass(noise(2.7), 280.0, 2400.0), env(2.7, 0.22, 0.95, 1.2))
    roar = [s * 3.2 for s in roar]
    out = silence(2.8)
    add(out, roar, 0.0)
    add(out, [s * 0.7 for s in whistle(0.55, 2460.0)], 0.04)
    return out


def slide():
    n = noise(0.34)
    out = []
    y = 0.0
    for i, s in enumerate(n):
        t = i / len(n)
        cut = 240.0 + 1500.0 * (1.0 - t)
        a = 1.0 - math.exp(-TAU * cut / SR)
        y += a * (s - y)
        out.append(y)
    body = apply_env(out, env(0.34, 0.01, 0.11, 1.0))
    gravel = apply_env(bandpass(noise(0.3), 900.0, 4200.0), env(0.3, 0.04, 0.09))
    return mix(body, [s * 0.25 for s in gravel])


def moon():
    out = silence(0.9)
    for i, f in enumerate([392.0, 523.25, 659.25, 783.99]):
        tone = apply_env(sine_sweep(0.7, f, f * 2.0, 0.7), env(0.7, 0.03, 0.22))
        add(out, [s * (0.22 - i * 0.02) for s in tone], i * 0.05)
    air = apply_env(bandpass(noise(0.9), 2500.0, 9000.0), env(0.9, 0.08, 0.3))
    add(out, [s * 0.18 for s in air], 0.0)
    return out


def rumble():
    body = apply_env(lowpass(noise(0.85), 110.0), env(0.85, 0.12, 0.35, 1.0))
    grit = apply_env(bandpass(noise(0.6), 200.0, 1200.0), env(0.6, 0.1, 0.2))
    return mix([s * 3.0 for s in body], [s * 0.5 for s in grit])


def squeak():
    out = silence(0.4)
    for i, base in enumerate([1500.0, 2100.0, 1800.0]):
        tone = apply_env(sine_sweep(0.13, base, base * 1.55, 0.5), env(0.13, 0.004, 0.05))
        add(out, [s * 0.5 for s in tone], i * 0.09)
    return out


def crowd():
    dur = 5.0
    n = int(SR * dur)
    out = []
    y_lo = 0.0
    y_mid = 0.0
    for i in range(n):
        t = i / SR
        w = random.uniform(-1.0, 1.0)
        y_lo += 0.018 * (w - y_lo)
        y_mid += 0.14 * (w - y_mid)
        lfo = 0.76 + 0.11 * math.sin(TAU * 0.4 * t) + 0.07 * math.sin(TAU * 0.8 * t + 1.1)
        voice = 0.5 + 0.5 * math.sin(TAU * 3.0 * t + 0.4 * math.sin(TAU * 0.6 * t))
        out.append((y_mid * 0.8 + y_lo * 3.4) * lfo + voice * 0.05 * random.uniform(0.5, 1.0))
    return out


SOUNDS = [
    ("kick.wav", kick, False),
    ("hit.wav", hit, False),
    ("bounce.wav", bounce, False),
    ("whoosh.wav", whoosh, False),
    ("whistle.wav", whistle, False),
    ("beep.wav", beep, False),
    ("ui.wav", ui, False),
    ("slide.wav", slide, False),
    ("moon.wav", moon, False),
    ("rumble.wav", rumble, False),
    ("squeak.wav", squeak, False),
    ("event.wav", event_chime, False),
    ("goal.wav", goal, False),
    ("crowd.wav", crowd, True),
]


def main():
    print("Gerando áudio em %s" % OUT)
    for name, fn, loop in SOUNDS:
        write(name, fn(), loop)
    print("Pronto.")


if __name__ == "__main__":
    main()
