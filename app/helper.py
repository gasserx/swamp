#!/usr/bin/env python3
"""Omamp helper.

  helper.py probe <path-or-url>...   one JSON line of tags per track
  helper.py scan <dir>...            probe every audio file below each dir
  helper.py m3u <file.m3u>           probe every entry of a playlist file
  helper.py spectrum                 19 band levels (0-16) per line, ~30 fps,
                                     captured from the default output's monitor
"""
import array
import cmath
import json
import urllib.parse
import math
import os
import re
import stat
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

AUDIO_EXT = {".mp3", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".aac", ".wav",
             ".wma", ".mka", ".aiff", ".aif", ".ape", ".wv", ".mp2"}


# Tag cache: path -> [mtime, size, info]. Re-adding a library only probes
# files that are new or changed since the last time.
CACHE_PATH = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
                          "swamp", "tags.json")
_cache = None
_cache_dirty = 0
_cache_lock = threading.Lock()


def cache():
    global _cache
    if _cache is None:
        try:
            with open(CACHE_PATH, encoding="utf-8") as fh:
                _cache = json.load(fh)
        except Exception:
            _cache = {}
    return _cache


def save_cache(force=False):
    global _cache_dirty
    with _cache_lock:
        if _cache is None or not _cache_dirty or (not force and _cache_dirty < 500):
            return
        _cache_dirty = 0
        data = json.dumps(_cache, separators=(",", ":"))
    try:
        # private: keys are track paths/URLs, which can carry stream credentials
        os.makedirs(os.path.dirname(CACHE_PATH), mode=0o700, exist_ok=True)
        tmp = CACHE_PATH + ".tmp"
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass
        with os.fdopen(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600),
                       "w", encoding="utf-8") as fh:
            fh.write(data)
        os.replace(tmp, CACHE_PATH)
    except OSError:
        pass


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def probe(src):
    emit(tags_of(src))


def tags_of(src):
    """Tags for one file, from the cache when the file is unchanged."""
    global _cache_dirty
    if "://" in src:
        return read_tags(src)
    try:
        st = os.stat(src)
        key = [int(st.st_mtime), st.st_size]
    except OSError:
        return read_tags(src)
    c = cache()
    hit = c.get(src)
    if hit and hit[:2] == key:
        return hit[2]
    info = read_tags(src)
    with _cache_lock:
        c[src] = key + [info]
        _cache_dirty += 1
    save_cache()
    return info


def probe_many(paths):
    """Probe in parallel (ffprobe is the slow part) but emit in order."""
    paths = list(paths)
    if not paths:
        return
    cache()
    with ThreadPoolExecutor(max_workers=min(16, (os.cpu_count() or 4) * 2)) as ex:
        for info in ex.map(tags_of, paths):
            emit(info)
    save_cache(force=True)


def has_secret(url):
    """True if a URL carries user:pass, a query string or a fragment (often tokens)."""
    try:
        u = urllib.parse.urlsplit(url)
    except ValueError:
        return True
    return bool(u.username or u.password or u.query or u.fragment)


def read_tags(src):
    is_url = "://" in src
    if is_url:
        try:
            u = urllib.parse.urlsplit(src)
            base = urllib.parse.unquote(u.path.rstrip("/").rsplit("/", 1)[-1]) or u.hostname or "stream"
        except ValueError:
            base = "stream"
    else:
        base = os.path.basename(src)
    info = {"path": src, "title": os.path.splitext(base)[0] or base, "artist": "",
            "dur": 0, "kbps": 0, "khz": 0, "ch": 2}
    # ffprobe only takes its input on the command line, where other local users can
    # read it: never hand it a URL with credentials or tokens (it plays fine, untagged)
    if is_url and has_secret(src):
        return info
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format",
             "-show_streams", "-select_streams", "a:0", src],
            capture_output=True, text=True, timeout=8 if is_url else 20).stdout
        data = json.loads(out or "{}")
    except Exception:
        data = {}
    fmt = data.get("format", {})
    tags = {k.lower(): v for k, v in fmt.get("tags", {}).items()}
    st = (data.get("streams") or [{}])[0]
    tags.update({k.lower(): v for k, v in st.get("tags", {}).items() if k.lower() not in tags})
    if tags.get("title"):
        info["title"] = tags["title"].strip()
    info["artist"] = (tags.get("artist") or tags.get("album_artist") or "").strip()
    if not tags.get("title") and not info["artist"] and is_url:
        info["title"] = tags.get("icy-name") or info["title"]
    try:
        info["dur"] = int(float(fmt.get("duration", 0)) * 1000)
    except ValueError:
        pass
    br = st.get("bit_rate") or fmt.get("bit_rate") or 0
    try:
        info["kbps"] = int(round(int(br) / 1000))
    except ValueError:
        pass
    try:
        info["khz"] = int(round(int(st.get("sample_rate", 0)) / 1000))
    except ValueError:
        pass
    info["ch"] = int(st.get("channels", 2) or 2)
    return info


def walk(root):
    for d, dirs, files in os.walk(root, followlinks=True):
        dirs.sort(key=str.lower)
        for f in sorted(files, key=str.lower):
            if os.path.splitext(f)[1].lower() in AUDIO_EXT:
                yield os.path.join(d, f)


def scan(root):
    probe_many(walk(root))


def m3u(path):
    probe_many(m3u_entries(path))


def m3u_entries(path):
    base = os.path.dirname(path)
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "://" not in line and not os.path.isabs(line):
                line = os.path.join(base, line)
            yield line


def fft(x):
    n = len(x)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            x[i], x[j] = x[j], x[i]
    size = 2
    while size <= n:
        w = cmath.exp(-2j * math.pi / size)
        half = size // 2
        for start in range(0, n, size):
            wk = 1
            for k in range(start, start + half):
                t = wk * x[k + half]
                x[k + half] = x[k] - t
                x[k] += t
                wk *= w
        size <<= 1
    return x


def spectrum():
    import signal
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    rate, n, bands = 22050, 1024, 19
    hop = rate // 30
    window = [0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)) for i in range(n)]
    # log-spaced band edges, 50 Hz .. 10 kHz, as FFT bin indices
    edges = [50 * (10000 / 50) ** (b / bands) for b in range(bands + 1)]
    bins = [max(1, int(f * n / rate)) for f in edges]
    proc = subprocess.Popen(
        ["pw-record", "-P", "{ stream.capture.sink = true node.name = swamp-vis }",
         "--rate", str(rate), "--channels", "1", "--format", "s16", "--raw",
         "--latency", "20ms", "-"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    buf = array.array("h", [0] * n)
    try:
        while True:
            chunk = proc.stdout.read(hop * 2)
            if not chunk:
                break
            new = array.array("h")
            new.frombytes(chunk[: len(chunk) // 2 * 2])
            buf = buf[len(new):] + new if len(new) < n else new[-n:]
            mags = fft([buf[i] / 32768.0 * window[i] for i in range(n)])
            out = []
            for b in range(bands):
                lo, hi = bins[b], max(bins[b] + 1, bins[b + 1])
                p = max(abs(mags[k]) for k in range(lo, hi))
                db = 20 * math.log10(p + 1e-9) + b * 0.6  # tilt: music has less treble energy
                out.append(str(max(0, min(16, int((db + 22) * 16 / 46 + 0.5)))))
            sys.stdout.write(" ".join(out) + "\n")
            sys.stdout.flush()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
    finally:
        proc.terminate()


def place(title, w, h):
    """Resize the floating window to w x h but keep its top-left corner where it is
    (Hyprland resizes around the centre), nudged so it stays inside the work area."""
    import json, subprocess
    def hy(*a):
        return subprocess.run(["hyprctl", *a], capture_output=True, text=True).stdout
    cl = [c for c in json.loads(hy("clients", "-j") or "[]") if c.get("title") == title]
    if not cl:
        return
    c = cl[0]
    sel = 'window = "address:%s"' % c["address"]
    w, h = int(w), int(h)
    x, y = c["at"]
    mon = next((m for m in json.loads(hy("monitors", "-j") or "[]") if m["id"] == c["monitor"]), None)
    if mon and not c["workspace"]["name"].startswith("special:"):
        l, t, r, b = (mon.get("reserved") or [0, 0, 0, 0])
        sc = mon.get("scale") or 1
        mw, mh = mon["width"] / sc, mon["height"] / sc
        if mon.get("transform", 0) % 2:
            mw, mh = mh, mw
        x0, y0 = mon["x"] + l, mon["y"] + t
        x1, y1 = mon["x"] + mw - r, mon["y"] + mh - b
        x = int(max(x0, min(x, x1 - w)))
        y = int(max(y0, min(y, y1 - h)))
    # one batch, so there is no frame at the centred position in between
    hy("--batch", "dispatch hl.dsp.window.resize({ x = %d, y = %d, %s }) ; "
                  "dispatch hl.dsp.window.move({ x = %d, y = %d, %s })" % (w, h, sel, x, y, sel))


LIST_NAME = re.compile(r"swamp-list\.[A-Za-z0-9]{6,}")


def take_list(path):
    """Read and delete a launcher list file, but only a genuine one: named
    swamp-list.XXXXXX directly in $XDG_RUNTIME_DIR (or /tmp), a regular file
    (no symlink) owned by us and not readable by anyone else. Anything else
    is ignored and left alone."""
    base = os.path.realpath(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
    name = os.path.basename(path)
    if not LIST_NAME.fullmatch(name) or os.path.realpath(os.path.dirname(path)) != base:
        return []
    path = os.path.join(base, name)
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    except OSError:
        return []
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid() or st.st_mode & 0o077:
            return []
        with os.fdopen(fd, encoding="utf-8", errors="replace") as fh:
            fd = None
            data = fh.read()
    finally:
        if fd is not None:
            os.close(fd)
    try:
        os.unlink(path)
    except OSError:
        pass
    return [x for x in data.split("\0") if x]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "probe" and args == ["-"]:
        # NUL-separated paths on stdin (keeps URLs out of the process list). Nothing
        # in this stream is ever treated as a command, whatever the names contain.
        args = [x for x in sys.stdin.read().split("\0") if x]
    elif cmd == "probe-list":
        # a list file written by the launcher: read it, then delete it
        args = take_list(args[0]) if args else []
        cmd = "probe"
    if cmd == "probe":
        def expand():
            for a in args:
                if os.path.isdir(a):
                    yield from walk(a)
                elif a.lower().endswith((".m3u", ".m3u8")) and "://" not in a:
                    yield from m3u_entries(a)
                else:
                    yield a
        probe_many(expand())
    elif cmd == "scan":
        for a in args:
            scan(a)
    elif cmd == "m3u":
        for a in args:
            m3u(a)
    elif cmd == "place":
        place(*args[:3])
    elif cmd == "spectrum":
        spectrum()


if __name__ == "__main__":
    main()
