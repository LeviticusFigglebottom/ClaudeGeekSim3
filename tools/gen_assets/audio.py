#!/usr/bin/env python3
"""audio.py -- procedural audio generator for ANTEROOM.

Renders every ambience loop and sound effect the game references into

    assets/audio/ambience/<name>.wav   seamless loops, 14-20 s, with a `smpl` loop chunk
    assets/audio/sfx/<name>.wav        one-shots

as 16-bit PCM mono at 22050 Hz. Everything is synthesised from scratch with
numpy (see ``synth.py``) and is deterministic: each sound gets its own RNG
seeded from its name, so ``--only`` regenerates identical files.

Usage (from the repository root)::

    python3 tools/gen_assets/audio.py            # everything
    python3 tools/gen_assets/audio.py --list     # show the catalogue
    python3 tools/gen_assets/audio.py --only step --only door

Loops are rendered *circularly*: events that run past the end wrap into the
start, filters and reverbs are applied as circular convolutions, oscillator
frequencies are quantised to whole cycles per loop, and the result is passed
through a short crossfade as extra insurance. The catalogue at the bottom maps
name -> (kind, generator).
"""
from __future__ import annotations

import argparse
import os
import struct
import sys
import time
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import synth as S  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AMB_DIR = os.path.join(ROOT, "assets", "audio", "ambience")
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")

SR = S.SR
AMB_PEAK_DB = -3.0
SFX_PEAK_DB = -1.0
BASE_SEED = 0x4A7E5  # "ANTEROOM"; change to re-roll every sound
LOOP_XFADE = 0.01    # seconds trimmed by the final safety crossfade

# A few ambiences are meant to sit lower than the rest.
PEAK_OVERRIDE_DB = {"static": -9.0, "hallway": -6.0}


def rng_for(name: str) -> np.random.Generator:
    """Deterministic generator per sound name."""
    return np.random.default_rng([BASE_SEED, zlib.crc32(name.encode("utf-8"))])


# ===========================================================================
# Shared building blocks
# ===========================================================================

def thump(f_start: float, f_end: float, dur: float, tau: float, attack: float = 0.002) -> np.ndarray:
    """Pitch-dropping sine thump (impact bodies, heartbeats, thuds)."""
    n = S.N(dur)
    return S.sine(S.expline(n, f_start, f_end), n) * S.perc(n, attack, tau)


def noise_burst(rng, dur: float, lo: float, hi: float, attack: float = 0.001, tau: float = 0.03,
                passes: int = 2) -> np.ndarray:
    """Band-limited white noise with a percussive envelope."""
    n = S.N(dur)
    return S.band(S.white(rng, n), lo, hi, passes=passes) * S.perc(n, attack, tau)


def click(rng, lo: float = 1500.0, hi: float = 6000.0, tau: float = 0.003, dur: float = 0.02) -> np.ndarray:
    """A tiny transient (latches, mechanisms, UI)."""
    return S.normalize(noise_burst(rng, dur, lo, hi, 0.0003, tau, passes=1), 0.0)


def clock_tick(rng, tock: bool = False) -> np.ndarray:
    """Soft mechanical clock tick (or the slightly lower 'tock')."""
    n = S.N(0.07)
    hi = 1300.0 if tock else 1900.0
    c = S.band(S.white(rng, n), hi, 6500, passes=1) * S.perc(n, 0.0004, 0.0035)
    body = S.sine(700.0 if tock else 950.0, n) * S.perc(n, 0.001, 0.010)
    return S.normalize(c + 0.6 * body, 0.0)


def ticking(rng, n: int, period: float, alternate: bool = True, jitter_db: float = 1.0) -> np.ndarray:
    """A tick every ``period`` seconds across a circular buffer of ``n`` samples."""
    out = S.zeros(n)
    dur = n / SR
    k = 0
    t = 0.0
    while t < dur - 1e-6:
        S.place(out, clock_tick(rng, tock=alternate and k % 2 == 1), t,
                gain=S.db(rng.uniform(-jitter_db, 0.0)), wrap=True)
        t += period
        k += 1
    return out


def drip(rng, f: float = 1600.0, dur: float = 0.35) -> np.ndarray:
    """Water drip: a 'plip' (rising bubble chirp) with a dropping tail."""
    n = S.N(dur)
    chirp = S.sine(S.expline(n, f * 0.75, f * 1.35), n) * S.perc(n, 0.0008, 0.018)
    tail = S.sine(S.expline(n, f * 1.2, f * 0.9), n) * S.perc(n, 0.004, 0.05)
    tick = noise_burst(rng, 0.004, 2500, 8000, 0.0002, 0.0012, passes=1)
    out = chirp + 0.5 * tail
    out[:len(tick)] += 0.25 * tick
    return S.normalize(out, 0.0)


def creak(rng, dur: float = 0.7, f_lo: float = 30.0, f_hi: float = 110.0, res: float = 1500.0,
          q: float = 9.0, wood: float = 260.0) -> np.ndarray:
    """Stick-slip creak: a pulse train whose rate rises and falls, ringing a
    resonance (``res``) plus a wooden body (``wood``)."""
    n = S.N(dur)
    t = S.t_axis(n)
    hump = np.sin(np.pi * t / dur) ** 0.7
    rate = f_lo * (f_hi / f_lo) ** hump * (1.0 + 0.15 * S.random_lfo(rng, n, 6.0))
    pulses = S.pulse_train(rate, n, rng, jitter=0.5)
    body = (S.bandpass(pulses, res, q=q) + 0.5 * S.bandpass(pulses, res * 1.9, q=q * 1.5)
            + 0.9 * S.bandpass(pulses, wood, q=3.0))
    env = S.adsr(n, 0.12 * dur, 0.1 * dur, 0.8, 0.3 * dur, curve=2.0)
    return S.normalize(body * env, 0.0)


def crackle(rng, n: int, rate: float = 14.0, circular: bool = True) -> np.ndarray:
    """Fire crackle: sparse ticks plus rarer low pops."""
    ticks = S.bandpass(S.impulses(rng, n, rate, shape=3.0), 3200, q=1.6, circular=circular)
    ticks += 0.6 * S.bandpass(S.impulses(rng, n, rate * 0.6, shape=2.5), 5200, q=2.0, circular=circular)
    pops = S.lowpass(S.impulses(rng, n, rate * 0.12, shape=1.5), 500, q=2.5, circular=circular)
    return S.normalize(ticks + 4.0 * pops, 0.0)


def fire(rng, n: int, circular: bool = True) -> np.ndarray:
    """Fire bed: low roar with turbulence, mid hiss and crackle (RMS ~ -20 dB)."""
    roar = S.band(S.pink(rng, n), 60, 350, circular=circular)
    roar *= 0.6 + 0.4 * S.random_lfo(rng, n, 2.5, periodic=circular)
    hiss = S.band(S.pink(rng, n), 400, 2500, circular=circular)
    hiss *= 0.5 + 0.5 * S.random_lfo(rng, n, 1.5, periodic=circular)
    return S.mix((S.set_rms(roar, -20.0), 0), (S.set_rms(hiss, -30.0), 0),
                 (S.normalize(crackle(rng, n, 14.0, circular), -14.0), 0))


def wind(rng, n: int, lo: float = 150.0, hi: float = 1200.0, res=(250.0, 700.0), q: float = 8.0,
         swell_rate: float = 0.1, depth: float = 0.6, circular: bool = True) -> np.ndarray:
    """Wind bed (RMS ~ -20 dB): band-limited pink noise with gusty swells and a
    slowly wandering resonance."""
    base = S.band(S.pink(rng, n), lo, hi, circular=circular)
    fc = res[0] * (res[1] / res[0]) ** (0.5 + 0.5 * S.random_lfo(rng, n, 0.15, periodic=circular))
    whistle = S.stft_filter(S.white(rng, n), "bp", fc, q=q, circular=circular)
    swell = (1.0 - depth) + depth * (0.5 + 0.5 * S.random_lfo(rng, n, swell_rate, periodic=circular))
    swell = swell ** 1.5
    return S.set_rms(base, -20.0) * swell + S.set_rms(whistle, -29.0) * swell ** 2


def hum(rng, n: int, f0: float, partials, wobble: float = 0.06, thin_below: float | None = None) -> np.ndarray:
    """Mains-style hum. ``partials`` = [(harmonic, amplitude), ...]. The
    fundamental is quantised to the loop so the hum is seamless."""
    f = S.loop_freq(f0, n)
    out = S.zeros(n)
    for k, amp in partials:
        flicker = 1.0 + 0.15 * S.random_lfo(rng, n, 7.0, periodic=True)
        out += amp * S.sine(f * k, n, rng.random()) * flicker
    out *= 1.0 + wobble * S.random_lfo(rng, n, 0.4, periodic=True)
    if thin_below:
        out = S.highpass(out, thin_below, circular=True)
    return S.normalize(out, 0.0)


def fluorescent(rng, n: int, f0: float = 60.0, thin: bool = True) -> np.ndarray:
    """Fluorescent tube buzz: 60 Hz series with strong even harmonics."""
    parts = [(k, (1.0 if k % 2 == 0 else 0.55) / k ** 0.8) for k in range(1, 16)]
    buzz = hum(rng, n, f0, parts, wobble=0.04, thin_below=100.0 if thin else None)
    buzz = S.lowpass(buzz, 3500, circular=True)
    # occasional micro-dropouts (the tube 'thinking')
    drop = 1.0 - 0.35 * np.clip(S.random_lfo(rng, n, 1.3, periodic=True) - 0.55, 0, 1) / 0.45
    return S.normalize(buzz * drop, 0.0)


CHURCH_PARTIALS = [
    (0.5, 0.55, 7.0), (1.0, 1.0, 5.5), (1.2, 0.6, 3.6), (1.5, 0.45, 2.8), (2.0, 0.8, 2.4),
    (2.5, 0.3, 1.6), (2.67, 0.2, 1.3), (3.0, 0.25, 1.1), (4.0, 0.12, 0.7), (5.4, 0.08, 0.5),
]


def church_bell(rng, f0: float = 196.0, dur: float = 7.0, decay_scale: float = 1.0,
                strike: float = 0.5) -> np.ndarray:
    """Inharmonic church bell with a strike transient."""
    n = S.N(dur)
    parts = [(r, a, d * decay_scale) for r, a, d in CHURCH_PARTIALS]
    b = S.bell(f0, n, parts, beat=0.6, rng=rng)
    if strike > 0:
        hit = noise_burst(rng, 0.03, 700, 5000, 0.0005, 0.006)
        b[:len(hit)] += strike * hit
    return S.normalize(b, 0.0)


def metallic(rng, dur: float = 0.4, f_base: float = 2500.0, n_parts: int = 5, decay: float = 0.25,
             strike: float = 0.6) -> np.ndarray:
    """Inharmonic metallic hit (chains, mugs, coins, levers)."""
    n = S.N(dur)
    ratios = np.cumprod(np.concatenate([[1.0], rng.uniform(1.25, 1.55, n_parts - 1)]))
    parts = [(float(r), float(0.9 ** i * rng.uniform(0.6, 1.0)), float(decay * 0.65 ** i * rng.uniform(0.7, 1.3)))
             for i, r in enumerate(ratios)]
    b = S.bell(f_base, n, parts, beat=rng.uniform(1.0, 4.0), rng=rng)
    hit = noise_burst(rng, 0.012, 1500, 8000, 0.0003, 0.003, passes=1)
    b[:len(hit)] += strike * hit
    return S.normalize(b, 0.0)


def growl(rng, dur: float = 2.0, f0: float = 32.0) -> np.ndarray:
    """Deep beast growl: jittery low pulse train through throat formants."""
    n = S.N(dur)
    t = S.t_axis(n)
    contour = f0 * (1.0 + 0.3 * np.sin(np.pi * t / dur)) * (1.0 + 0.08 * S.random_lfo(rng, n, 6.0))
    src = S.lp1(S.pulse_train(contour, n, rng, jitter=0.35), 900)
    voice = S.formant(src, (230, 560, 1350), q=(5, 6, 7), gains=(1.0, 0.6, 0.25))
    rasp = S.band(S.white(rng, n), 300, 2500) * (0.5 + 0.5 * S.random_lfo(rng, n, 30.0))
    env = S.adsr(n, 0.22 * dur, 0.1 * dur, 0.8, 0.35 * dur, curve=2.5)
    trem = 1.0 - 0.3 * (0.5 + 0.5 * S.lfo(n, 21.0))
    out = (S.normalize(voice, 0.0) + 0.22 * S.normalize(rasp, 0.0)) * env * trem
    out = S.lowpass(S.drive(out, 2.5), 2500)
    return S.normalize(out, 0.0)


def whisper(rng, dur: float = 1.5, rate: float = 5.0, circular: bool = False, frame: int = 1024) -> np.ndarray:
    """Unintelligible whisper: noise through two wandering formants, gated at
    syllable rate."""
    n = S.N(dur)
    w = S.white(rng, n)
    f1 = 300.0 * 3.0 ** (0.5 + 0.5 * S.random_lfo(rng, n, 3.0, periodic=circular))
    f2 = 1200.0 * 2.3 ** (0.5 + 0.5 * S.random_lfo(rng, n, 2.5, periodic=circular))
    v = (S.stft_filter(w, "bp", f1, q=6.0, frame=frame, circular=circular)
         + 0.7 * S.stft_filter(w, "bp", f2, q=8.0, frame=frame, circular=circular)
         + 0.15 * S.band(w, 3000, 7000, circular=circular))
    syl = np.clip(S.random_lfo(rng, n, rate, periodic=circular), 0.0, 1.0) ** 0.7
    return S.normalize(S.hp1(v * syl, 200, circular=circular), 0.0)


def murmur_voice(rng, n: int, f0: float, circular: bool = True) -> np.ndarray:
    """One distant talker: buzzy pulse source, morphing vowels, syllables, phrases."""
    f = f0 * 2.0 ** (0.35 * S.random_lfo(rng, n, 3.0, periodic=circular)) * (1.0 + 0.008 * S.lfo(n, S.loop_freq(5.5, n)))
    src = S.lp1(S.pulse_train(f, n, rng, jitter=0.1), 700, circular=circular)
    vowels = [S.formant(src, S.VOWELS[v], q=8.0, gains=(1.0, 0.5, 0.2), circular=circular) for v in "aoeu"]
    weights = [np.clip(S.random_lfo(rng, n, 3.5, periodic=circular), 0.0, 1.0) ** 2 for _ in vowels]
    tot = sum(weights) + 1e-6
    voice = sum(w * v for w, v in zip(weights, vowels)) / tot
    syl = np.clip(S.random_lfo(rng, n, 4.5, periodic=circular), 0.0, 1.0)
    phrase = np.clip(S.random_lfo(rng, n, 0.35, periodic=circular) + 0.3, 0.0, 1.0)
    return S.normalize(voice * syl * phrase, 0.0)


def phone_ring(rng, dur: float = 1.5, f1: float = 1450.0, f2: float = 1850.0, ring_len: float = 1.0) -> np.ndarray:
    """Mechanical telephone ringer: two small bells struck alternately at 20 Hz."""
    n = S.N(dur)
    out = S.zeros(n)
    bells = [S.bell(f, S.N(0.12), [(1.0, 1.0, 0.05), (2.7, 0.4, 0.03), (4.1, 0.2, 0.02)], rng=rng) for f in (f1, f2)]
    k = 0
    for t in np.arange(0.0, ring_len, 0.05):
        S.place(out, bells[k % 2], t, gain=0.9 + 0.1 * rng.random())
        k += 1
    return S.normalize(out, 0.0)


def heartbeat_pair(rng, gap: float = 0.19) -> np.ndarray:
    """One 'lub-dub'."""
    out = S.zeros(S.N(0.7))
    S.place(out, thump(70, 42, 0.22, 0.06, attack=0.012), 0.0)
    S.place(out, thump(60, 38, 0.2, 0.05, attack=0.01), gap, gain=0.75)
    return S.normalize(S.lowpass(out, 220), 0.0)


def stone_grind(rng, dur: float = 2.0, thud: bool = True) -> np.ndarray:
    """Heavy stone sliding on stone."""
    n = S.N(dur)
    grit = S.band(S.impulses(rng, n, 400.0, shape=1.0), 150, 2500)
    rumble = S.band(S.pink(rng, n), 30, 200) * (0.6 + 0.4 * S.random_lfo(rng, n, 8.0))
    drag_fc = 180.0 * 2.0 ** (0.5 * S.random_lfo(rng, n, 2.0))
    drag = S.stft_filter(S.white(rng, n), "bp", drag_fc, q=12.0)
    env = S.adsr(n, 0.15 * dur, 0.1 * dur, 0.85, 0.2 * dur, curve=2.0)
    rough = 0.7 + 0.3 * S.random_lfo(rng, n, 12.0)
    out = (S.normalize(grit, -3.0) + S.normalize(rumble, 0.0) + S.normalize(drag, -6.0)) * env * rough
    if thud:
        S.place(out, thump(80, 40, 0.3, 0.08), dur - 0.3, gain=1.2)
    return S.normalize(S.lowpass(out, 3000), 0.0)


def step_core(rng, dur: float, thump_f=(110.0, 60.0), thump_tau: float = 0.05, thump_gain: float = 1.0,
              noise_lo: float = 300.0, noise_hi: float = 3000.0, noise_tau: float = 0.04,
              noise_gain: float = 1.0, click_gain: float = 0.0) -> np.ndarray:
    """Generic footstep: body thump + surface noise + optional transient click."""
    n = S.N(dur)
    th = S.sine(S.expline(n, thump_f[0], thump_f[1]), n) * S.perc(n, 0.002, thump_tau)
    nz = S.band(S.white(rng, n), noise_lo, noise_hi) * S.perc(n, 0.001, noise_tau)
    ck = S.band(S.white(rng, n), 2000, 7000, passes=1) * S.perc(n, 0.0003, 0.002)
    return thump_gain * th + noise_gain * nz + click_gain * ck


def sparkle(rng, dur: float, lo: float = 3000.0, hi: float = 9000.0, count: int = 24,
            decay: float = 0.08, rise: bool = False) -> np.ndarray:
    """Cloud of tiny high sine 'tings' (magic shimmer, glass)."""
    n = S.N(dur)
    out = S.zeros(n)
    for i in range(count):
        u = rng.random()
        f = lo * (hi / lo) ** (u if not rise else 0.3 * u + 0.7 * i / count)
        m = S.N(decay * 4)
        tone = S.sine(f, m, rng.random()) * S.perc(m, 0.001, decay * rng.uniform(0.5, 1.5))
        at = rng.uniform(0.0, max(dur - decay, 0.01)) if not rise else i / count * (dur - decay)
        S.place(out, tone, at, gain=rng.uniform(0.3, 1.0))
    return S.normalize(out, 0.0)


def chord_pad(rng, n: int, freqs, shape: str = "sine", voices: int = 3, spread: float = 6.0,
              vib_rate=(0.12, 0.35), vib_depth: float = 0.003) -> np.ndarray:
    """Slow chorused pad: each note is a detuned unison with its own loop-safe vibrato."""
    out = S.zeros(n)
    for f in freqs:
        rate = S.loop_freq(rng.uniform(*vib_rate), n)
        vib = 1.0 + vib_depth * S.lfo(n, rate, phase0=rng.random())
        out += S.detuned(shape, S.loop_freq(f, n) * vib, n, voices=voices, spread_cents=spread, rng=rng)
    return S.normalize(out, 0.0)


# ===========================================================================
# Ambience loops (all circular; length in seconds is fixed per loop)
# ===========================================================================

def amb_apartment(rng):
    """Rain on the window, fridge hum, a ticking clock, far traffic."""
    dur = 16.0
    n = S.N(dur)
    swell = 0.65 + 0.35 * S.random_lfo(rng, n, 0.12, periodic=True)
    hiss = S.band(S.pink(rng, n), 600, 4000, circular=True) * swell
    drops = S.impulses(rng, n, 25.0, shape=2.5)
    drops = (S.bandpass(drops, 2600, q=2.0, circular=True) + 0.7 * S.bandpass(drops, 1300, q=3.0, circular=True)) * swell
    rain = S.set_rms(hiss, -27.0) + S.normalize(drops, -19.0)
    fridge = hum(rng, n, 50.0, [(1, 1.0), (2, 0.35), (3, 0.2), (4, 0.08), (6, 0.04)], wobble=0.08)
    fridge = S.set_rms(fridge, -35.0)
    clock = S.reverb(ticking(rng, n, 1.0), rt60=0.5, size=0.4, wet=0.25, circular=True)
    traffic = S.band(S.pink(rng, n), 40, 260, circular=True) * (0.6 + 0.4 * S.random_lfo(rng, n, 0.08, periodic=True))
    S.place(traffic, S.band(S.pink(rng, S.N(4.0)), 60, 400) * S.bump(S.N(4.0), 2.0, 4.0), 9.0, gain=0.8, wrap=True)
    return S.mix(rain, fridge, (S.normalize(clock, -16.0), 0), (S.set_rms(traffic, -33.0), 0))


def amb_corridor(rng):
    """Fluorescent buzz, stairwell wind, one far door slam."""
    dur = 16.0
    n = S.N(dur)
    buzz = S.set_rms(fluorescent(rng, n), -31.0)
    w = wind(rng, n, 200, 1400, res=(300.0, 900.0), q=10.0, swell_rate=0.12, depth=0.7)
    w = S.reverb(w, rt60=1.8, size=1.2, wet=0.35, tone=3000, circular=True)
    w = S.set_rms(w, -25.0)
    room = S.set_rms(S.band(S.pink(rng, n), 30, 140, circular=True), -36.0)
    slam = S.zeros(n)
    door = S.zeros(S.N(0.6))
    S.place(door, thump(95, 45, 0.3, 0.07, attack=0.003), 0.0)
    S.place(door, noise_burst(rng, 0.3, 80, 700, 0.002, 0.045), 0.0, gain=0.7)
    S.place(door, click(rng, 1500, 5000, 0.006), 0.06, gain=0.5)
    S.place(slam, S.lowpass(door, 1200), 10.3)
    slam = S.reverb(slam, rt60=3.5, size=1.8, damp=0.4, wet=0.9, tone=2500, circular=True)
    return S.mix(buzz, w, room, (S.normalize(slam, -7.0), 0))


def amb_hallway(rng):
    """Near-silence: sub rumble, one deep growl, a wood creak or two."""
    dur = 18.0
    n = S.N(dur)
    f1, f2 = S.loop_freq(33.0, n), S.loop_freq(38.0, n)
    swell = (0.5 + 0.5 * S.lfo(n, S.loop_freq(1.0 / 9.0, n), phase0=0.75)) ** 1.5
    rumble = (S.sine(f1, n) + 0.8 * S.sine(f2, n) + 0.25 * S.sine(2 * f1, n)) * swell
    rumble = S.set_rms(rumble, -22.0)
    g = S.zeros(n)
    S.place(g, growl(rng, 2.4, 30.0), 7.0)
    g = S.reverb(g, rt60=4.0, size=2.0, damp=0.4, wet=0.9, tone=2000, circular=True)
    cr = S.zeros(n)
    for t in S.event_times(rng, dur, 2, min_gap=3.0):
        S.place(cr, creak(rng, rng.uniform(0.5, 0.9), 30, 100), t, gain=rng.uniform(0.6, 1.0), wrap=True)
    cr = S.reverb(S.lowpass(cr, 3000), rt60=2.5, size=1.4, wet=0.6, tone=2500, circular=True)
    tone = S.set_rms(S.band(S.pink(rng, n), 2000, 7000, circular=True), -52.0)
    return S.mix(rumble, (S.normalize(g, -9.0), 0), (S.normalize(cr, -20.0), 0), tone)


def amb_nexus(rng):
    """Cavernous drone, minor pad, dripping water, faint choir."""
    dur = 20.0
    n = S.N(dur)
    drone = S.zeros(n)
    for f, a in ((55.0, 1.0), (55.35, 0.8), (110.0, 0.5), (110.6, 0.4), (82.5, 0.25), (27.5, 0.3)):
        drone += a * S.sine(S.loop_freq(f, n), n, rng.random()) * (0.8 + 0.2 * S.lfo(n, S.loop_freq(rng.uniform(0.05, 0.15), n), phase0=rng.random()))
    drone = S.set_rms(drone, -22.0)
    pad = chord_pad(rng, n, (110.0, 130.81, 164.81), voices=3, spread=6.0)
    pad = S.band(pad, 80, 1200, circular=True) * (0.6 + 0.4 * S.random_lfo(rng, n, 0.07, periodic=True))
    pad = S.set_rms(S.reverb(pad, rt60=5.0, size=2.2, wet=0.8, tone=2500, circular=True), -28.0)
    drips = S.zeros(n)
    for t in S.event_times(rng, dur, 6, min_gap=1.2):
        S.place(drips, drip(rng, rng.uniform(900.0, 2200.0)), t, gain=rng.uniform(0.4, 1.0), wrap=True)
    drips = S.reverb(drips, rt60=6.0, size=2.5, damp=0.35, wet=1.2, predelay=0.04, tone=4000, circular=True)
    choir = S.zeros(n)
    for f in (220.0, 261.63, 329.63, 440.0, 659.25):
        vib = 1.0 + 0.004 * S.lfo(n, S.loop_freq(rng.uniform(4.5, 6.0), n), phase0=rng.random())
        sw = (0.5 + 0.5 * S.random_lfo(rng, n, 0.06, periodic=True)) ** 2
        choir += S.detuned("sine", S.loop_freq(f, n) * vib, n, voices=3, spread_cents=7.0, rng=rng) * sw
    choir = S.formant(choir, (450, 900, 2400), q=(4, 5, 6), gains=(1.0, 0.7, 0.2), circular=True)
    choir = S.set_rms(S.reverb(choir, rt60=6.0, size=2.5, wet=1.0, tone=3000, circular=True), -31.0)
    return S.mix(drone, pad, (S.normalize(drips, -11.0), 0), choir)


def cricket_trill(rng, f: float, pulses: int = 8, pulse_rate: float = 30.0) -> np.ndarray:
    """One cricket trill: a burst of very short chirps at ``f`` Hz."""
    dur = pulses / pulse_rate
    n = S.N(dur)
    env = 0.5 - 0.5 * np.cos(S.TWO_PI * S.phasor(pulse_rate, n))
    env = env ** 3 * (0.5 - 0.5 * np.cos(S.TWO_PI * S.t_axis(n) / dur)) ** 0.3
    return S.normalize(S.sine(f, n) * env, 0.0)


def amb_forest(rng):
    """Wind in leaves, crickets, one owl, a creak."""
    dur = 18.0
    n = S.N(dur)
    leaves = S.band(S.pink(rng, n), 600, 3500, circular=True)
    slow = (0.5 + 0.5 * S.random_lfo(rng, n, 0.15, periodic=True)) ** 1.7
    flutter = 0.75 + 0.25 * S.random_lfo(rng, n, 6.0, periodic=True)
    leaves = S.set_rms(leaves * slow * flutter, -27.0)
    low = S.set_rms(S.band(S.pink(rng, n), 150, 600, circular=True) * slow, -32.0)
    crick = S.zeros(n)
    for f, period, pulses in ((4300.0, 0.9, 8), (4700.0, 1.2, 10), (5100.0, 1.5, 6)):
        trill = cricket_trill(rng, f, pulses)
        k = int(round(dur / period))
        for i in range(k):
            S.place(crick, trill, i * (dur / k) + rng.uniform(0.0, 0.05), gain=rng.uniform(0.7, 1.0), wrap=True)
    crick = S.lowpass(crick, 6000, circular=True)
    owl = S.zeros(S.N(1.4))
    for at, f0, f1 in ((0.0, 430.0, 370.0), (0.5, 400.0, 340.0)):
        m = S.N(0.42)
        fr = S.expline(m, f0, f1)
        hoo = (S.sine(fr, m) + 0.25 * S.sine(2 * fr, m)) * S.adsr(m, 0.07, 0.05, 0.85, 0.12)
        breath = S.band(S.white(rng, m), 300, 900) * S.adsr(m, 0.05, 0.1, 0.5, 0.1)
        S.place(owl, hoo + 0.1 * breath, at)
    owl_layer = S.zeros(n)
    S.place(owl_layer, S.lowpass(owl, 1500), 11.0)
    owl_layer = S.reverb(owl_layer, rt60=1.8, size=1.5, wet=0.6, tone=2000, circular=True)
    cr = S.zeros(n)
    S.place(cr, creak(rng, 0.8, 35, 90), 4.0)
    cr = S.reverb(S.lowpass(cr, 2500), rt60=1.5, size=1.2, wet=0.4, circular=True)
    return S.mix(leaves, low, (S.normalize(crick, -18.0), 0), (S.normalize(owl_layer, -14.0), 0),
                 (S.normalize(cr, -22.0), 0))


def amb_city(rng):
    """Hollow wind, a distant bell twice, a flapping banner, shifting grit."""
    dur = 20.0
    n = S.N(dur)
    w = wind(rng, n, 120, 1500, res=(180.0, 420.0), q=6.0, swell_rate=0.09, depth=0.7)
    gust = (0.5 + 0.5 * S.random_lfo(rng, n, 0.09, periodic=True)) ** 2
    w = S.set_rms(S.reverb(w, rt60=1.5, size=1.6, wet=0.3, circular=True), -24.0)
    bells = S.zeros(n)
    for t in (3.0, 13.0):
        S.place(bells, church_bell(rng, 196.0, 8.0), t, wrap=True)
    bells = S.lowpass(bells, 2200, circular=True)
    bells = S.reverb(bells, rt60=4.0, size=2.0, wet=0.7, tone=2000, circular=True)
    banner = S.zeros(n)
    flap = lambda: noise_burst(rng, rng.uniform(0.04, 0.07), 300, 2500, 0.002, 0.018)
    t = 0.0
    while t < dur:
        if rng.random() < 0.6:
            for _ in range(rng.integers(3, 8)):
                S.place(banner, flap(), t, gain=rng.uniform(0.4, 1.0), wrap=True)
                t += rng.uniform(0.09, 0.2)
        t += rng.uniform(0.6, 2.2)
    banner = banner * (0.3 + 0.7 * gust)
    grit = S.band(S.impulses(rng, n, 30.0 * (0.4 + 0.6 * gust), shape=3.0), 1500, 6000, circular=True)
    grit = grit * (0.3 + 0.7 * gust)
    return S.mix(w, (S.normalize(bells, -10.0), 0), (S.normalize(banner, -18.0), 0), (S.normalize(grit, -26.0), 0))


def amb_tavern(rng):
    """Fire, murmuring patrons, a slow lute phrase in D minor, a mug clink."""
    dur = 16.0
    n = S.N(dur)
    hearth = S.set_rms(fire(rng, n), -24.0)
    voices = S.zeros(n)
    for f0 in (95.0, 115.0, 140.0, 180.0, 215.0):
        voices += murmur_voice(rng, n, f0) * rng.uniform(0.6, 1.0)
    voices = S.lowpass(voices, 2200, circular=True)
    voices = S.set_rms(S.reverb(voices, rt60=1.2, size=1.0, wet=0.5, tone=2500, circular=True), -30.0)
    phrase = [(293.66, 2.0), (349.23, 2.0), (329.63, 1.5), (293.66, 2.5),
              (220.0, 2.0), (261.63, 2.0), (233.08, 1.5), (220.0, 2.5)]
    lute = S.zeros(n)
    t = 0.0
    for f, d in phrase:
        note = S.karplus_strong(rng, f, S.N(3.5), decay=0.9965, damp=0.5, brightness=3500) * S.decay_env(S.N(3.5), 1.6)
        S.place(lute, note, t, gain=rng.uniform(0.7, 1.0), wrap=True)
        t += d
    for t in (0.0, 8.0):
        bass = S.karplus_strong(rng, 146.83, S.N(5.0), decay=0.998, damp=0.5, brightness=2000) * S.decay_env(S.N(5.0), 2.5)
        S.place(lute, bass, t, gain=0.6, wrap=True)
    lute = S.peak_eq(S.lowpass(lute, 4000, circular=True), 250, q=1.5, gain_db=4.0, circular=True)
    lute = S.reverb(lute, rt60=1.0, size=0.9, wet=0.3, circular=True)
    clink = S.zeros(n)
    for t in S.event_times(rng, dur, 2, min_gap=4.0):
        S.place(clink, metallic(rng, 0.35, rng.uniform(2200.0, 3200.0), 4, 0.18), t, gain=rng.uniform(0.5, 1.0), wrap=True)
    clink = S.reverb(clink, rt60=0.9, size=0.8, wet=0.4, circular=True)
    return S.mix(hearth, voices, (S.normalize(lute, -13.0), 0), (S.normalize(clink, -20.0), 0))


def amb_house(rng):
    """House hum, ticking clock, a pipe knock, a muffled TV in another room."""
    dur = 16.0
    n = S.N(dur)
    h = S.set_rms(hum(rng, n, 60.0, [(1, 1.0), (2, 0.3), (3, 0.1)], wobble=0.05), -36.0)
    room = S.set_rms(S.band(S.pink(rng, n), 25, 110, circular=True), -37.0)
    clock = S.reverb(ticking(rng, n, 1.0, alternate=True), rt60=0.7, size=0.6, wet=0.3, circular=True)
    knock = S.zeros(n)
    t = rng.uniform(3.0, 6.0)
    for _ in range(rng.integers(2, 5)):
        hit = thump(160, 90, 0.15, 0.04) + 0.5 * S.normalize(S.bandpass(S.impulse(S.N(0.15)), 900, q=12.0), 0.0) * S.decay_env(S.N(0.15), 0.06)
        S.place(knock, hit, t, gain=rng.uniform(0.6, 1.0), wrap=True)
        t += rng.uniform(0.18, 0.45)
    knock = S.reverb(S.lowpass(knock, 900, circular=True), rt60=1.2, size=1.0, wet=0.5, circular=True)
    tv = murmur_voice(rng, n, 130.0) + 0.8 * murmur_voice(rng, n, 200.0)
    tv = S.set_rms(S.lowpass(tv, 550, passes=2, circular=True), -35.0)
    return S.mix(h, room, (S.normalize(clock, -16.0), 0), (S.normalize(knock, -16.0), 0), tv)


def amb_castle(rng):
    """Cold stone wind, heavy clockwork every 2 s, creaking gears, a low drone."""
    dur = 16.0
    n = S.N(dur)
    w = wind(rng, n, 120, 900, res=(170.0, 260.0), q=6.0, swell_rate=0.08, depth=0.65)
    w = S.set_rms(S.reverb(w, rt60=2.5, size=1.8, wet=0.4, tone=2500, circular=True), -25.0)
    clock = S.zeros(n)
    for i in range(8):
        clunk = S.zeros(S.N(0.5))
        S.place(clunk, thump(90, 55, 0.25, 0.06, attack=0.003), 0.0)
        S.place(clunk, noise_burst(rng, 0.03, 700, 2500, 0.0005, 0.006), 0.0, gain=0.5)
        S.place(clunk, click(rng, 1200, 4000, 0.004), 0.12, gain=0.35)
        S.place(clock, clunk, i * 2.0, gain=rng.uniform(0.85, 1.0), wrap=True)
    clock = S.reverb(clock, rt60=2.8, size=1.8, damp=0.4, wet=0.6, tone=3000, circular=True)
    gears = S.zeros(n)
    for t in S.event_times(rng, dur, 3, min_gap=2.5):
        S.place(gears, creak(rng, rng.uniform(0.9, 1.6), 20, 70, res=rng.uniform(500.0, 800.0), q=12, wood=140), t,
                gain=rng.uniform(0.5, 1.0), wrap=True)
    gears = S.reverb(S.lowpass(gears, 1500, circular=True), rt60=3.0, size=2.0, wet=0.8, tone=1800, circular=True)
    drone = (S.sine(S.loop_freq(49.0, n), n) + 0.5 * S.sine(S.loop_freq(73.4, n), n, 0.3)
             + 0.3 * S.sine(S.loop_freq(98.3, n), n, 0.6)) * (0.7 + 0.3 * S.random_lfo(rng, n, 0.05, periodic=True))
    return S.mix(w, (S.normalize(clock, -12.0), 0), (S.normalize(gears, -22.0), 0), (S.set_rms(drone, -30.0), 0))


def amb_sea(rng):
    """Shimmering maj7 pad, slow wave swells, sparse glassy bells."""
    dur = 16.0
    n = S.N(dur)
    pad = chord_pad(rng, n, (130.81, 164.81, 196.0, 246.94, 293.66, 261.63), voices=3, spread=5.0,
                    vib_rate=(0.1, 0.35), vib_depth=0.003)
    pad = S.band(pad, 120, 4000, circular=True) * (0.7 + 0.3 * S.lfo(n, S.loop_freq(1.0 / 16.0, n)))
    pad = S.set_rms(S.reverb(pad, rt60=5.0, size=2.0, wet=0.7, tone=4000, circular=True), -22.0)
    t = S.t_axis(n)
    phase = 0.5 - 0.5 * np.cos(S.TWO_PI * t / 8.0)
    surge = S.band(S.pink(rng, n), 40, 220, circular=True) * phase ** 2.5
    wash = S.band(S.pink(rng, n), 300, 1500, circular=True) * np.roll(phase ** 2, S.N(0.6))
    spray = S.band(S.pink(rng, n), 1500, 6000, circular=True) * np.roll(phase ** 3, S.N(1.2))
    waves = S.set_rms(surge, -24.0) + S.set_rms(wash, -27.0) + S.set_rms(spray, -33.0)
    bells = S.zeros(n)
    for tt in S.event_times(rng, dur, 5, min_gap=1.5):
        f = rng.choice([659.25, 783.99, 987.77, 1174.66, 1567.98])
        m = S.N(1.2)
        tone = S.fm(f, 2.01, 0.6 * np.exp(-S.t_axis(m) / 0.15), m) * S.perc(m, 0.002, 0.3)
        S.place(bells, tone, tt, gain=rng.uniform(0.4, 1.0), wrap=True)
    bells = S.reverb(bells, rt60=4.0, size=2.0, wet=1.0, tone=5000, circular=True)
    out = S.mix(pad, waves, (S.normalize(bells, -16.0), 0))
    return S.lowpass(out, 6500, circular=True)


def rattle(rng, dur: float = 0.35) -> np.ndarray:
    """Dry bony rattle."""
    n = S.N(dur)
    rate = 25.0 * 2.0 ** S.random_lfo(rng, n, 10.0)
    imp = S.pulse_train(rate, n, rng, jitter=0.6)
    body = (S.bandpass(imp, 2600, q=3.0) + 0.5 * S.bandpass(imp, 1200, q=4.0) + 0.4 * S.lowpass(imp, 400, q=2.0))
    return S.normalize(body * S.adsr(n, 0.02, 0.1, 0.6, 0.15), 0.0)


def amb_catacombs(rng):
    """Big-reverb drips, a very low drone, dry rattles, whispers."""
    dur = 18.0
    n = S.N(dur)
    drips = S.zeros(n)
    for t in S.event_times(rng, dur, 7, min_gap=1.0):
        S.place(drips, drip(rng, rng.uniform(600.0, 2200.0)), t, gain=rng.uniform(0.4, 1.0), wrap=True)
        if rng.random() < 0.35:
            S.place(drips, drip(rng, rng.uniform(600.0, 2200.0)), t + rng.uniform(0.12, 0.3), gain=0.6, wrap=True)
    drips = S.reverb(drips, rt60=7.0, size=2.6, damp=0.35, wet=1.3, predelay=0.05, tone=3500, circular=True)
    drone = (S.sine(S.loop_freq(41.0, n), n) + 0.9 * S.sine(S.loop_freq(43.2, n), n, 0.4) + 0.3 * S.sine(S.loop_freq(82.0, n), n, 0.2))
    drone = S.set_rms(drone * (0.75 + 0.25 * S.random_lfo(rng, n, 0.06, periodic=True)), -25.0)
    rat = S.zeros(n)
    for t in S.event_times(rng, dur, 4, min_gap=2.0):
        S.place(rat, rattle(rng, rng.uniform(0.25, 0.5)), t, gain=rng.uniform(0.5, 1.0), wrap=True)
    rat = S.reverb(rat, rt60=1.0, size=1.0, wet=0.2, circular=True)
    wh = S.zeros(n)
    for _ in range(3):
        wh += whisper(rng, dur, rate=rng.uniform(4.0, 6.5), circular=True) * (0.5 + 0.5 * S.random_lfo(rng, n, 0.25, periodic=True)) ** 3
    wh = S.reverb(wh, rt60=3.0, size=1.8, wet=0.6, tone=3000, circular=True)
    return S.mix((S.normalize(drips, -9.0), 0), drone, (S.normalize(rat, -20.0), 0), (S.set_rms(wh, -33.0), 0))


def amb_furnace(rng):
    """Roaring fire, clinking chains, a dissonant choir, a slow heartbeat."""
    dur = 16.0
    n = S.N(dur)
    roar = fire(rng, n)
    roar += S.set_rms(S.band(S.pink(rng, n), 40, 200, circular=True) * (0.5 + 0.5 * S.random_lfo(rng, n, 1.8, periodic=True)), -20.0)
    roar = S.set_rms(roar, -20.0)
    chains = S.zeros(n)
    for t in S.event_times(rng, dur, 5, min_gap=1.5):
        for _ in range(rng.integers(3, 7)):
            S.place(chains, metallic(rng, rng.uniform(0.15, 0.35), rng.uniform(2000.0, 4200.0), 5, 0.15), t,
                    gain=rng.uniform(0.3, 1.0), wrap=True)
            t += rng.uniform(0.04, 0.13)
    chains = S.reverb(chains, rt60=3.0, size=1.8, wet=0.7, tone=5000, circular=True)
    choir = S.zeros(n)
    for f in (220.0, 233.08, 329.63, 349.23, 440.0, 466.16):
        vib = 1.0 + 0.008 * S.lfo(n, S.loop_freq(rng.uniform(5.0, 6.5), n), phase0=rng.random())
        sw = (0.5 + 0.5 * S.random_lfo(rng, n, 0.12, periodic=True)) ** 2.5
        choir += S.detuned("saw", S.loop_freq(f, n) * vib, n, voices=3, spread_cents=7.0, rng=rng) * sw
    choir = S.formant(choir, (700, 1100, 2600), q=(4, 5, 6), gains=(1.0, 0.6, 0.4), circular=True)
    choir = S.peak_eq(S.lowpass(choir, 3500, circular=True), 2800, q=1.5, gain_db=5.0, circular=True)
    choir = S.set_rms(S.reverb(choir, rt60=4.0, size=2.0, wet=0.9, tone=3500, circular=True), -27.0)
    heart = S.zeros(n)
    for i in range(10):
        S.place(heart, heartbeat_pair(rng), i * 1.6, wrap=True)
    return S.mix(roar, (S.normalize(chains, -15.0), 0), choir, (S.normalize(heart, -8.0), 0))


def splash(rng, dur: float = 0.8) -> np.ndarray:
    """Water splash: burst, fizz, plop and a few droplets."""
    n = S.N(dur)
    body = S.band(S.white(rng, n), 400, 4000) * S.adsr(n, 0.008, 0.15, 0.3, 0.5)
    body *= 0.6 + 0.4 * S.random_lfo(rng, n, 25.0)
    out = body
    S.place(out, thump(180, 70, 0.12, 0.03), 0.0, gain=1.1)
    drops = S.bandpass(S.impulses(rng, n, 60.0, shape=2.0), 2500, q=4.0) * S.decay_env(n, 0.3)
    return S.normalize(out + S.normalize(drops, -6.0), 0.0)


def amb_cistern(rng):
    """Lapping water, gurgles, huge-reverb drips, a fluorescent hum, one splash."""
    dur = 18.0
    n = S.N(dur)
    gfc = 250.0 * 2.0 ** (1.5 * S.random_lfo(rng, n, 3.0, periodic=True))
    gurgle = S.stft_filter(S.white(rng, n), "bp", gfc, q=10.0, frame=512, circular=True)
    gurgle *= np.clip(S.random_lfo(rng, n, 4.0, periodic=True), 0.0, 1.0) ** 2
    lap = S.band(S.pink(rng, n), 250, 900, circular=True) * (0.5 + 0.5 * S.random_lfo(rng, n, 0.3, periodic=True)) ** 2
    water = S.set_rms(gurgle, -30.0) + S.set_rms(lap, -27.0)
    water = S.reverb(water, rt60=3.0, size=2.0, wet=0.5, tone=2500, circular=True)
    drips = S.zeros(n)
    for t in S.event_times(rng, dur, 8, min_gap=0.8):
        S.place(drips, drip(rng, rng.uniform(800.0, 2400.0)), t, gain=rng.uniform(0.4, 1.0), wrap=True)
    drips = S.reverb(drips, rt60=7.0, size=2.8, damp=0.3, wet=1.4, predelay=0.06, tone=4000, circular=True)
    buzz = S.set_rms(fluorescent(rng, n, thin=True), -34.0)
    sp = S.zeros(n)
    S.place(sp, splash(rng, 0.9), 9.0)
    sp = S.reverb(sp, rt60=6.0, size=2.6, wet=1.2, tone=3000, circular=True)
    return S.mix(water, (S.normalize(drips, -10.0), 0), buzz, (S.normalize(sp, -10.0), 0))


def muzak(rng, n: int, dur: float) -> np.ndarray:
    """Elevator muzak from a tiny speaker: warped-tape major chords + arpeggio."""
    chords = [(261.63, 329.63, 392.0), (220.0, 261.63, 329.63), (174.61, 220.0, 261.63), (196.0, 246.94, 293.66)]
    wobble = 2.0 ** (0.012 * S.random_lfo(rng, n, 0.8, periodic=True) + 0.004 * S.lfo(n, S.loop_freq(6.0, n)))
    seg = dur / len(chords)
    out = S.zeros(n)
    for i, chord in enumerate(chords):
        s, e = S.N(i * seg), S.N((i + 1) * seg)
        m = e - s
        env = S.adsr(m, 0.25, 0.3, 0.8, 0.5, curve=2.0)
        for f in chord:
            v = 0.6 * S.triangle(f * wobble[s:e], m, rng.random()) + 0.3 * S.square(f * 0.5 * wobble[s:e], m, rng.random())
            out[s:e] += v * env
        for j in range(8):
            f = chord[j % 3] * (2.0 if j % 3 else 1.0) * 2.0
            a, b = s + S.N(j * seg / 8), min(s + S.N((j + 1) * seg / 8), e)
            k = b - a
            out[a:b] += 0.5 * S.triangle(f * wobble[a:b], k) * S.perc(k, 0.01, 0.25)
    out = S.band(out, 250, 2800, circular=True)
    out = S.peak_eq(out, 1200, q=1.0, gain_db=4.0, circular=True)
    out *= 0.85 + 0.15 * S.lfo(n, S.loop_freq(3.2, n))
    return S.normalize(S.reverb(out, rt60=0.6, size=0.5, wet=0.3, circular=True), 0.0)


def amb_offices(rng):
    """Fluorescent hum, HVAC, faint warped muzak, a phone ringing once."""
    dur = 16.0
    n = S.N(dur)
    buzz = S.set_rms(fluorescent(rng, n, thin=False), -31.0)
    hvac = S.lowpass(S.pink(rng, n), 400, circular=True) * (1.0 + 0.06 * S.lfo(n, S.loop_freq(24.0, n)))
    hvac *= 0.85 + 0.15 * S.random_lfo(rng, n, 0.1, periodic=True)
    hvac = S.set_rms(hvac, -26.0)
    mz = S.set_rms(muzak(rng, n, dur), -34.0)
    ring = S.zeros(n)
    S.place(ring, phone_ring(rng), 6.5)
    ring = S.reverb(S.lowpass(ring, 3000), rt60=1.0, size=1.0, wet=0.5, tone=3000, circular=True)
    return S.mix(buzz, hvac, mz, (S.normalize(ring, -20.0), 0))


def amb_clocktower(rng):
    """Massive tick-tock, turning gears, wind at height, a deep bell resonance."""
    dur = 16.0
    n = S.N(dur)
    tt = S.zeros(n)
    for i in range(16):
        tock = i % 2 == 1
        c = S.zeros(S.N(0.5))
        S.place(c, thump(60 if tock else 75, 38 if tock else 45, 0.3, 0.07, attack=0.003), 0.0)
        S.place(c, noise_burst(rng, 0.04, 500 if tock else 700, 2500, 0.0005, 0.008), 0.0, gain=0.55)
        S.place(c, S.bell(900.0 if tock else 1100.0, S.N(0.3), [(1.0, 1.0, 0.05), (2.3, 0.4, 0.03)], rng=rng), 0.0, gain=0.25)
        S.place(tt, c, float(i), gain=rng.uniform(0.9, 1.0), wrap=True)
    tt = S.reverb(tt, rt60=3.5, size=1.6, damp=0.4, wet=0.5, tone=3500, circular=True)
    gears = S.bandpass(S.pulse_train(8.0 * (1.0 + 0.1 * S.random_lfo(rng, n, 2.0, periodic=True)), n, rng, jitter=0.5), 3000, q=6.0, circular=True)
    gears += 2.0 * S.bandpass(S.pulse_train(2.0, n, rng, jitter=0.3), 1500, q=8.0, circular=True)
    gears = S.reverb(gears, rt60=2.0, size=1.4, wet=0.4, circular=True)
    w = S.set_rms(wind(rng, n, 300, 2500, res=(500.0, 1500.0), q=10.0, swell_rate=0.1, depth=0.75), -27.0)
    bell = church_bell(rng, 110.0, dur, decay_scale=2.2, strike=0.0)
    bell = S.lowpass(bell, 900, circular=True) * S.adsr(n, 0.3, 0.0, 1.0, 0.0)
    return S.mix((S.normalize(tt, -8.0), 0), (S.normalize(gears, -24.0), 0), w, (S.set_rms(bell, -26.0), 0))


def amb_static(rng):
    """TV static with a soft warble, an 8 kHz whine, and ghost-voice modulations."""
    dur = 15.0
    n = S.N(dur)
    st = S.white(rng, n)
    st *= 1.0 + 0.12 * S.random_lfo(rng, n, 3.0, periodic=True) + 0.04 * S.lfo(n, S.loop_freq(0.4, n))
    st *= 1.0 + 0.03 * S.lfo(n, S.loop_freq(60.0, n))
    st = S.set_rms(S.highpass(st, 120, circular=True), -16.0)
    whine = S.sine(S.loop_freq(8000.0, n) * (1.0 + 0.0005 * S.random_lfo(rng, n, 1.0, periodic=True)), n)
    whine = S.set_rms(whine, -34.0)
    ghost = S.zeros(n)
    for _ in range(2):
        ghost += whisper(rng, dur, rate=4.0, circular=True) * (0.5 + 0.5 * S.random_lfo(rng, n, 0.2, periodic=True)) ** 3
    ghost = S.set_rms(S.band(ghost, 300, 3000, circular=True), -30.0)
    dip = 1.0 - 0.25 * np.clip(S.random_lfo(rng, n, 0.15, periodic=True), 0.0, 1.0) ** 2
    return st * dip + whine + ghost


def amb_mirror(rng):
    """The nexus in reverse: swells that cut, a flattened drone, reversed reverb."""
    dur = 20.0
    n = S.N(dur)
    det = 0.985
    drone = S.zeros(n)
    for f, a in ((55.0, 1.0), (55.45, 0.8), (110.0, 0.5), (110.7, 0.4), (82.5, 0.2), (27.5, 0.3)):
        drone += a * S.sine(S.loop_freq(f * det, n), n, rng.random()) * (0.8 + 0.2 * S.lfo(n, S.loop_freq(rng.uniform(0.05, 0.15), n), phase0=rng.random()))
    drone = S.set_rms(drone, -22.0)
    rev = S.zeros(n)
    for t in S.event_times(rng, dur, 6, min_gap=1.2):
        ev = S.zeros(S.N(3.0))
        S.place(ev, drip(rng, rng.uniform(700.0, 1800.0) * det), 0.0)
        ev = S.reverb(ev, rt60=2.5, size=2.0, wet=1.5, tone=3500)
        S.place(rev, S.reverse(S.fade(ev, 0.0, 0.004)), t, gain=rng.uniform(0.4, 1.0), wrap=True)
    b = church_bell(rng, 196.0 * det, 5.0, decay_scale=0.7)
    S.place(rev, S.reverse(S.lowpass(b, 1800)), 9.0, gain=0.9, wrap=True)
    choir = S.zeros(n)
    t = S.t_axis(n)
    for f in (220.0, 261.63, 329.63, 440.0):
        vib = 1.0 + 0.004 * S.lfo(n, S.loop_freq(rng.uniform(4.5, 6.0), n), phase0=rng.random())
        glide = 2.0 ** (-0.02 * (t % 5.0) / 5.0)
        env = np.exp(((t % 5.0) - 5.0) / 1.2) * (t % 5.0 < 4.9)
        choir += S.detuned("sine", f * det * vib * glide, n, voices=3, spread_cents=8.0, rng=rng) * env
    choir = S.formant(choir, (450, 900, 2400), q=(4, 5, 6), gains=(1.0, 0.7, 0.2), circular=True)
    choir = S.set_rms(S.reverb(choir, rt60=4.0, size=2.2, wet=0.6, tone=3000, circular=True), -30.0)
    breath = S.band(S.pink(rng, n), 400, 3000, circular=True) * np.exp(((t % 10.0) - 10.0) / 2.5) * (t % 10.0 < 9.95)
    breath = S.set_rms(S.reverb(breath, rt60=3.0, size=2.0, wet=0.5, circular=True), -36.0)
    return S.mix(drone, (S.normalize(rev, -10.0), 0), choir, breath)


# ===========================================================================
# SFX: footsteps
# ===========================================================================

def sfx_step_stone(rng):
    n = S.N(0.25)
    body = S.normalize(step_core(rng, 0.25, (140, 70), 0.03, 0.8, 400, 4000, 0.02, 1.0, 0.8), 0.0)
    ring = S.normalize(S.bandpass(S.impulse(n), 1200, q=10.0), 0.0) * S.decay_env(n, 0.03)
    grit = S.normalize(S.band(S.white(rng, n), 1500, 6000), 0.0) * S.decay_env(n, 0.05)
    return S.reverb(body + 0.5 * ring + 0.35 * grit, rt60=0.6, size=0.8, wet=0.15)


def sfx_step_wood(rng):
    n = S.N(0.25)
    body = S.normalize(step_core(rng, 0.25, (120, 75), 0.07, 1.2, 300, 1500, 0.03, 0.8, 0.3), 0.0)
    knock = S.normalize(S.bandpass(S.impulse(n), 420, q=5.0), 0.0) * S.decay_env(n, 0.04)
    cr = S.pad_to(creak(rng, 0.12, 60, 140, res=1100, q=6.0), n) * S.decay_env(n, 0.08)
    return body + 0.6 * knock + 0.35 * cr


def sfx_step_grass(rng):
    n = S.N(0.28)
    swish = S.normalize(S.band(S.white(rng, n), 1200, 6000), 0.0) * S.adsr(n, 0.02, 0.08, 0.35, 0.15)
    crunch = S.normalize(S.band(S.impulses(rng, n, 300.0, shape=1.5), 2000, 7000), 0.0) * S.decay_env(n, 0.09)
    body = S.normalize(step_core(rng, 0.28, (100, 60), 0.04, 1.0, 200, 800, 0.05, 0.6), 0.0)
    return swish + 0.6 * crunch + 0.4 * body


def sfx_step_carpet(rng):
    n = S.N(0.2)
    body = S.normalize(S.lowpass(step_core(rng, 0.2, (90, 55), 0.05, 0.9, 150, 600, 0.06, 1.0, 0.0), 700), 0.0)
    brush = S.normalize(S.band(S.white(rng, n), 1500, 5000), 0.0) * S.adsr(n, 0.01, 0.05, 0.3, 0.08)
    return body + 0.35 * brush


def sfx_step_water(rng):
    n = S.N(0.32)
    splashy = S.normalize(S.band(S.white(rng, n), 500, 4500), 0.0) * S.adsr(n, 0.005, 0.1, 0.3, 0.15)
    splashy *= 0.5 + 0.5 * S.random_lfo(rng, n, 40.0)
    plop = S.pad_to(thump(160, 70, 0.1, 0.03), n)
    drops = S.normalize(S.bandpass(S.impulses(rng, n, 80.0, shape=2.0), 2800, q=5.0), 0.0) * S.decay_env(n, 0.15)
    return splashy + 0.7 * plop + 0.5 * drops


def sfx_step_tile(rng):
    n = S.N(0.22)
    body = S.normalize(step_core(rng, 0.22, (150, 80), 0.025, 0.5, 800, 6000, 0.012, 1.0, 1.2), 0.0)
    ring = S.bell(2600.0, n, [(1.0, 1.0, 0.04), (1.55, 0.6, 0.03), (2.4, 0.3, 0.02)], rng=rng)
    return S.reverb(body + 0.45 * ring, rt60=1.0, size=0.7, wet=0.3)


def sfx_step_metal(rng):
    n = S.N(0.35)
    body = S.normalize(step_core(rng, 0.35, (130, 70), 0.04, 0.9, 300, 3000, 0.02, 0.7, 0.8), 0.0)
    clang = S.bell(310.0, n, [(1.0, 1.0, 0.25), (2.3, 0.7, 0.18), (4.2, 0.5, 0.12), (6.8, 0.3, 0.08)], beat=1.5, rng=rng)
    return S.reverb(body + 0.8 * clang, rt60=0.8, size=0.9, wet=0.25)


def sfx_step_bone(rng):
    n = S.N(0.3)
    body = S.normalize(step_core(rng, 0.3, (250, 140), 0.03, 0.8, 500, 3000, 0.015, 0.7, 0.5), 0.0)
    knock = S.normalize(S.bandpass(S.impulse(n), 260, q=6.0), 0.0) * S.decay_env(n, 0.05)
    clicks = S.zeros(n)
    for _ in range(rng.integers(5, 9)):
        S.place(clicks, click(rng, 2000, 6000, 0.004), rng.uniform(0.005, 0.2), gain=rng.uniform(0.3, 0.9))
    rat = S.pad_to(rattle(rng, 0.25), n)
    return 0.6 * body + 0.5 * knock + 0.8 * clicks + 0.5 * rat


def sfx_step_flesh(rng):
    n = S.N(0.3)
    body = S.normalize(step_core(rng, 0.3, (90, 50), 0.06, 1.0, 200, 1500, 0.05, 0.8, 0.0), 0.0)
    sq = S.stft_filter(S.white(rng, n), "bp", S.expline(n, 1500.0, 350.0), q=4.0, frame=256)
    sq = S.normalize(sq, 0.0) * (0.5 + 0.5 * S.random_lfo(rng, n, 60.0)) * S.adsr(n, 0.005, 0.1, 0.2, 0.1)
    return S.lowpass(0.8 * body + sq, 3500)


def sfx_step_sand(rng):
    n = S.N(0.3)
    hiss = S.normalize(S.band(S.white(rng, n), 800, 4500), 0.0) * S.adsr(n, 0.03, 0.1, 0.4, 0.12)
    hiss *= 0.6 + 0.4 * S.random_lfo(rng, n, 90.0)
    body = S.normalize(step_core(rng, 0.3, (90, 55), 0.05, 1.0, 150, 600, 0.06, 0.5), 0.0)
    return hiss + 0.4 * body


def sfx_step_gravel(rng):
    n = S.N(0.3)
    crunch = S.normalize(S.band(S.impulses(rng, n, 500.0, shape=1.2), 1000, 6500), 0.0) * S.adsr(n, 0.004, 0.08, 0.3, 0.12)
    scrape = S.normalize(S.band(S.white(rng, n), 300, 2000), 0.0) * S.perc(n, 0.002, 0.05)
    body = S.normalize(step_core(rng, 0.3, (110, 60), 0.04, 1.0, 200, 800, 0.03, 0.4), 0.0)
    return crunch + 0.5 * scrape + 0.45 * body


def sfx_step_snow(rng):
    n = S.N(0.32)
    crunch = S.normalize(S.bandpass(S.impulses(rng, n, 350.0, shape=1.5), 2500, q=3.0), 0.0) * S.adsr(n, 0.02, 0.1, 0.4, 0.14)
    crunch *= 0.5 + 0.5 * S.random_lfo(rng, n, 25.0)
    squeak = S.normalize(S.bandpass(S.impulses(rng, n, 200.0, shape=2.0), 1400, q=12.0), 0.0) * S.adsr(n, 0.03, 0.1, 0.3, 0.1)
    body = S.normalize(S.lowpass(step_core(rng, 0.32, (80, 50), 0.06, 1.0, 150, 500, 0.08, 0.8), 600), 0.0)
    return crunch + 0.4 * squeak + 0.5 * body


# ===========================================================================
# SFX: doors
# ===========================================================================

def sfx_door_open(rng):
    n = S.N(0.95)
    x = S.zeros(n)
    S.place(x, click(rng, 1200, 5000, 0.006), 0.0, gain=0.7)
    S.place(x, thump(180, 110, 0.08, 0.02), 0.01, gain=0.4)
    S.place(x, creak(rng, 0.7, 28, 120, res=1400, q=9.0), 0.08, gain=1.0)
    S.place(x, thump(120, 80, 0.12, 0.03), 0.78, gain=0.35)
    return S.reverb(x, rt60=0.8, size=0.9, wet=0.2)


def sfx_door_close(rng):
    n = S.N(0.6)
    x = S.zeros(n)
    S.place(x, thump(110, 50, 0.3, 0.06, attack=0.003), 0.0, gain=1.0)
    S.place(x, noise_burst(rng, 0.25, 90, 800, 0.002, 0.04), 0.0, gain=0.8)
    S.place(x, click(rng, 1500, 5000, 0.005), 0.055, gain=0.6)
    S.place(x, thump(250, 160, 0.06, 0.015), 0.055, gain=0.3)
    return S.reverb(x, rt60=0.9, size=1.0, wet=0.3)


def sfx_door_locked(rng):
    n = S.N(0.5)
    x = S.zeros(n)
    t = 0.0
    for i in range(4):
        S.place(x, click(rng, 1800, 6000, 0.005), t, gain=rng.uniform(0.6, 1.0))
        S.place(x, thump(140, 90, 0.08, 0.02), t, gain=0.5)
        S.place(x, S.bell(2100.0, S.N(0.08), [(1.0, 1.0, 0.03), (1.7, 0.5, 0.02)], rng=rng), t + 0.003, gain=0.35)
        t += rng.uniform(0.07, 0.11)
    return S.reverb(x, rt60=0.6, size=0.7, wet=0.15)


def sfx_door_heavy(rng):
    return stone_grind(rng, 1.7, thud=True)


def sfx_curtain(rng):
    n = S.N(0.5)
    fc = S.expline(n, 4000.0, 900.0)
    x = S.stft_filter(S.white(rng, n), "bp", fc, q=1.2, frame=512) * S.adsr(n, 0.04, 0.12, 0.5, 0.2)
    for _ in range(6):
        S.place(x, click(rng, 3000, 8000, 0.003) * 0.15, rng.uniform(0.02, 0.35))
    return x


def sfx_door_creak_long(rng):
    n = S.N(2.4)
    x = S.zeros(n)
    S.place(x, creak(rng, 1.3, 22, 95, res=1300, q=10.0), 0.0)
    S.place(x, creak(rng, 0.9, 40, 60, res=1700, q=12.0), 1.35, gain=0.7)
    return S.reverb(x, rt60=1.4, size=1.2, wet=0.35)


# ===========================================================================
# SFX: pickups, bells, keepsakes
# ===========================================================================

def sfx_pickup(rng):
    n = S.N(1.6)
    x = S.zeros(n)
    for i, f in enumerate((523.25, 659.25, 783.99, 987.77, 1174.66, 1567.98)):
        m = S.N(0.9)
        tone = S.fm(f, 2.0, 0.5 * np.exp(-S.t_axis(m) / 0.12), m) * S.perc(m, 0.003, 0.22)
        S.place(x, tone, i * 0.075, gain=0.8 - 0.05 * i)
    x += 0.35 * S.pad_to(sparkle(rng, 1.4, 4000, 9000, 30, 0.07, rise=True), n)
    return S.reverb(x, rt60=1.8, size=1.4, wet=0.5, tone=6000)


def sfx_pickup_item(rng):
    n = S.N(0.25)
    x = S.zeros(n)
    S.place(x, S.sine(1760.0, S.N(0.12)) * S.perc(S.N(0.12), 0.002, 0.035), 0.0)
    S.place(x, S.sine(2349.3, S.N(0.14)) * S.perc(S.N(0.14), 0.002, 0.045), 0.05, gain=0.8)
    return x


def sfx_bell_small(rng):
    n = S.N(1.5)
    parts = [(1.0, 1.0, 1.1), (2.0, 0.15, 0.6), (3.0, 0.5, 0.7), (5.4, 0.25, 0.35), (7.9, 0.1, 0.2)]
    x = S.bell(1046.5, n, parts, beat=1.5, rng=rng)
    x += 0.5 * S.pad_to(noise_burst(rng, 0.02, 2000, 8000, 0.0003, 0.004), n)
    return x


def sfx_bell_big(rng):
    x = church_bell(rng, 196.0, 5.0, decay_scale=0.75, strike=0.6)
    return S.reverb(x, rt60=2.5, size=1.8, wet=0.35, tone=3000)


def sfx_lantern_on(rng):
    n = S.N(0.9)
    x = S.stft_filter(S.white(rng, n), "bp", S.expline(n, 300.0, 2200.0), q=2.0, frame=512) * S.adsr(n, 0.05, 0.15, 0.3, 0.3)
    ign = fire(rng, S.N(0.7), circular=False) * S.adsr(S.N(0.7), 0.03, 0.2, 0.5, 0.35)
    S.place(x, S.normalize(ign, 0.0), 0.15, gain=0.9)
    S.place(x, thump(120, 60, 0.2, 0.06), 0.14, gain=0.5)
    return x


def sfx_lantern_off(rng):
    n = S.N(0.4)
    x = S.band(S.white(rng, n), 200, 1800) * S.perc(n, 0.004, 0.05)
    x += 0.3 * S.band(S.white(rng, n), 2000, 6000) * S.adsr(n, 0.01, 0.1, 0.2, 0.2)
    return x


def sfx_shrink(rng):
    n = S.N(0.8)
    x = S.detuned("triangle", S.expline(n, 1300.0, 140.0), n, voices=3, spread_cents=12.0, rng=rng) * S.adsr(n, 0.01, 0.2, 0.6, 0.3)
    x += 0.6 * S.pad_to(sparkle(rng, 0.7, 3000, 9000, 20, 0.05), n)
    return S.reverb(S.lowpass(x, 5000), rt60=1.0, size=1.0, wet=0.3)


def sfx_grow(rng):
    n = S.N(0.8)
    x = S.detuned("triangle", S.expline(n, 140.0, 1300.0), n, voices=3, spread_cents=12.0, rng=rng) * S.adsr(n, 0.02, 0.2, 0.7, 0.25)
    x += 0.5 * S.pad_to(sparkle(rng, 0.7, 2500, 9000, 20, 0.05, rise=True), n)
    return S.reverb(S.lowpass(x, 5000), rt60=1.0, size=1.0, wet=0.3)


def sfx_shard(rng):
    n = S.N(1.0)
    x = S.pad_to(sparkle(rng, 0.9, 4000, 9500, 40, 0.09), n)
    x += 0.5 * S.bell(3400.0, n, [(1.0, 1.0, 0.5), (1.6, 0.5, 0.3), (2.35, 0.3, 0.2)], beat=2.0, rng=rng)
    x += 0.4 * S.pad_to(click(rng, 3000, 9000, 0.004), n)
    return S.reverb(x, rt60=1.2, size=1.2, wet=0.4, tone=8000)


def sfx_hourglass(rng):
    n = S.N(1.6)
    sand = S.band(S.white(rng, n), 2000, 7000) * (0.6 + 0.4 * S.random_lfo(rng, n, 120.0)) * S.adsr(n, 0.1, 0.4, 0.5, 0.5)
    t = S.t_axis(n)
    chord = sum(S.detuned("sine", f, n, voices=3, spread_cents=6.0, rng=rng) for f in (261.63, 392.0, 523.25, 659.25))
    swell = np.exp((t - 1.5) / 0.35) * (t < 1.5)
    x = S.normalize(sand, -6.0) + S.normalize(chord * swell, -3.0)
    x = S.reverb(x, rt60=1.5, size=1.3, wet=0.3)
    return S.fade(x, 0.0, 0.05)


def sfx_umbrella(rng):
    n = S.N(0.35)
    x = S.band(S.white(rng, n), 500, 6000) * S.perc(n, 0.001, 0.02)
    x += 0.8 * S.pad_to(thump(120, 50, 0.15, 0.04), n)
    for i in range(4):
        S.place(x, noise_burst(rng, 0.03, 400, 2500, 0.002, 0.01) * 0.3, 0.06 + i * 0.05)
    return x


def sfx_knife_swing(rng):
    n = S.N(0.35)
    fc = np.concatenate([S.expline(S.N(0.15), 400.0, 2600.0), S.expline(n - S.N(0.15), 2600.0, 700.0)])
    x = S.stft_filter(S.white(rng, n), "bp", fc, q=2.5, frame=512) * S.adsr(n, 0.05, 0.1, 0.5, 0.15)
    return x


def sfx_knife_cut(rng):
    n = S.N(0.45)
    rate = S.expline(n, 250.0, 900.0)
    x = S.stft_filter(S.impulses(rng, n, rate, shape=1.0), "bp", S.expline(n, 1200.0, 3500.0), q=3.0, frame=512)
    x *= S.adsr(n, 0.01, 0.1, 0.7, 0.12)
    x += 0.4 * S.band(S.white(rng, n), 1000, 5000) * S.adsr(n, 0.01, 0.15, 0.5, 0.12)
    return x


def sfx_flap(rng):
    n = S.N(0.5)
    x = S.stft_filter(S.white(rng, n), "bp", S.expline(n, 260.0, 70.0), q=1.5, frame=512) * S.adsr(n, 0.08, 0.1, 0.4, 0.2)
    x += 0.4 * S.band(S.white(rng, n), 1500, 6000) * S.adsr(n, 0.04, 0.05, 0.3, 0.2)
    x += 0.6 * S.pad_to(thump(90, 45, 0.25, 0.08, attack=0.05), n)
    return x


# ===========================================================================
# SFX: movement, UI
# ===========================================================================

def sfx_jump(rng):
    n = S.N(0.25)
    x = S.stft_filter(S.white(rng, n), "bp", S.expline(n, 300.0, 1000.0), q=2.0, frame=512) * S.adsr(n, 0.03, 0.06, 0.4, 0.1)
    x += 0.3 * S.band(S.white(rng, n), 2000, 6000) * S.perc(n, 0.005, 0.03)
    return x


def sfx_land(rng):
    n = S.N(0.35)
    x = S.zeros(n)
    S.place(x, thump(85, 40, 0.3, 0.07, attack=0.003), 0.0)
    S.place(x, noise_burst(rng, 0.2, 100, 900, 0.002, 0.04), 0.0, gain=0.7)
    S.place(x, S.band(S.impulses(rng, S.N(0.15), 200.0, shape=1.5), 1500, 5000) * S.decay_env(S.N(0.15), 0.04), 0.0, gain=0.25)
    return x


def sfx_splash(rng):
    return S.reverb(splash(rng, 0.8), rt60=0.8, size=1.0, wet=0.2)


def sfx_void_fall(rng):
    n = S.N(2.0)
    t = S.t_axis(n)
    fc = S.expline(n, 300.0, 3200.0)
    x = S.stft_filter(S.white(rng, n), "bp", fc, q=6.0) * (0.15 + 0.85 * (t / 2.0) ** 1.5)
    whistle = S.sine(S.expline(n, 600.0, 2400.0) * (1.0 + 0.01 * S.lfo(n, 6.0)), n) * (t / 2.0) ** 2
    rumble = S.band(S.pink(rng, n), 30, 150) * (t / 2.0) ** 2
    x = S.normalize(x, 0.0) + 0.3 * whistle + 0.8 * rumble
    return S.fade(x, 0.02, 0.06)


def sfx_ui_blip(rng):
    n = S.N(0.06)
    return S.sine(1400.0, n) * S.perc(n, 0.002, 0.012) + 0.2 * S.pad_to(click(rng, 3000, 8000, 0.002), n)


def sfx_ui_confirm(rng):
    n = S.N(0.22)
    x = S.zeros(n)
    S.place(x, S.sine(880.0, S.N(0.09)) * S.perc(S.N(0.09), 0.002, 0.03), 0.0)
    S.place(x, S.sine(1318.5, S.N(0.13)) * S.perc(S.N(0.13), 0.002, 0.045), 0.08)
    return x


def sfx_page(rng):
    n = S.N(0.45)
    x = S.band(S.white(rng, n), 1500, 7000) * (S.bump(n, 0.08, 0.14) * 0.6 + S.bump(n, 0.26, 0.2))
    x += 0.5 * S.band(S.impulses(rng, n, 200.0, shape=2.0), 2000, 8000) * (S.bump(n, 0.1, 0.15) + S.bump(n, 0.27, 0.15))
    return x


def sfx_write(rng):
    n = S.N(0.55)
    strokes = np.clip(S.random_lfo(rng, n, 7.0), 0.0, 1.0) ** 0.6
    x = S.band(S.impulses(rng, n, 900.0, shape=1.0), 2000, 7000) * strokes
    x += 0.3 * S.band(S.white(rng, n), 3000, 8000) * strokes
    x += 0.15 * S.bandpass(x, 350, q=3.0)
    return x * S.adsr(n, 0.02, 0.1, 0.9, 0.08)


# ===========================================================================
# SFX: world
# ===========================================================================

def sfx_brazier(rng):
    n = S.N(1.3)
    x = S.band(S.white(rng, n), 100, 1500) * S.adsr(n, 0.03, 0.25, 0.25, 0.6)
    x += 0.9 * S.pad_to(thump(70, 35, 0.4, 0.12, attack=0.02), n)
    S.place(x, S.normalize(fire(rng, S.N(1.0), circular=False), 0.0) * S.adsr(S.N(1.0), 0.05, 0.3, 0.6, 0.4), 0.2, gain=0.6)
    return x


def sfx_lever(rng):
    n = S.N(0.55)
    x = S.zeros(n)
    S.place(x, click(rng, 1500, 5000, 0.005), 0.0, gain=0.6)
    S.place(x, metallic(rng, 0.25, 1400.0, 4, 0.12), 0.0, gain=0.5)
    S.place(x, thump(110, 60, 0.25, 0.06, attack=0.003), 0.16, gain=1.0)
    S.place(x, noise_burst(rng, 0.15, 150, 900, 0.002, 0.03), 0.16, gain=0.6)
    for i in range(3):
        S.place(x, click(rng, 2500, 7000, 0.003), 0.24 + i * 0.045, gain=0.35)
    return x


def sfx_stone_grind(rng):
    return stone_grind(rng, 2.0, thud=True)


def sfx_tv_on(rng):
    n = S.N(0.85)
    x = S.zeros(n)
    S.place(x, click(rng, 2000, 7000, 0.004), 0.0, gain=1.0)
    S.place(x, thump(120, 60, 0.15, 0.04), 0.0, gain=0.5)
    m = S.N(0.7)
    whine = S.sine(S.expline(m, 2500.0, 8000.0), m) * S.adsr(m, 0.02, 0.2, 0.5, 0.2)
    S.place(x, whine, 0.05, gain=0.25)
    S.place(x, S.highpass(S.white(rng, m), 1500) * S.adsr(m, 0.15, 0.2, 0.4, 0.2), 0.05, gain=0.35)
    S.place(x, S.sine(60.0, m) * S.adsr(m, 0.2, 0.1, 0.8, 0.2), 0.1, gain=0.25)
    return x


def sfx_tv_off(rng):
    n = S.N(0.7)
    x = S.zeros(n)
    S.place(x, click(rng, 2000, 7000, 0.004), 0.0, gain=1.0)
    m = S.N(0.5)
    S.place(x, S.sine(S.expline(m, 8000.0, 400.0), m) * S.adsr(m, 0.005, 0.15, 0.4, 0.2), 0.01, gain=0.3)
    S.place(x, S.highpass(S.white(rng, m), 1500) * S.decay_env(m, 0.08), 0.01, gain=0.35)
    S.place(x, thump(140, 60, 0.12, 0.03), 0.03, gain=0.5)
    return x


def sfx_static_burst(rng):
    n = S.N(0.5)
    x = S.white(rng, n) * (1.0 + 0.3 * S.random_lfo(rng, n, 25.0)) * S.adsr(n, 0.005, 0.1, 0.8, 0.08)
    x += 0.08 * S.sine(8000.0, n) * S.adsr(n, 0.01, 0.1, 0.6, 0.1)
    return x


def sfx_creak(rng):
    return S.reverb(creak(rng, 0.75, 30, 110), rt60=1.0, size=1.0, wet=0.25)


def sfx_whisper(rng):
    return S.reverb(whisper(rng, 1.5, rate=5.5), rt60=1.5, size=1.4, wet=0.4, tone=3500)


def sfx_heartbeat(rng):
    return np.pad(heartbeat_pair(rng), (0, S.N(0.2)))


def sfx_thunder(rng):
    n = S.N(3.0)
    t = S.t_axis(n)
    crack = S.band(S.white(rng, S.N(0.25)), 100, 2500) * S.perc(S.N(0.25), 0.002, 0.05)
    rumble = S.band(S.pink(rng, n), 25, 140) * (0.5 + 0.5 * S.random_lfo(rng, n, 2.0)) * np.exp(-t / 1.1) * S.adsr(n, 0.05, 0.0, 1.0, 0.3)
    x = S.normalize(rumble, 0.0)
    S.place(x, crack, 0.0, gain=0.9)
    S.place(x, S.band(S.white(rng, S.N(1.0)), 200, 1200) * S.decay_env(S.N(1.0), 0.3), 0.02, gain=0.35)
    x = S.reverb(x, rt60=3.0, size=2.5, wet=0.5, tone=1500)
    return S.fade(x, 0.0, 0.1)


def sfx_growl(rng):
    return S.reverb(growl(rng, 2.0, 30.0), rt60=1.5, size=1.5, wet=0.3, tone=2000)


def sfx_dog_bark(rng):
    n = S.N(0.32)
    t = S.t_axis(n)
    f0 = S.expline(n, 420.0, 230.0) * (1.0 + 0.05 * S.random_lfo(rng, n, 40.0))
    src = S.lp1(S.pulse_train(f0, n, rng, jitter=0.2), 1200)
    x = S.formant(src, (650, 1150, 2500), q=(4, 5, 6), gains=(1.0, 0.7, 0.3))
    x = S.normalize(x, 0.0) * S.adsr(n, 0.015, 0.06, 0.5, 0.12, curve=2.0)
    x += 0.25 * S.band(S.white(rng, n), 800, 4000) * S.adsr(n, 0.01, 0.05, 0.3, 0.12)
    return S.drive(x, 2.0)


def sfx_dog_pant(rng):
    n = S.N(1.25)
    x = S.zeros(n)
    for i in range(5):
        ex = S.band(S.white(rng, S.N(0.14)), 600, 3500) * S.adsr(S.N(0.14), 0.03, 0.05, 0.6, 0.05)
        ex = S.formant(ex, (750, 1300, 2600), q=(3, 4, 5), gains=(1.0, 0.6, 0.3)) + 0.5 * ex
        S.place(x, S.normalize(ex, 0.0), i * 0.25, gain=0.9)
        inh = S.band(S.white(rng, S.N(0.1)), 1500, 5000) * S.adsr(S.N(0.1), 0.03, 0.03, 0.5, 0.04)
        S.place(x, inh, i * 0.25 + 0.14, gain=0.45)
    return x


def sfx_coin(rng):
    n = S.N(0.7)
    x = S.zeros(n)
    t = 0.0
    for i, g in enumerate((1.0, 0.7, 0.45, 0.3)):
        S.place(x, metallic(rng, 0.35, 3300.0 * (1.0 + 0.02 * i), 5, 0.25, strike=0.5), t, gain=g)
        t += (0.16, 0.11, 0.075, 0.05)[i]
    return x


def sfx_key_turn(rng):
    n = S.N(0.65)
    x = S.zeros(n)
    for i in range(3):
        S.place(x, click(rng, 2500, 7000, 0.003), i * 0.035, gain=0.5)
    m = S.N(0.18)
    scrape = S.band(S.impulses(rng, m, 500.0, shape=1.0), 2000, 5000) * S.adsr(m, 0.02, 0.05, 0.6, 0.06)
    S.place(x, scrape, 0.14, gain=0.5)
    S.place(x, metallic(rng, 0.25, 1800.0, 4, 0.1), 0.36, gain=0.6)
    S.place(x, thump(150, 90, 0.12, 0.03), 0.36, gain=0.8)
    S.place(x, click(rng, 1500, 5000, 0.004), 0.36, gain=0.7)
    return x


def sfx_drink(rng):
    n = S.N(0.6)
    x = S.zeros(n)
    for i in range(2):
        m = S.N(0.22)
        glug = S.stft_filter(S.white(rng, m), "bp", S.expline(m, 380.0, 140.0), q=8.0, frame=256) * S.adsr(m, 0.01, 0.06, 0.5, 0.1)
        S.place(x, S.normalize(glug, 0.0), i * 0.25, gain=0.9)
        S.place(x, thump(220, 120, 0.05, 0.012), i * 0.25 + 0.02, gain=0.4)
    return S.lowpass(x, 2500)


def sfx_riddle_correct(rng):
    n = S.N(1.3)
    x = S.zeros(n)
    for i, f in enumerate((1046.5, 1318.5, 1568.0)):
        m = S.N(0.9)
        S.place(x, S.fm(f, 3.0, 0.3 * np.exp(-S.t_axis(m) / 0.1), m) * S.perc(m, 0.003, 0.25), i * 0.09, gain=0.9)
    x += 0.3 * S.pad_to(sparkle(rng, 1.0, 4000, 9000, 18, 0.06, rise=True), n)
    return S.reverb(x, rt60=1.5, size=1.2, wet=0.4, tone=7000)


def sfx_riddle_wrong(rng):
    n = S.N(0.5)
    x = (S.square(110.0, n) + S.square(116.5, n, 0.3)) * (0.7 + 0.3 * S.lfo(n, 30.0))
    x = S.lowpass(x, 800) * S.adsr(n, 0.01, 0.05, 0.8, 0.12)
    return x


def sfx_wake(rng):
    n = S.N(2.0)
    t = S.t_axis(n)
    rise = (t / 2.0) ** 2.2
    x = S.stft_filter(S.white(rng, n), "hp", S.expline(n, 150.0, 2500.0), q=0.7) * rise
    chord = sum(S.detuned("sine", f, n, voices=3, spread_cents=8.0, rng=rng) for f in (261.63, 329.63, 392.0, 523.25))
    x = S.normalize(x, 0.0) + 0.6 * S.normalize(chord, 0.0) * rise ** 1.5
    x += 0.2 * sparkle(rng, 2.0, 3000, 9000, 25, 0.08, rise=True) * rise
    return S.fade(x, 0.01, 0.12)


def sfx_sleep(rng):
    n = S.N(2.0)
    t = S.t_axis(n)
    fall = (1.0 - t / 2.0) ** 1.6
    x = S.stft_filter(S.white(rng, n), "lp", S.expline(n, 4000.0, 150.0), q=0.7) * fall
    glide = 2.0 ** (-(t / 2.0) * 1.0 / 12.0)
    chord = sum(S.detuned("sine", f * glide, n, voices=3, spread_cents=8.0, rng=rng) for f in (220.0, 261.63, 329.63, 440.0))
    x = S.normalize(x, 0.0) + 0.7 * S.normalize(chord, 0.0) * fall ** 0.8
    x = S.reverb(x, rt60=2.0, size=1.6, wet=0.3, tone=3000)
    return S.fade(x, 0.02, 0.2)


def sfx_clock_chime(rng):
    n = S.N(3.2)
    x = S.zeros(n)
    parts = [(1.0, 1.0, 1.6), (2.0, 0.4, 0.9), (2.76, 0.5, 0.7), (4.07, 0.3, 0.4), (5.4, 0.15, 0.25)]
    for i in range(3):
        b = S.bell(659.25, S.N(2.2), parts, beat=1.0, rng=rng)
        S.place(x, b, i * 0.7, gain=0.9 + 0.1 * (i == 2))
    return S.reverb(x, rt60=1.8, size=1.4, wet=0.3, tone=5000)


def sfx_gear_tick(rng):
    n = S.N(0.12)
    x = S.zeros(n)
    S.place(x, click(rng, 2500, 7000, 0.003), 0.0)
    S.place(x, S.bell(3100.0, S.N(0.06), [(1.0, 1.0, 0.015), (1.8, 0.4, 0.01)], rng=rng), 0.001, gain=0.4)
    S.place(x, click(rng, 1500, 4000, 0.003), 0.03, gain=0.35)
    return x


def sfx_wind_gust(rng):
    n = S.N(1.6)
    fc = np.concatenate([S.expline(S.N(0.7), 300.0, 1500.0), S.expline(n - S.N(0.7), 1500.0, 350.0)])
    x = S.stft_filter(S.pink(rng, n), "bp", fc, q=2.5) * S.adsr(n, 0.4, 0.2, 0.7, 0.7, curve=2.0)
    x += 0.4 * S.stft_filter(S.white(rng, n), "bp", fc * 1.8, q=12.0) * S.adsr(n, 0.5, 0.2, 0.6, 0.6)
    return x


def sfx_drip(rng):
    x = np.pad(drip(rng, 1500.0), (0, S.N(0.6)))
    return S.reverb(x, rt60=2.5, size=2.0, wet=1.0, tone=4000)


def sfx_wood_knock(rng):
    n = S.N(0.3)
    x = S.zeros(n)
    S.place(x, thump(190, 110, 0.12, 0.03, attack=0.001), 0.0)
    S.place(x, noise_burst(rng, 0.08, 300, 2500, 0.0005, 0.012), 0.0, gain=0.6)
    S.place(x, S.bell(420.0, S.N(0.15), [(1.0, 1.0, 0.05), (2.4, 0.3, 0.03)], rng=rng), 0.0, gain=0.3)
    return S.reverb(x, rt60=0.6, size=0.8, wet=0.15)


def sfx_glass_break(rng):
    n = S.N(1.0)
    x = S.zeros(n)
    S.place(x, click(rng, 1500, 9000, 0.008), 0.0, gain=1.0)
    S.place(x, sparkle(rng, 0.5, 3000, 9500, 110, 0.06), 0.005, gain=0.9)
    shards = S.normalize(S.band(S.impulses(rng, S.N(0.75), 140.0, shape=2.0), 2500, 8000), 0.0) * S.decay_env(S.N(0.75), 0.35)
    S.place(x, shards, 0.2, gain=0.45)
    return S.reverb(x, rt60=1.0, size=1.1, wet=0.35, tone=8000)


def sfx_chain_rattle(rng):
    n = S.N(0.95)
    x = S.zeros(n)
    t = 0.0
    while t < 0.7:
        S.place(x, metallic(rng, rng.uniform(0.12, 0.3), rng.uniform(2200.0, 4500.0), 5, 0.12), t, gain=rng.uniform(0.3, 1.0))
        t += rng.uniform(0.03, 0.1)
    x += 0.2 * S.band(S.white(rng, n), 800, 4000) * S.adsr(n, 0.02, 0.2, 0.4, 0.3)
    return S.reverb(x, rt60=0.8, size=1.0, wet=0.25)


def sfx_seagull_wrong(rng):
    n = S.N(1.0)
    t = S.t_axis(n)
    f0 = 900.0 * 1.8 ** np.sin(np.pi * t / 1.0) ** 0.6 * (1.0 + 0.03 * S.lfo(n, 38.0))
    src = S.lp1(S.pulse_train(f0, n, rng, jitter=0.05), 2500)
    x = S.formant(src, (1200, 2600, 4200), q=(3, 4, 5), gains=(1.0, 0.7, 0.4))
    x = S.normalize(x, 0.0) * S.adsr(n, 0.05, 0.1, 0.8, 0.25, curve=2.0)
    x = S.reverse(x)
    x = x + 0.6 * S.resample(np.pad(x, (0, len(x))), 0.5)[:n] * S.decay_env(n, 0.6)
    return S.reverb(x, rt60=1.5, size=1.6, wet=0.35, tone=5000)


def sfx_tape_measure(rng):
    n = S.N(0.75)
    m = S.N(0.62)
    rate = S.expline(m, 70.0, 260.0)
    zip_ = S.bandpass(S.pulse_train(rate, m, rng, jitter=0.3), 3200, q=5.0) + 0.5 * S.bandpass(S.pulse_train(rate, m, rng, jitter=0.3, phase0=0.5), 5200, q=6.0)
    zip_ = S.normalize(zip_, 0.0) * S.adsr(m, 0.02, 0.1, 0.9, 0.05)
    whine = S.sine(S.expline(m, 1200.0, 3800.0), m) * S.adsr(m, 0.05, 0.1, 0.5, 0.05)
    x = S.zeros(n)
    S.place(x, zip_ + 0.15 * whine, 0.0)
    S.place(x, click(rng, 1500, 6000, 0.006), 0.63, gain=1.0)
    S.place(x, metallic(rng, 0.12, 2600.0, 4, 0.06), 0.63, gain=0.7)
    S.place(x, thump(200, 120, 0.06, 0.015), 0.63, gain=0.6)
    return x


def sfx_phone_ring(rng):
    return phone_ring(rng, 1.2)


def sfx_photo_click(rng):
    n = S.N(0.28)
    x = S.zeros(n)
    S.place(x, click(rng, 2000, 7000, 0.004), 0.0, gain=1.0)
    S.place(x, thump(600, 350, 0.03, 0.008), 0.0, gain=0.5)
    S.place(x, S.band(S.impulses(rng, S.N(0.06), 800.0, shape=1.0), 3000, 8000) * S.decay_env(S.N(0.06), 0.03), 0.02, gain=0.3)
    S.place(x, click(rng, 1500, 5000, 0.005), 0.075, gain=0.8)
    S.place(x, thump(500, 300, 0.04, 0.01), 0.075, gain=0.5)
    return x


# ===========================================================================
# Catalogue: name -> (kind, generator)
# ===========================================================================

CATALOG = {
    # ambience loops
    "apartment": ("ambience", amb_apartment), "corridor": ("ambience", amb_corridor),
    "hallway": ("ambience", amb_hallway), "nexus": ("ambience", amb_nexus),
    "forest": ("ambience", amb_forest), "city": ("ambience", amb_city),
    "tavern": ("ambience", amb_tavern), "house": ("ambience", amb_house),
    "castle": ("ambience", amb_castle), "sea": ("ambience", amb_sea),
    "catacombs": ("ambience", amb_catacombs), "furnace": ("ambience", amb_furnace),
    "cistern": ("ambience", amb_cistern), "offices": ("ambience", amb_offices),
    "clocktower": ("ambience", amb_clocktower), "static": ("ambience", amb_static),
    "mirror": ("ambience", amb_mirror),
    # footsteps
    "step_stone": ("sfx", sfx_step_stone), "step_wood": ("sfx", sfx_step_wood),
    "step_grass": ("sfx", sfx_step_grass), "step_carpet": ("sfx", sfx_step_carpet),
    "step_water": ("sfx", sfx_step_water), "step_tile": ("sfx", sfx_step_tile),
    "step_metal": ("sfx", sfx_step_metal), "step_bone": ("sfx", sfx_step_bone),
    "step_flesh": ("sfx", sfx_step_flesh), "step_sand": ("sfx", sfx_step_sand),
    "step_gravel": ("sfx", sfx_step_gravel), "step_snow": ("sfx", sfx_step_snow),
    # doors
    "door_open": ("sfx", sfx_door_open), "door_close": ("sfx", sfx_door_close),
    "door_locked": ("sfx", sfx_door_locked), "door_heavy": ("sfx", sfx_door_heavy),
    "curtain": ("sfx", sfx_curtain), "door_creak_long": ("sfx", sfx_door_creak_long),
    # pickups, bells
    "pickup": ("sfx", sfx_pickup), "pickup_item": ("sfx", sfx_pickup_item),
    "bell_small": ("sfx", sfx_bell_small), "bell_big": ("sfx", sfx_bell_big),
    # keepsakes
    "lantern_on": ("sfx", sfx_lantern_on), "lantern_off": ("sfx", sfx_lantern_off),
    "shrink": ("sfx", sfx_shrink), "grow": ("sfx", sfx_grow), "shard": ("sfx", sfx_shard),
    "hourglass": ("sfx", sfx_hourglass), "umbrella": ("sfx", sfx_umbrella),
    "knife_swing": ("sfx", sfx_knife_swing), "knife_cut": ("sfx", sfx_knife_cut),
    "flap": ("sfx", sfx_flap),
    # movement
    "jump": ("sfx", sfx_jump), "land": ("sfx", sfx_land), "splash": ("sfx", sfx_splash),
    "void_fall": ("sfx", sfx_void_fall),
    # ui
    "ui_blip": ("sfx", sfx_ui_blip), "ui_confirm": ("sfx", sfx_ui_confirm),
    "page": ("sfx", sfx_page), "write": ("sfx", sfx_write),
    # world
    "brazier": ("sfx", sfx_brazier), "lever": ("sfx", sfx_lever), "stone_grind": ("sfx", sfx_stone_grind),
    "tv_on": ("sfx", sfx_tv_on), "tv_off": ("sfx", sfx_tv_off), "static_burst": ("sfx", sfx_static_burst),
    "creak": ("sfx", sfx_creak), "whisper": ("sfx", sfx_whisper), "heartbeat": ("sfx", sfx_heartbeat),
    "thunder": ("sfx", sfx_thunder), "growl": ("sfx", sfx_growl), "dog_bark": ("sfx", sfx_dog_bark),
    "dog_pant": ("sfx", sfx_dog_pant), "coin": ("sfx", sfx_coin), "key_turn": ("sfx", sfx_key_turn),
    "drink": ("sfx", sfx_drink), "riddle_correct": ("sfx", sfx_riddle_correct),
    "riddle_wrong": ("sfx", sfx_riddle_wrong), "wake": ("sfx", sfx_wake), "sleep": ("sfx", sfx_sleep),
    "clock_chime": ("sfx", sfx_clock_chime), "gear_tick": ("sfx", sfx_gear_tick),
    "wind_gust": ("sfx", sfx_wind_gust), "drip": ("sfx", sfx_drip), "wood_knock": ("sfx", sfx_wood_knock),
    "glass_break": ("sfx", sfx_glass_break), "chain_rattle": ("sfx", sfx_chain_rattle),
    "seagull_wrong": ("sfx", sfx_seagull_wrong), "tape_measure": ("sfx", sfx_tape_measure),
    "phone_ring": ("sfx", sfx_phone_ring), "photo_click": ("sfx", sfx_photo_click),
}


# ===========================================================================
# Pipeline
# ===========================================================================

def render(name: str) -> tuple[np.ndarray, str]:
    """Render one catalogue entry; returns (samples, kind)."""
    kind, fn = CATALOG[name]
    x = np.asarray(fn(rng_for(name)), dtype=np.float64)
    if not np.all(np.isfinite(x)):
        raise ValueError("%s produced non-finite samples" % name)
    if kind == "ambience":
        x = S.make_loop(x, LOOP_XFADE)
        x = S.hp1(x, 18.0, circular=True)  # DC block / sub-sonic cleanup
        x = S.normalize(x, 0.0)
        x = S.softclip(x, knee=0.6)
        x = S.normalize(x, PEAK_OVERRIDE_DB.get(name, AMB_PEAK_DB))
    else:
        x = S.hp1(x, 18.0)
        x = S.normalize(x, 0.0)
        x = S.softclip(x, knee=0.7)
        x = S.fade(x, 0.001, 0.008)
        x = S.normalize(x, SFX_PEAK_DB)
    return x, kind


def output_path(name: str, kind: str) -> str:
    return os.path.join(AMB_DIR if kind == "ambience" else SFX_DIR, name + ".wav")


def check_wav(path: str, expect_loop: bool) -> int:
    """Re-read a written file's RIFF header with struct and assert its format.
    Returns the number of frames."""
    with open(path, "rb") as fh:
        raw = fh.read()
    assert raw[:4] == b"RIFF" and raw[8:12] == b"WAVE", "%s: not a RIFF/WAVE file" % path
    assert struct.unpack("<I", raw[4:8])[0] == len(raw) - 8, "%s: bad RIFF size" % path
    pos, chunks = 12, {}
    while pos + 8 <= len(raw):
        cid, size = struct.unpack("<4sI", raw[pos:pos + 8])
        chunks[cid] = raw[pos + 8:pos + 8 + size]
        pos += 8 + size + (size & 1)
    fmt = struct.unpack("<HHIIHH", chunks[b"fmt "][:16])
    assert fmt == (1, 1, SR, SR * 2, 2, 16), "%s: unexpected fmt %r" % (path, fmt)
    assert b"data" in chunks and len(chunks[b"data"]) % 2 == 0, "%s: bad data chunk" % path
    frames = len(chunks[b"data"]) // 2
    if expect_loop:
        assert b"smpl" in chunks and len(chunks[b"smpl"]) == 60, "%s: missing smpl chunk" % path
        s = struct.unpack("<15I", chunks[b"smpl"])
        assert s[7] == 1 and s[10] == 0 and s[11] == 0 and s[12] == frames - 1, "%s: bad loop %r" % (path, s)
    else:
        assert b"smpl" not in chunks, "%s: one-shot must not loop" % path
    return frames


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Generate ANTEROOM's procedural audio assets.")
    ap.add_argument("--only", action="append", default=[], metavar="SUBSTR",
                    help="only render names containing SUBSTR (repeatable)")
    ap.add_argument("--list", action="store_true", help="list the catalogue and exit")
    args = ap.parse_args(argv)

    names = [n for n in CATALOG if not args.only or any(s in n for s in args.only)]
    if args.list:
        for n in names:
            print("%-9s %s" % (CATALOG[n][0], n))
        return 0
    if not names:
        print("nothing matches", args.only, file=sys.stderr)
        return 1

    os.makedirs(AMB_DIR, exist_ok=True)
    os.makedirs(SFX_DIR, exist_ok=True)
    t_start = time.time()
    written = []
    total_bytes = 0
    for name in names:
        t0 = time.time()
        x, kind = render(name)
        path = output_path(name, kind)
        size = S.write_wav(path, x, loop=(kind == "ambience"))
        total_bytes += size
        written.append((path, kind == "ambience"))
        print("%-9s %-16s %6.2fs %7.1f KB  peak %5.1f dB  rms %5.1f dB  (%.2fs)" % (
            kind, name, len(x) / SR, size / 1024.0, S.to_db(S.peak(x)), S.to_db(S.rms(x)), time.time() - t0))

    # Verify every file we wrote really is a 22050 Hz / 16-bit PCM mono WAV.
    frames = 0
    for path, is_loop in written:
        frames += check_wav(path, is_loop)
    print("verified %d files, %.1f MB, %.1f s of audio, generated in %.1f s" % (
        len(written), total_bytes / 1e6, frames / SR, time.time() - t_start))
    return 0


if __name__ == "__main__":
    sys.exit(main())
