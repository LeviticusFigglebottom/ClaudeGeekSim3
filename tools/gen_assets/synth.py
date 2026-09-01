"""synth.py -- a small pure-numpy synthesis toolkit for ANTEROOM's asset generator.

Everything here works on 1-D float64 numpy arrays at ``SR`` = 22050 Hz with a
nominal range of [-1, 1]. Lengths are always given in *samples* (use ``N()`` to
convert seconds). Only numpy and the standard library are used.

Design notes
------------
* **Filters** are applied in the frequency domain: the exact transfer function
  of a one-pole or RBJ biquad is evaluated on the FFT grid and multiplied in.
  With ``circular=True`` the result is the filter's *circular* convolution,
  which is exactly what a seamless loop wants (the decay tail wraps into the
  head). One-shots are zero-padded so nothing wraps.
* **Time-varying filters** (sweeps, moving formants) use a short-time Fourier
  transform where each frame gets its own biquad response.
* **Reverb** is a Schroeder/Freeverb-style network (parallel damped combs into
  series allpasses) run with block recursion -- pure numpy, no per-sample
  Python loop.
* **Determinism**: all randomness comes from an explicit
  ``numpy.random.Generator`` passed in by the caller.
"""
from __future__ import annotations

import math
import struct

import numpy as np

SR = 22050
TWO_PI = 2.0 * math.pi


# ---------------------------------------------------------------------------
# Basics
# ---------------------------------------------------------------------------

def N(seconds: float) -> int:
    """Seconds -> samples (at least 1)."""
    return max(1, int(round(seconds * SR)))


def t_axis(n: int) -> np.ndarray:
    """Time axis in seconds for ``n`` samples."""
    return np.arange(n) / SR


def db(gain_db: float) -> float:
    """Decibels -> linear amplitude."""
    return 10.0 ** (gain_db / 20.0)


def to_db(lin: float) -> float:
    """Linear amplitude -> decibels (floored at -200 dB)."""
    return 20.0 * math.log10(max(float(lin), 1e-10))


def peak(x: np.ndarray) -> float:
    return float(np.max(np.abs(x))) if len(x) else 0.0


def rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(x)))) if len(x) else 0.0


def zeros(n: int) -> np.ndarray:
    return np.zeros(n, dtype=np.float64)


def impulse(n: int, at: int = 0) -> np.ndarray:
    """A unit impulse in ``n`` samples of silence."""
    x = zeros(n)
    x[at] = 1.0
    return x


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    """Zero-pad (or truncate) ``x`` to exactly ``n`` samples."""
    if len(x) >= n:
        return np.array(x[:n], copy=True)
    return np.concatenate([x, zeros(n - len(x))])


def _pow2(n: int) -> int:
    return 1 << max(1, int(n - 1)).bit_length()


def _freq_array(freq, n: int) -> np.ndarray:
    """Broadcast a scalar or per-sample array to length ``n``."""
    f = np.asarray(freq, dtype=np.float64)
    if f.ndim == 0:
        return np.full(n, float(f))
    if len(f) != n:
        raise ValueError("array length %d != %d" % (len(f), n))
    return f


# ---------------------------------------------------------------------------
# Oscillators
# ---------------------------------------------------------------------------

def phasor(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """Phase in cycles [0, 1) for an instantaneous frequency (scalar or array)."""
    f = _freq_array(freq, n)
    ph = np.cumsum(f) / SR
    ph = ph - ph[0] + phase0
    return np.mod(ph, 1.0)


def sine(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    return np.sin(TWO_PI * phasor(freq, n, phase0))


def saw(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """Naive sawtooth (aliases at high pitch; low-pass it)."""
    return 2.0 * phasor(freq, n, phase0) - 1.0


def square(freq, n: int, phase0: float = 0.0, duty: float = 0.5) -> np.ndarray:
    return np.where(phasor(freq, n, phase0) < duty, 1.0, -1.0)


def triangle(freq, n: int, phase0: float = 0.0) -> np.ndarray:
    return 1.0 - 4.0 * np.abs(phasor(freq, n, phase0) - 0.5)


_OSC = {"sine": sine, "saw": saw, "square": square, "triangle": triangle}


def osc(shape: str, freq, n: int, phase0: float = 0.0) -> np.ndarray:
    return _OSC[shape](freq, n, phase0)


def detuned(shape: str, freq, n: int, voices: int = 3, spread_cents: float = 8.0,
            rng: np.random.Generator | None = None) -> np.ndarray:
    """Sum of ``voices`` copies spread evenly across +-spread_cents (unison/chorus).

    ``freq`` may be an array (vibrato, glides). Random start phases if ``rng``.
    """
    f = _freq_array(freq, n)
    out = zeros(n)
    for i in range(voices):
        cents = 0.0 if voices == 1 else -spread_cents + 2.0 * spread_cents * i / (voices - 1)
        ph = float(rng.random()) if rng is not None else 0.0
        out += osc(shape, f * 2.0 ** (cents / 1200.0), n, ph)
    return out / voices


def fm(fc, ratio: float, index, n: int, phase0: float = 0.0) -> np.ndarray:
    """Two-operator FM: carrier ``fc`` modulated by a sine at ``fc*ratio``.

    ``index`` may be an envelope array (bright attack that mellows out).
    """
    f = _freq_array(fc, n)
    idx = _freq_array(index, n)
    mod = np.sin(TWO_PI * phasor(f * ratio, n))
    return np.sin(TWO_PI * phasor(f, n, phase0) + idx * mod)


# ---------------------------------------------------------------------------
# Noise
# ---------------------------------------------------------------------------

def white(rng: np.random.Generator, n: int) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def pink(rng: np.random.Generator, n: int) -> np.ndarray:
    """Pink noise: Paul Kellet's 3-pole approximation (parallel one-poles),
    evaluated exactly in the frequency domain. Peak-normalised."""
    w = white(rng, n)
    nfft = _pow2(n)
    freqs = np.fft.rfftfreq(nfft, 1.0 / SR)
    z = np.exp(-1j * TWO_PI * freqs / SR)  # z^-1 on the grid
    H = (0.0990460 / (1 - 0.99765 * z) + 0.2965164 / (1 - 0.96300 * z)
         + 1.0526913 / (1 - 0.57000 * z) + 0.1848)
    H *= response(*onepole("hp", 10.0), freqs)  # drop the sub-sonic tail (1/f -> inf at DC)
    y = np.fft.irfft(np.fft.rfft(w, nfft) * H, nfft)[:n]
    return y / max(peak(y), 1e-9)


def brown(rng: np.random.Generator, n: int, cutoff: float = 18.0) -> np.ndarray:
    """Brown(ish) noise: white through a one-pole low-pass. Peak-normalised."""
    y = hp1(lp1(white(rng, n), cutoff), 8.0)
    return y / max(peak(y), 1e-9)


def noise(rng: np.random.Generator, n: int, color: str = "white") -> np.ndarray:
    return {"white": white, "pink": pink, "brown": brown}[color](rng, n)


# ---------------------------------------------------------------------------
# Filters (frequency-domain application of one-pole / biquad responses)
# ---------------------------------------------------------------------------

def biquad(kind: str, fc, q=0.7071, gain_db: float = 0.0):
    """RBJ cookbook biquad coefficients. ``fc``/``q`` may be arrays.

    Returns ``(b, a)`` with shape ``(..., 3)``, ``a[...,0] == 1``.
    kind: 'lp', 'hp', 'bp' (constant 0 dB peak), 'notch', 'peak'.
    """
    fc = np.asarray(fc, dtype=np.float64)
    q = np.asarray(q, dtype=np.float64)
    w0 = TWO_PI * np.clip(fc, 1.0, SR * 0.499) / SR
    cw, sw = np.cos(w0), np.sin(w0)
    alpha = sw / (2.0 * np.maximum(q, 0.05))
    A = 10.0 ** (gain_db / 40.0)
    a0, a1, a2 = 1.0 + alpha, -2.0 * cw, 1.0 - alpha
    if kind == "lp":
        b0, b1, b2 = (1.0 - cw) / 2.0, 1.0 - cw, (1.0 - cw) / 2.0
    elif kind == "hp":
        b0, b1, b2 = (1.0 + cw) / 2.0, -(1.0 + cw), (1.0 + cw) / 2.0
    elif kind == "bp":
        b0, b1, b2 = alpha, np.zeros_like(alpha), -alpha
    elif kind == "notch":
        b0, b1, b2 = np.ones_like(alpha), -2.0 * cw, np.ones_like(alpha)
    elif kind == "peak":
        b0, b1, b2 = 1.0 + alpha * A, -2.0 * cw, 1.0 - alpha * A
        a0, a2 = 1.0 + alpha / A, 1.0 - alpha / A
    else:
        raise ValueError("unknown biquad kind %r" % kind)
    b = np.stack([b0, b1, b2], axis=-1) / a0[..., None]
    a = np.stack([a0, a1, a2], axis=-1) / a0[..., None]
    return b, a


def onepole(kind: str, fc: float):
    """First-order low-pass ('lp') or high-pass ('hp') coefficients (b, a)."""
    p = math.exp(-TWO_PI * max(fc, 0.1) / SR)
    if kind == "lp":
        return np.array([1.0 - p, 0.0, 0.0]), np.array([1.0, -p, 0.0])
    if kind == "hp":
        return np.array([(1 + p) / 2, -(1 + p) / 2, 0.0]), np.array([1.0, -p, 0.0])
    raise ValueError(kind)


def response(b, a, freqs: np.ndarray) -> np.ndarray:
    """Complex response of the IIR filter (b, a) at ``freqs`` Hz."""
    z = np.exp(-1j * TWO_PI * freqs / SR)
    b = np.asarray(b)[..., None]
    a = np.asarray(a)[..., None]
    num = b[..., 0, :] + b[..., 1, :] * z + b[..., 2, :] * z * z
    den = a[..., 0, :] + a[..., 1, :] * z + a[..., 2, :] * z * z
    return num / den


def apply_response(x: np.ndarray, H_fn, circular: bool = False) -> np.ndarray:
    """Multiply the spectrum of ``x`` by ``H_fn(freqs)``.

    Circular: FFT of exactly len(x), so filter tails wrap around (loops).
    Otherwise zero-pad by a second so nothing wraps.
    """
    n = len(x)
    nfft = n if circular else _pow2(n + SR)
    freqs = np.fft.rfftfreq(nfft, 1.0 / SR)
    y = np.fft.irfft(np.fft.rfft(x, nfft) * H_fn(freqs), nfft)
    return y[:n]


def filt(x, b, a, circular: bool = False, passes: int = 1) -> np.ndarray:
    """Apply IIR filter (b, a) ``passes`` times (cascade)."""
    return apply_response(x, lambda f: response(b, a, f) ** passes, circular)


def lowpass(x, fc, q=0.7071, passes=1, circular=False):
    return filt(x, *biquad("lp", fc, q), circular=circular, passes=passes)


def highpass(x, fc, q=0.7071, passes=1, circular=False):
    return filt(x, *biquad("hp", fc, q), circular=circular, passes=passes)


def bandpass(x, fc, q=1.0, passes=1, circular=False):
    return filt(x, *biquad("bp", fc, q), circular=circular, passes=passes)


def notch(x, fc, q=4.0, circular=False):
    return filt(x, *biquad("notch", fc, q), circular=circular)


def peak_eq(x, fc, q=1.0, gain_db=6.0, circular=False):
    return filt(x, *biquad("peak", fc, q, gain_db), circular=circular)


def lp1(x, fc, circular=False, passes=1):
    """One-pole low-pass."""
    return filt(x, *onepole("lp", fc), circular=circular, passes=passes)


def hp1(x, fc, circular=False, passes=1):
    """One-pole high-pass."""
    return filt(x, *onepole("hp", fc), circular=circular, passes=passes)


def band(x, lo, hi, passes=2, circular=False):
    """Band-limit with 2nd-order Butterworth-ish HP at ``lo`` and LP at ``hi``."""
    return lowpass(highpass(x, lo, passes=passes, circular=circular), hi,
                   passes=passes, circular=circular)


def formant(x, freqs, q=8.0, gains=None, circular=False):
    """Parallel band-pass bank (vowel-like resonances)."""
    freqs = list(freqs)
    gains = list(gains) if gains is not None else [1.0] * len(freqs)
    qs = list(q) if np.ndim(q) else [q] * len(freqs)

    def H(f):
        tot = np.zeros(len(f), dtype=complex)
        for fc, g, qq in zip(freqs, gains, qs):
            tot += g * response(*biquad("bp", fc, qq), f)
        return tot

    return apply_response(x, H, circular)


# Male-ish vowel formants (F1, F2, F3) in Hz.
VOWELS = {
    "a": (700, 1220, 2600), "e": (530, 1840, 2480), "i": (300, 2250, 3010),
    "o": (570, 840, 2410), "u": (440, 1020, 2240),
}


def stft_filter(x, kind: str, fc, q=1.0, gain_db: float = 0.0, frame: int = 1024,
                hop: int | None = None, circular: bool = False) -> np.ndarray:
    """Time-varying biquad: ``fc`` and ``q`` may be per-sample arrays.

    Short-time Fourier transform with a sqrt-Hann window; each frame is
    multiplied by the biquad response for the fc/q at its centre and
    overlap-added. ``circular`` wraps the signal so loops stay seamless.
    """
    n = len(x)
    hop = hop or frame // 4
    fc = _freq_array(fc, n)
    q = _freq_array(q, n)
    pad = frame
    if circular:
        xp = np.concatenate([x[-pad:], x, x[:pad]])
        fcp = np.concatenate([fc[-pad:], fc, fc[:pad]])
        qp = np.concatenate([q[-pad:], q, q[:pad]])
    else:
        xp = np.concatenate([zeros(pad), x, zeros(pad)])
        fcp = np.concatenate([np.full(pad, fc[0]), fc, np.full(pad, fc[-1])])
        qp = np.concatenate([np.full(pad, q[0]), q, np.full(pad, q[-1])])
    extra = (-(len(xp) - frame)) % hop
    if extra:
        xp = np.concatenate([xp, zeros(extra)])
        fcp = np.concatenate([fcp, np.full(extra, fcp[-1])])
        qp = np.concatenate([qp, np.full(extra, qp[-1])])
    nfr = (len(xp) - frame) // hop + 1
    win = np.sqrt(np.hanning(frame + 1)[:-1])
    frames = np.lib.stride_tricks.sliding_window_view(xp, frame)[::hop][:nfr] * win
    centres = np.arange(nfr) * hop + frame // 2
    b, a = biquad(kind, fcp[centres], qp[centres], gain_db)
    H = response(b, a, np.fft.rfftfreq(frame, 1.0 / SR))
    Y = np.fft.irfft(np.fft.rfft(frames, axis=1) * H, frame, axis=1) * win
    ratio = frame // hop
    out = np.zeros((nfr + ratio - 1, hop))
    wsum = np.zeros((nfr + ratio - 1, hop))
    w2 = (win * win).reshape(ratio, hop)
    for j in range(ratio):
        out[j:j + nfr] += Y[:, j * hop:(j + 1) * hop]
        wsum[j:j + nfr] += w2[j]
    out = (out / np.maximum(wsum, 1e-6)).ravel()
    return out[pad:pad + n]


# ---------------------------------------------------------------------------
# Envelopes and control signals
# ---------------------------------------------------------------------------

def _curve(n: int, k: float) -> np.ndarray:
    """0 -> 1 over n samples with exponential shape (k>0: fast start)."""
    if n <= 0:
        return np.zeros(0)
    u = np.linspace(0.0, 1.0, n, endpoint=False)
    if abs(k) < 1e-6:
        return u
    return (1.0 - np.exp(-k * u)) / (1.0 - math.exp(-k))


def adsr(n: int, attack: float, decay: float, sustain: float, release: float,
         curve: float = 4.0) -> np.ndarray:
    """Attack/decay/sustain/release envelope (times in seconds, sustain level 0..1).

    The sustain segment fills whatever is left of ``n``; if there is no room
    the segments are scaled down proportionally.
    """
    na, nd, nr = N(attack) if attack > 0 else 0, N(decay) if decay > 0 else 0, N(release) if release > 0 else 0
    tot = na + nd + nr
    if tot > n:
        s = n / tot
        na, nd = int(na * s), int(nd * s)
        nr = n - na - nd
    ns = n - na - nd - nr
    env = np.concatenate([
        _curve(na, curve),
        1.0 - (1.0 - sustain) * _curve(nd, curve),
        np.full(ns, sustain),
        sustain * (1.0 - _curve(nr, curve)),
    ])
    return env[:n]


def decay_env(n: int, tau: float, attack: float = 0.0) -> np.ndarray:
    """Exponential decay exp(-t/tau) with an optional linear attack ramp."""
    t = t_axis(n)
    env = np.exp(-t / max(tau, 1e-5))
    na = N(attack) if attack > 0 else 0
    if na > 0:
        env[:na] *= np.linspace(0.0, 1.0, na, endpoint=False)
    return env


def perc(n: int, attack: float = 0.003, tau: float = 0.1) -> np.ndarray:
    """Percussive envelope: short attack then exponential decay."""
    return decay_env(n, tau, attack)


def line(n: int, v0: float, v1: float) -> np.ndarray:
    return np.linspace(v0, v1, n, endpoint=False)


def expline(n: int, v0: float, v1: float) -> np.ndarray:
    """Exponential (constant-ratio) interpolation, good for frequency glides."""
    return v0 * (v1 / v0) ** np.linspace(0.0, 1.0, n, endpoint=False)


def bump(n: int, centre: float, width: float) -> np.ndarray:
    """Raised-cosine bump of ``width`` seconds centred at ``centre`` seconds."""
    t = t_axis(n)
    u = (t - centre) / max(width, 1e-6)
    return np.where(np.abs(u) < 0.5, 0.5 + 0.5 * np.cos(TWO_PI * u), 0.0)


def fade(x: np.ndarray, fin: float = 0.005, fout: float = 0.02) -> np.ndarray:
    """Apply linear fade-in/out (seconds). Returns a copy."""
    y = np.array(x, dtype=np.float64, copy=True)
    ni, no = min(N(fin), len(y)) if fin > 0 else 0, min(N(fout), len(y)) if fout > 0 else 0
    if ni:
        y[:ni] *= np.linspace(0.0, 1.0, ni, endpoint=False)
    if no:
        y[-no:] *= np.linspace(1.0, 0.0, no, endpoint=False)
    return y


def lfo(n: int, rate, shape: str = "sine", phase0: float = 0.0) -> np.ndarray:
    """Low-frequency oscillator in [-1, 1]; ``rate`` may be an array."""
    return osc(shape, rate, n, phase0)


def random_lfo(rng: np.random.Generator, n: int, rate: float, periodic: bool = False) -> np.ndarray:
    """Smooth random control signal in [-1, 1]: cosine-interpolated random
    points at ``rate`` Hz. ``periodic`` wraps so a loop has no seam."""
    m = max(1, int(round(rate * n / SR)))
    pts = rng.uniform(-1.0, 1.0, m + 1)
    if periodic:
        pts[-1] = pts[0]
    pos = np.arange(n) * (m / n)
    i = np.minimum(pos.astype(int), m - 1)
    frac = pos - i
    s = 0.5 - 0.5 * np.cos(math.pi * frac)
    return pts[i] * (1.0 - s) + pts[i + 1] * s


def loop_freq(freq: float, n: int) -> float:
    """Nearest frequency with a whole number of cycles in ``n`` samples."""
    cycles = max(1, int(round(freq * n / SR)))
    return cycles * SR / n


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

def impulses(rng: np.random.Generator, n: int, rate, shape: float = 2.0) -> np.ndarray:
    """Poisson impulses at ``rate`` per second (scalar or array) with random
    signed amplitudes skewed towards small values by ``shape``."""
    r = _freq_array(rate, n)
    hit = rng.random(n) < r / SR
    out = zeros(n)
    k = int(np.count_nonzero(hit))
    out[hit] = rng.random(k) ** shape * rng.choice([-1.0, 1.0], k)
    return out


def pulse_train(rate, n: int, rng: np.random.Generator | None = None,
                jitter: float = 0.0, phase0: float = 0.0) -> np.ndarray:
    """Unit impulses at every cycle of an instantaneous ``rate`` (Hz array).

    ``jitter`` randomises impulse amplitudes (0..1) for a rougher texture.
    """
    ph = phasor(rate, n, phase0)
    hits = np.zeros(n, dtype=bool)
    hits[1:] = ph[1:] < ph[:-1]
    out = zeros(n)
    k = int(np.count_nonzero(hits))
    amp = np.ones(k)
    if rng is not None and jitter > 0:
        amp *= 1.0 - jitter * rng.random(k)
    out[hits] = amp
    return out


def place(buf: np.ndarray, snd: np.ndarray, at: float, gain: float = 1.0,
          wrap: bool = False) -> np.ndarray:
    """Add ``snd`` into ``buf`` starting at ``at`` seconds. With ``wrap`` the
    part that runs past the end folds back to the start (circular loops);
    otherwise it is truncated."""
    n = len(buf)
    start = int(round(at * SR))
    if wrap:
        start %= n
    seg = snd * gain
    pos = 0
    while pos < len(seg):
        room = n - start
        take = min(room, len(seg) - pos)
        if take <= 0:
            break
        buf[start:start + take] += seg[pos:pos + take]
        pos += take
        if not wrap:
            break
        start = 0
    return buf


def event_times(rng: np.random.Generator, dur: float, count: int, min_gap: float = 0.5,
                jitter: float = 0.5) -> list[float]:
    """``count`` event times in [0, dur): evenly spaced with random jitter,
    respecting ``min_gap``."""
    if count <= 0:
        return []
    step = dur / count
    times = []
    for i in range(count):
        t = (i + 0.5) * step + rng.uniform(-jitter, jitter) * step * 0.5
        times.append(t % dur)
    times.sort()
    out = []
    for t in times:
        if not out or t - out[-1] >= min_gap:
            out.append(t)
    return out


# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------

def _comb(x: np.ndarray, D: int, g: float, damp: float) -> np.ndarray:
    """Feedback comb with one-zero damping in the loop, block-recursive.

    y[i] = x[i] + g * ((1-damp) * y[i-D] + damp * y[i-D-1])
    """
    n = len(x)
    yp = zeros(n + D + 1)  # y[i] lives at yp[i + D + 1]
    for start in range(0, n, D):
        end = min(start + D, n)
        yp[D + 1 + start:D + 1 + end] = (x[start:end]
                                          + g * ((1.0 - damp) * yp[start + 1:end + 1]
                                                 + damp * yp[start:end]))
    return yp[D + 1:]


def _allpass(x: np.ndarray, D: int, g: float) -> np.ndarray:
    """Schroeder allpass  y[i] = -g x[i] + x[i-D] + g y[i-D], block-recursive."""
    n = len(x)
    xp = np.concatenate([zeros(D), x])
    yp = zeros(n + D)
    for start in range(0, n, D):
        end = min(start + D, n)
        yp[D + start:D + end] = -g * x[start:end] + xp[start:end] + g * yp[start:end]
    return yp[D:]


_COMBS = (0.0253, 0.0269, 0.0290, 0.0307, 0.0322, 0.0338, 0.0353, 0.0367)
_ALLPASSES = (0.0126, 0.0100, 0.0077, 0.0051)


def reverb(x: np.ndarray, rt60: float = 2.0, size: float = 1.0, damp: float = 0.3,
           wet: float = 0.3, dry: float = 1.0, predelay: float = 0.0,
           tone: float | None = None, circular: bool = False) -> np.ndarray:
    """Schroeder reverb: 8 damped parallel combs -> 4 series allpasses.

    ``wet`` is the RMS of the wet signal relative to the dry input (so the
    parameter means the same thing for a click and a drone). ``tone`` low-passes
    the wet signal (one-pole, Hz). ``circular`` renders the input twice around
    and keeps the second pass, so a loop's tail wraps into its head.
    """
    if circular:
        n = len(x)
        y = reverb(np.concatenate([x, x]), rt60, size, damp, wet, 0.0, predelay, tone, False)[n:]
        return dry * x + y
    n = len(x)
    inp = x
    if predelay > 0:
        inp = np.concatenate([zeros(N(predelay)), x])[:n]
    acc = zeros(n)
    for i, d in enumerate(_COMBS):
        D = max(4, int(d * size * SR) + i)  # +i keeps lengths coprime-ish
        g = 10.0 ** (-3.0 * D / SR / max(rt60, 0.01))
        acc += _comb(inp, D, g, damp)
    for d in _ALLPASSES:
        acc = _allpass(acc, max(2, int(d * size * SR)), 0.5)
    if tone:
        acc = lp1(acc, tone)
    acc *= wet * rms(x) / max(rms(acc), 1e-9)
    return dry * x + acc


def echo(x: np.ndarray, delay: float, feedback: float = 0.4, wet: float = 0.5,
         damp: float = 0.3, circular: bool = False) -> np.ndarray:
    """Simple damped feedback echo."""
    if circular:
        n = len(x)
        return x + echo(np.concatenate([x, x]), delay, feedback, wet, damp, False)[n:] - np.concatenate([x, x])[n:]
    D = max(1, N(delay))
    y = _comb(np.concatenate([zeros(D), x])[:len(x)], D, feedback, damp)
    return x + wet * y


def softclip(x: np.ndarray, knee: float = 0.7) -> np.ndarray:
    """Soft-knee limiter: linear below ``knee``, tanh above, never exceeds 1."""
    ax = np.abs(x)
    over = ax > knee
    y = np.array(x, dtype=np.float64, copy=True)
    y[over] = np.sign(x[over]) * (knee + (1.0 - knee) * np.tanh((ax[over] - knee) / (1.0 - knee)))
    return y


def drive(x: np.ndarray, amount: float = 2.0) -> np.ndarray:
    """tanh saturation, unity peak gain."""
    return np.tanh(x * amount) / math.tanh(amount)


def normalize(x: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    p = peak(x)
    return x * (db(peak_db) / p) if p > 1e-9 else x


def set_rms(x: np.ndarray, rms_db: float) -> np.ndarray:
    r = rms(x)
    return x * (db(rms_db) / r) if r > 1e-9 else x


def mix(*layers) -> np.ndarray:
    """Sum layers; each is an array or ``(array, gain_db)``. Shorter layers are
    zero-padded to the longest."""
    parts = [(l, 0.0) if isinstance(l, np.ndarray) else (l[0], float(l[1])) for l in layers]
    n = max(len(p[0]) for p in parts)
    out = zeros(n)
    for sig, g in parts:
        out[:len(sig)] += sig * db(g)
    return out


def reverse(x: np.ndarray) -> np.ndarray:
    return x[::-1].copy()


def resample(x: np.ndarray, factor: float) -> np.ndarray:
    """Vary-speed resample: factor > 1 raises pitch and shortens (linear interp)."""
    n_out = max(1, int(len(x) / factor))
    pos = np.arange(n_out) * factor
    return np.interp(pos, np.arange(len(x)), x)


def make_loop(x: np.ndarray, xfade: float = 0.05) -> np.ndarray:
    """Seamless loop: equal-power crossfade the last ``xfade`` seconds into the
    start and drop them, so the wrap from the last sample to the first is
    continuous. Output is ``xfade`` seconds shorter than the input."""
    n = len(x)
    k = N(xfade)
    if k <= 0 or 2 * k > n:
        return np.array(x, copy=True)
    u = np.linspace(0.0, 1.0, k, endpoint=False)
    fin, fout = np.sin(0.5 * math.pi * u), np.cos(0.5 * math.pi * u)
    y = np.array(x[:n - k], copy=True)
    y[:k] = x[:k] * fin + x[n - k:] * fout
    return y


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def karplus_strong(rng: np.random.Generator, freq: float, n: int, decay: float = 0.996,
                   damp: float = 0.5, brightness: float = 4000.0) -> np.ndarray:
    """Plucked string (Karplus-Strong), block-recursive.

    y[i] = x[i] + decay * ((1-damp) y[i-D] + damp y[i-D-1]); the excitation is
    one period of noise low-passed at ``brightness`` Hz.
    """
    D = max(2, int(round(SR / freq - 0.5)))
    x = zeros(n)
    m = min(D, n)
    exc = lp1(white(rng, m), brightness)
    x[:m] = exc - exc.mean()  # zero-mean so the loop cannot build up DC
    yp = zeros(n + D + 1)
    for start in range(0, n, D):
        end = min(start + D, n)
        yp[D + 1 + start:D + 1 + end] = (x[start:end]
                                          + decay * ((1.0 - damp) * yp[start + 1:end + 1]
                                                     + damp * yp[start:end]))
    y = hp1(yp[D + 1:], 30.0)  # DC blocker
    return y / max(peak(y), 1e-9)


def bell(f0: float, n: int, partials, beat: float = 0.0, rng: np.random.Generator | None = None) -> np.ndarray:
    """Additive bell: ``partials`` = [(ratio, amplitude, decay_seconds), ...].

    ``beat`` adds a slightly detuned twin to each partial (Hz) for warble.
    """
    t = t_axis(n)
    y = zeros(n)
    for ratio, amp, dec in partials:
        ph = float(rng.random()) * TWO_PI if rng is not None else 0.0
        env = amp * np.exp(-t / max(dec, 1e-4))
        y += env * np.sin(TWO_PI * f0 * ratio * t + ph)
        if beat:
            y += 0.5 * env * np.sin(TWO_PI * (f0 * ratio + beat) * t + ph * 0.7)
    return y / max(peak(y), 1e-9)


# ---------------------------------------------------------------------------
# WAV output
# ---------------------------------------------------------------------------

def to_pcm16(x: np.ndarray) -> bytes:
    return (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()


def write_wav(path: str, x: np.ndarray, sr: int = SR, loop: bool = False) -> int:
    """Write 16-bit PCM mono WAV. With ``loop`` a ``smpl`` chunk holding one
    forward loop over the whole file (0 .. n-1) is appended so Godot's importer
    ("Detect From WAV") marks the stream as looping. Returns bytes written."""
    data = to_pcm16(x)
    n = len(x)
    chunks = [
        (b"fmt ", struct.pack("<HHIIHH", 1, 1, sr, sr * 2, 2, 16)),
        (b"data", data),
    ]
    if loop:
        smpl = struct.pack(
            "<IIIIIIIII",
            0,                       # manufacturer
            0,                       # product
            int(1e9 / sr),           # sample period (ns)
            60,                      # MIDI unity note
            0,                       # MIDI pitch fraction
            0,                       # SMPTE format
            0,                       # SMPTE offset
            1,                       # number of sample loops
            0,                       # sampler data bytes
        ) + struct.pack(
            "<IIIIII",
            0,                       # cue point id
            0,                       # type: 0 = forward
            0,                       # start sample
            max(n - 1, 0),           # end sample (inclusive)
            0,                       # fraction
            0,                       # play count: 0 = infinite
        )
        chunks.append((b"smpl", smpl))
    body = b"".join(cid + struct.pack("<I", len(c)) + c + (b"\x00" if len(c) % 2 else b"")
                    for cid, c in chunks)
    blob = b"RIFF" + struct.pack("<I", 4 + len(body)) + b"WAVE" + body
    with open(path, "wb") as fh:
        fh.write(blob)
    return len(blob)
