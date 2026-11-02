#!/usr/bin/env python3
"""sWamp skin backgrounds: one generated scene per skin.

Each scene is 275x288 units (main panel 0-116, playlist 116-288), rendered with
rsvg-convert to ../bg/<skin>.png at 4x (QtSvg can't do blur filters).

  python3 gen.py            render every scene
  python3 gen.py sky ember  render just those
"""
import math
import os
import random
import subprocess
import sys

W, H = 275, 288
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "bg")


class Svg:
    def __init__(self, seed):
        self.r = random.Random(seed)
        self.defs, self.body, self.n = [], [], 0

    def _id(self, p):
        self.n += 1
        return f"{p}{self.n}"

    @staticmethod
    def _stops(stops):
        out = []
        for st in stops:
            o, c, a = (st + (1,))[:3] if len(st) == 2 else st
            out.append(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>')
        return "".join(out)

    def lin(self, stops, x1=0, y1=0, x2=0, y2=1):
        i = self._id("l")
        self.defs.append(f'<linearGradient id="{i}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{self._stops(stops)}</linearGradient>')
        return f"url(#{i})"

    def rad(self, stops, cx=0.5, cy=0.5, r=0.5):
        i = self._id("r")
        self.defs.append(f'<radialGradient id="{i}" cx="{cx}" cy="{cy}" r="{r}">{self._stops(stops)}</radialGradient>')
        return f"url(#{i})"

    def blur(self, sd):
        i = self._id("f")
        self.defs.append(f'<filter id="{i}" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="{sd}"/></filter>')
        return f'filter="url(#{i})"'

    def add(self, *xs):
        self.body.extend(xs)

    def rect(self, fill, x=0, y=0, w=W, h=H, extra=""):
        self.add(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{fill}" {extra}/>')

    def circle(self, cx, cy, r, fill, extra=""):
        self.add(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.2f}" fill="{fill}" {extra}/>')

    def path(self, d, fill="none", extra=""):
        self.add(f'<path d="{d}" fill="{fill}" {extra}/>')

    def svg(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W*4}" height="{H*4}">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>')

    # ---- building blocks -------------------------------------------------
    def stars(self, n, y0=0, y1=H, colors=("#ffffff",), big=0.05, amin=0.3):
        for _ in range(n):
            r = 0.9 if self.r.random() < big else self.r.choice([0.25, 0.3, 0.4, 0.5])
            self.circle(self.r.uniform(0, W), self.r.uniform(y0, y1), r, self.r.choice(colors),
                        f'opacity="{self.r.uniform(amin, 1):.2f}"')

    def glow(self, cx, cy, r, color, a=0.6):
        self.circle(cx, cy, r, self.rad([(0, color, a), (1, color, 0)]))

    def ridge(self, base, top, n, fill, sharp=True, extra=""):
        xs = [i * W / n for i in range(n + 1)]
        pts = [(x + self.r.uniform(-8, 8) * (0 < i < n), self.r.uniform(top, base))
               for i, x in enumerate(xs)]
        if sharp:
            d = f"M0 {H} L0 {pts[0][1]:.1f} " + " ".join(f"L{x:.1f} {y:.1f}" for x, y in pts) + f" L{W} {H} Z"
        else:
            d = f"M0 {H} L0 {pts[0][1]:.1f} "
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                mx = (x0 + x1) / 2
                d += f"C{mx:.1f} {y0:.1f} {mx:.1f} {y1:.1f} {x1:.1f} {y1:.1f} "
            d += f"L{W} {H} Z"
        self.path(d, fill, extra)
        return pts

    def pine(self, x, base, h, fill, extra=""):
        w = h * 0.38
        d = f"M{x:.1f} {base-h:.1f} "
        tiers = 4
        for t in range(tiers):
            yy = base - h + h * (t + 1) / tiers * 0.92
            ww = w * (t + 1) / tiers
            d += f"L{x+ww:.1f} {yy:.1f} L{x+ww*0.45:.1f} {yy:.1f} "
        d += f"L{x+w*0.12:.1f} {base:.1f} L{x-w*0.12:.1f} {base:.1f} "
        for t in reversed(range(tiers)):
            yy = base - h + h * (t + 1) / tiers * 0.92
            ww = w * (t + 1) / tiers
            d += f"L{x-ww*0.45:.1f} {yy:.1f} L{x-ww:.1f} {yy:.1f} "
        self.path(d + "Z", fill, extra)

    def forest(self, base, hmin, hmax, step, fill, extra=""):
        x = -5
        while x < W + 5:
            self.pine(x, base + self.r.uniform(0, 4), self.r.uniform(hmin, hmax), fill, extra)
            x += self.r.uniform(step * 0.6, step * 1.3)
        self.rect(fill, 0, base + 2, W, H - base, extra)

    def cloud(self, cx, cy, s, fill, blur=1.5, a=1):
        f = self.blur(blur)
        g = [f'<g {f} opacity="{a}">']
        for dx, dy, r in [(-1.6, 0.3, 0.9), (-0.7, -0.4, 1.2), (0.5, -0.6, 1.3), (1.6, 0.1, 1.0), (0, 0.4, 1.1)]:
            g.append(f'<circle cx="{cx+dx*s:.1f}" cy="{cy+dy*s:.1f}" r="{r*s:.1f}" fill="{fill}"/>')
        g.append(f'<rect x="{cx-2.3*s:.1f}" y="{cy:.1f}" width="{4.6*s:.1f}" height="{1.2*s:.1f}" rx="{0.6*s:.1f}" fill="{fill}"/></g>')
        self.add("".join(g))

    def buildings(self, base, hmin, hmax, wmin, wmax, fill, lit, lit_p=0.3):
        x = -3
        while x < W:
            w = self.r.uniform(wmin, wmax)
            h = self.r.uniform(hmin, hmax)
            self.rect(fill, x, base - h, w, h + 300)
            if self.r.random() < 0.3:
                self.rect(fill, x + w * 0.4, base - h - 6, 1, 6)
            for wy in range(int(base - h + 3), int(min(H, base + 200)), 4):
                for wx in range(int(x + 2), int(x + w - 2), 3):
                    if self.r.random() < lit_p:
                        self.rect(self.r.choice(lit), wx, wy, 1.4, 1.8, f'opacity="{self.r.uniform(0.4, 1):.2f}"')
            x += w + self.r.uniform(0.5, 3)

    def rain(self, n, color, a=0.25):
        for _ in range(n):
            x, y, l = self.r.uniform(0, W), self.r.uniform(0, H), self.r.uniform(4, 10)
            self.path(f"M{x:.1f} {y:.1f} l{-l*0.18:.1f} {l:.1f}", extra=f'stroke="{color}" stroke-width="0.35" opacity="{a}"')


# ---- scenes ---------------------------------------------------------------

def synthwave():
    s = Svg(1)
    s.rect(s.lin([(0, "#0d0221"), (0.3, "#2b0a4a"), (0.47, "#8a1f7a"), (0.53, "#ff5e7a")]), 0, 0, W, 150)
    s.stars(120, 0, 100, ("#ffffff", "#ffd1f5"))
    sun = s.lin([(0, "#ffe66b"), (0.5, "#ff8a3d"), (1, "#ff2e88")])
    s.glow(190, 110, 70, "#ff4fd8", 0.45)
    s.circle(190, 110, 40, sun)
    for i in range(7):  # sun stripes, cut to the sun's width
        y, hh = 112 + i * 5.5, 1 + i * 0.5
        dy = min(40, max(abs(y - 110), abs(y + hh - 110)))
        half = math.sqrt(max(0, 40 * 40 - dy * dy))
        s.rect("#7a1f6a", 190 - half, y, 2 * half, hh)
    s.ridge(150, 118, 9, "#1e0a3a")
    s.ridge(150, 132, 12, "#120628")
    s.rect(s.lin([(0, "#16052e"), (1, "#05010d")]), 0, 150, W, H - 150)
    vx = 137
    for k in range(-14, 15):
        s.path(f"M{vx} 150 L{vx + k * 42} {H}", extra='stroke="#ff3ad0" stroke-width="0.6" opacity="0.7"')
    for i in range(1, 16):
        y = 150 + (i / 15) ** 2 * (H - 150)
        s.path(f"M0 {y:.1f} L{W} {y:.1f}", extra=f'stroke="#ff3ad0" stroke-width="{0.4 + i * 0.04:.2f}" opacity="0.75"')
    s.rect(s.lin([(0, "#ff3ad0", 0.5), (1, "#ff3ad0", 0)]), 0, 148, W, 14)
    return s


def neonrose():
    s = Svg(2)
    s.rect(s.lin([(0, "#05000a"), (0.6, "#1e0418"), (1, "#3a0a2a")]))
    s.stars(60, 0, 90, ("#ffd1ea",))
    s.glow(70, 60, 60, "#ff3fa4", 0.35)
    s.circle(70, 60, 16, s.rad([(0, "#ffe0f0"), (0.7, "#ff9ad0"), (1, "#ff3fa4", 0.8)]))
    s.buildings(200, 30, 110, 10, 22, "#1a0616", ["#ff3fa4", "#ff9ad0"], 0.15)
    s.buildings(250, 20, 95, 14, 28, "#0b020a", ["#ff3fa4", "#ffd1ea", "#b04dff"], 0.22)
    for _ in range(6):  # neon signs
        x, y = s.r.uniform(10, 260), s.r.uniform(170, 260)
        c = s.r.choice(["#ff3fa4", "#ff9ad0", "#b04dff"])
        s.rect(c, x, y, 2, s.r.uniform(10, 22), f'{s.blur(1.2)} opacity="0.9"')
        s.rect("#ffe0f0", x + 0.6, y, 0.8, 12, 'opacity="0.8"')
    s.rain(160, "#ffb6dc", 0.22)
    return s


def nightshade():
    s = Svg(3)
    s.rect("#04010b")
    for _ in range(14):
        c = s.r.choice(["#6a1fd0", "#a02ad0", "#3a2ab0", "#c03aa0"])
        s.add(f'<ellipse cx="{s.r.uniform(0, W):.1f}" cy="{s.r.uniform(0, 200):.1f}" rx="{s.r.uniform(30, 80):.1f}" ry="{s.r.uniform(12, 40):.1f}" '
              f'fill="{c}" opacity="{s.r.uniform(0.15, 0.4):.2f}" {s.blur(14)} transform="rotate({s.r.uniform(-30, 10):.0f} 137 100)"/>')
    s.stars(320, 0, H, ("#ffffff", "#e0ccff", "#ffd6f5"), big=0.04)
    s.glow(205, 205, 60, "#a24dff", 0.3)
    s.circle(205, 205, 30, s.lin([(0, "#c69aff"), (0.5, "#6a2ac0"), (1, "#1a0640")], 0, 0, 1, 1))
    s.add('<ellipse cx="205" cy="205" rx="52" ry="9" fill="none" stroke="#e0b8ff" stroke-width="2.2" opacity="0.55" transform="rotate(-18 205 205)"/>')
    s.add('<ellipse cx="205" cy="205" rx="46" ry="7" fill="none" stroke="#a24dff" stroke-width="1.2" opacity="0.6" transform="rotate(-18 205 205)"/>')
    return s


def dracula():
    s = Svg(4)
    s.rect(s.lin([(0, "#0e0a16"), (0.6, "#2a1a40"), (1, "#3a2456")]))
    s.stars(110, 0, 200, ("#f8f8f2", "#bd93f9"))
    s.glow(205, 68, 75, "#bd93f9", 0.35)
    s.circle(205, 68, 30, s.rad([(0, "#fffaf0"), (0.8, "#f2e6d8"), (1, "#d8c6e8")]))
    s.circle(196, 60, 5, "#e2d4c6", 'opacity="0.6"')
    s.circle(214, 76, 3.5, "#e2d4c6", 'opacity="0.5"')
    for cx, cy in [(60, 95), (150, 120), (250, 130)]:
        s.cloud(cx, cy, 10, "#3a2a58", 3, 0.6)
    for _ in range(9):  # bats
        x, y, k = s.r.uniform(120, 270), s.r.uniform(30, 120), s.r.uniform(0.7, 1.6)
        s.path(f"M{x} {y} q{2*k} {-2*k} {4*k} {-0.5*k} q{-1*k} {1.5*k} {0.5*k} {2*k} q{1*k} {-1*k} {2.5*k} {-0.4*k} "
               f"q{-1.6*k} {2.4*k} {-3.5*k} {1.4*k} q{-1.9*k} {1*k} {-3.5*k} {-1.4*k} q{1.5*k} {-0.6*k} {2.5*k} {0.4*k} q{0.5*k} {-1*k} {0.5*k} {-2*k} z",
               "#0a0610")
    c = "#08050d"
    s.ridge(262, 236, 7, "#140c20", sharp=False)
    for x, w, h in [(40, 18, 60), (62, 34, 38), (100, 14, 78), (118, 44, 46), (166, 16, 66), (186, 26, 40)]:
        s.rect(c, x, 262 - h, w, h + 30)
        s.path(f"M{x-2} {262-h} L{x+w/2} {262-h-w*0.9} L{x+w+2} {262-h} Z", c)
        if h > 50:
            s.rect("#ffc46a", x + w / 2 - 1, 262 - h + 10, 2, 3, 'opacity="0.8"')
    s.rect(c, 0, 258, W, 40)
    return s


def mocha():
    s = Svg(5)
    s.rect(s.lin([(0, "#1e1e2e"), (1, "#11111b")]))
    for _ in range(46):
        c = s.r.choice(["#cba6f7", "#f5c2e7", "#89b4fa", "#f9e2af", "#94e2d5"])
        r = s.r.uniform(4, 26)
        s.circle(s.r.uniform(0, W), s.r.uniform(0, H), r, c, f'opacity="{s.r.uniform(0.06, 0.22):.2f}" {s.blur(r * 0.25)}')
    for i, c in enumerate(["#cba6f7", "#f5c2e7", "#89b4fa"]):
        y = 220 + i * 18
        s.path(f"M0 {y} C70 {y-30} 140 {y+30} {W} {y-12} L{W} {H} L0 {H} Z", c, f'opacity="{0.12 + i * 0.05:.2f}"')
    s.stars(50, 0, H, ("#f5e0dc",), amin=0.2)
    return s


def rosepine():
    s = Svg(6)
    s.rect(s.lin([(0, "#191724"), (0.4, "#2a2238"), (0.68, "#7a4a6a"), (0.82, "#ebbcba")]))
    s.stars(70, 0, 110, ("#e0def4", "#ebbcba"))
    s.circle(70, 55, 11, "#f6e0e0")
    s.circle(75, 51, 10, "#262034")
    s.add(f'<rect x="0" y="200" width="{W}" height="20" fill="#f6c6c0" opacity="0.25" {s.blur(4)}/>')
    s.forest(232, 30, 62, 9, "#2e2538")
    s.add(f'<rect x="0" y="236" width="{W}" height="14" fill="#c4a7e7" opacity="0.18" {s.blur(4)}/>')
    s.forest(256, 26, 52, 8, "#1f1a2c")
    s.forest(280, 30, 64, 11, "#12101a")
    return s


def everforest():
    s = Svg(7)
    s.rect(s.lin([(0, "#22292d"), (0.5, "#3b4a40"), (1, "#7d9a6a")]))
    for i in range(6):  # sun rays
        a = -0.95 + i * 0.16
        x2, y2 = 240 + math.cos(a + 2.3) * 400, -20 + math.sin(a + 2.3) * 400
        s.path(f"M240 -20 L{x2:.0f} {y2:.0f} L{x2 + 30:.0f} {y2 + 20:.0f} Z", "#e6e2b0", f'opacity="0.06" {s.blur(4)}')
    s.glow(240, -10, 80, "#f2eebe", 0.35)
    layers = [("#4a5d4c", 150), ("#3b4b3f", 185), ("#2c3a31", 220), ("#1e2823", 256), ("#141c17", 288)]
    for i, (c, b) in enumerate(layers):
        s.forest(b, 22 + i * 6, 46 + i * 9, 8 + i, c)
        s.add(f'<rect x="0" y="{b - 8}" width="{W}" height="16" fill="#d3c6aa" opacity="0.12" {s.blur(5)}/>')
    return s


def cabin():
    s = Svg(8)
    s.rect(s.lin([(0, "#050b08"), (1, "#14241a")]))
    s.stars(200, 0, 170, ("#ffffff", "#eaf6d8"))
    s.glow(60, 40, 40, "#d9e8c8", 0.25)
    s.circle(60, 40, 9, "#eef4dc")
    s.forest(232, 40, 80, 10, "#0e1a12")
    s.rect("#0a130d", 0, 250, W, 40)
    x, y = 120, 236
    s.glow(x + 22, y + 6, 46, "#ffb04a", 0.35)
    s.rect("#20140c", x, y - 14, 44, 30)
    s.path(f"M{x-5} {y-14} L{x+22} {y-34} L{x+49} {y-14} Z", "#140c08")
    s.rect("#140c08", x + 32, y - 34, 5, 12)
    for wx in (x + 6, x + 28):
        s.rect("#ffc46a", wx, y - 7, 9, 8)
        s.rect("#20140c", wx + 4.2, y - 7, 0.6, 8)
    for i in range(7):  # smoke
        s.circle(x + 35 + i * 3 + s.r.uniform(-2, 2), y - 40 - i * 9, 3 + i * 1.2, "#9aa89a", f'opacity="{0.18 - i * 0.02:.2f}" {s.blur(2)}')
    s.forest(288, 34, 70, 14, "#060d08")
    for _ in range(26):
        s.circle(s.r.uniform(0, W), s.r.uniform(150, 280), 0.7, "#e6ff7a", f'{s.blur(0.6)} opacity="{s.r.uniform(0.5, 1):.2f}"')
    return s


def nord():
    s = Svg(9)
    s.rect(s.lin([(0, "#242933"), (0.5, "#3b4252"), (0.85, "#5e81ac"), (1, "#88c0d0")]))
    s.stars(80, 0, 100, ("#eceff4",))
    for i, (c, b, t) in enumerate([("#4c566a", 200, 120), ("#3b4252", 230, 160), ("#2e3440", 262, 196)]):
        pts = s.ridge(b, t, 6 + i * 2, c)
        for x, y in pts:
            if y < b - 20:
                s.path(f"M{x-9} {y+11} L{x} {y} L{x+9} {y+11} L{x+4} {y+8} L{x} {y+12} L{x-4} {y+8} Z", "#eceff4", 'opacity="0.75"')
    s.rect(s.lin([(0, "#88c0d0", 0.45), (1, "#2e3440", 0.9)]), 0, 262, W, 30)
    for _ in range(140):
        s.circle(s.r.uniform(0, W), s.r.uniform(0, H), s.r.uniform(0.3, 1.0), "#eceff4", f'opacity="{s.r.uniform(0.3, 0.9):.2f}"')
    return s


def oceandeep():
    s = Svg(10)
    s.rect(s.lin([(0, "#1a6a8a"), (0.35, "#0c3a5a"), (1, "#020a12")]))
    for _ in range(9):
        x = s.r.uniform(-20, W)
        s.path(f"M{x:.0f} -5 L{x + 14:.0f} -5 L{x + 70:.0f} {H} L{x + 40:.0f} {H} Z", "#bff0ff", f'opacity="{s.r.uniform(0.04, 0.09):.2f}" {s.blur(3)}')
    for _ in range(60):
        r = s.r.uniform(0.4, 2.2)
        s.circle(s.r.uniform(0, W), s.r.uniform(0, H), r, "none", f'stroke="#cdeefa" stroke-width="0.35" opacity="{s.r.uniform(0.25, 0.7):.2f}"')
    s.ridge(288, 250, 8, "#04121c", sharp=False)
    for _ in range(14):
        x, h = s.r.uniform(0, W), s.r.uniform(40, 110)
        d = f"M{x:.1f} {H} " + " ".join(f"Q{x + (6 if k % 2 else -6):.1f} {H - h * (k + 0.5) / 6:.1f} {x:.1f} {H - h * (k + 1) / 6:.1f}" for k in range(6))
        s.path(d, extra=f'stroke="#1f6a5a" stroke-width="{s.r.uniform(1.2, 2.4):.1f}" opacity="0.7" stroke-linecap="round"')
    for _ in range(8):  # fish
        x, y = s.r.uniform(20, 260), s.r.uniform(40, 200)
        s.path(f"M{x} {y} q4 -2.5 8 0 q-4 2.5 -8 0 z M{x+8} {y} l2.5 -1.8 l0 3.6 z", "#59d8c4", 'opacity="0.35"')
    return s


def abyss():
    s = Svg(11)
    s.rect(s.lin([(0, "#021014"), (1, "#000304")]))
    for _ in range(200):
        s.circle(s.r.uniform(0, W), s.r.uniform(0, H), s.r.uniform(0.2, 0.6), "#7ff5ea", f'opacity="{s.r.uniform(0.1, 0.6):.2f}"')
    for _ in range(7):  # jellyfish
        x, y, k = s.r.uniform(20, 255), s.r.uniform(20, 240), s.r.uniform(0.7, 1.5)
        c = s.r.choice(["#17d4c4", "#7ff5ea", "#5ab4ff", "#b07aff"])
        s.glow(x, y, 22 * k, c, 0.3)
        s.path(f"M{x-9*k} {y} Q{x-9*k} {y-10*k} {x} {y-10*k} Q{x+9*k} {y-10*k} {x+9*k} {y} Q{x} {y-2*k} {x-9*k} {y} Z", c, 'opacity="0.55"')
        for t in range(5):
            tx = x - 6 * k + t * 3 * k
            s.path(f"M{tx:.1f} {y:.1f} q2 6 0 12 q-2 6 0 12 q2 6 0 10", extra=f'stroke="{c}" stroke-width="0.5" opacity="0.5" transform="scale(1)"')
    return s


def blackice():
    s = Svg(12)
    s.rect(s.lin([(0, "#02070e"), (1, "#06182a")]))
    for _ in range(40):
        cx, cy, r = s.r.uniform(0, W), s.r.uniform(0, H), s.r.uniform(6, 30)
        pts = [(cx + math.cos(a) * r * s.r.uniform(0.5, 1), cy + math.sin(a) * r * s.r.uniform(0.5, 1))
               for a in sorted(s.r.uniform(0, 6.28) for _ in range(5))]
        d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"
        s.path(d, s.lin([(0, "#c8ecff", 0.14), (1, "#5ab4ff", 0.02)], 0, 0, 1, 1), 'stroke="#9ad4ff" stroke-width="0.35" stroke-opacity="0.35"')
    for _ in range(8):  # snow crystals
        x, y, r = s.r.uniform(10, 265), s.r.uniform(10, 280), s.r.uniform(4, 10)
        arms = ""
        for k in range(6):
            a = k * math.pi / 3
            ex, ey = x + math.cos(a) * r, y + math.sin(a) * r
            arms += f"M{x:.1f} {y:.1f} L{ex:.1f} {ey:.1f} "
            mx, my = x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.6
            for b in (a + 0.6, a - 0.6):
                arms += f"M{mx:.1f} {my:.1f} l{math.cos(b) * r * 0.3:.1f} {math.sin(b) * r * 0.3:.1f} "
        s.glow(x, y, r * 1.8, "#5ab4ff", 0.25)
        s.path(arms, extra='stroke="#e6f6ff" stroke-width="0.6" opacity="0.8" stroke-linecap="round"')
    return s


def ember():
    s = Svg(13)
    s.rect(s.lin([(0, "#050201"), (0.6, "#1a0703"), (1, "#3a1004")]))
    s.circle(137, 330, 190, s.rad([(0, "#ff7a1a", 0.6), (0.5, "#c0300a", 0.25), (1, "#c0300a", 0)]))
    for _ in range(12):
        x = s.r.uniform(0, W)
        s.path(f"M{x:.0f} {H} C{x - 20:.0f} 220 {x + 30:.0f} 160 {x + s.r.uniform(-20, 20):.0f} 90", extra=f'stroke="#2a1410" stroke-width="{s.r.uniform(4, 10):.0f}" opacity="0.35" {s.blur(4)}')
    for _ in range(150):
        y = s.r.uniform(0, H)
        r = s.r.uniform(0.3, 1.3) * (0.4 + y / H)
        c = s.r.choice(["#ffb04a", "#ff6a1a", "#ffd27a", "#ff3a0a"])
        s.circle(s.r.uniform(0, W), y, r, c, f'opacity="{s.r.uniform(0.4, 1):.2f}" {s.blur(r * 0.5)}')
        if s.r.random() < 0.2:
            x0 = s.r.uniform(0, W)
            s.path(f"M{x0:.1f} {y:.1f} l{s.r.uniform(-3, 3):.1f} -6", extra=f'stroke="{c}" stroke-width="0.4" opacity="0.6"')
    return s


def bloodmoon():
    s = Svg(14)
    s.rect(s.lin([(0, "#000000"), (0.6, "#16000a"), (1, "#2a0208")]))
    s.stars(90, 0, 200, ("#ffd6d6",), amin=0.2)
    s.glow(185, 92, 95, "#d0142a", 0.45)
    s.circle(185, 92, 42, s.rad([(0, "#ff5a3a"), (0.7, "#b0101c"), (1, "#6a0010")], 0.42, 0.4, 0.6))
    for _ in range(8):
        s.circle(185 + s.r.uniform(-28, 28), 92 + s.r.uniform(-28, 28), s.r.uniform(2, 7), "#7a0810", 'opacity="0.35"')

    def branch(x, y, a, l, w, depth):
        if depth == 0 or l < 3:
            return
        x2, y2 = x + math.cos(a) * l, y + math.sin(a) * l
        s.path(f"M{x:.1f} {y:.1f} L{x2:.1f} {y2:.1f}", extra=f'stroke="#050002" stroke-width="{w:.2f}" stroke-linecap="round"')
        for da in (-0.45, 0.4):
            branch(x2, y2, a + da + s.r.uniform(-0.2, 0.2), l * s.r.uniform(0.62, 0.78), w * 0.68, depth - 1)
    branch(60, 290, -1.5, 70, 7, 8)
    s.ridge(288, 262, 6, "#050002", sharp=False)
    s.add(f'<rect x="0" y="240" width="{W}" height="30" fill="#6a0010" opacity="0.25" {s.blur(6)}/>')
    return s


def tokyo():
    s = Svg(15)
    s.rect(s.lin([(0, "#13141f"), (0.6, "#1f2235"), (1, "#2a2e48")]))
    s.stars(50, 0, 80, ("#c0caf5",))
    s.glow(137, 300, 160, "#bb9af7", 0.25)
    s.buildings(170, 40, 130, 12, 24, "#1c1e30", ["#7aa2f7", "#bb9af7"], 0.12)
    s.buildings(230, 30, 120, 14, 30, "#11121c", ["#7aa2f7", "#e0af68", "#bb9af7", "#7dcfff"], 0.25)
    for _ in range(8):
        x, y = s.r.uniform(10, 260), s.r.uniform(130, 260)
        c = s.r.choice(["#f7768e", "#7dcfff", "#bb9af7", "#e0af68"])
        w, h = (2, s.r.uniform(12, 24)) if s.r.random() < 0.6 else (s.r.uniform(10, 18), 3)
        s.rect(c, x, y, w, h, f'{s.blur(1.2)} opacity="0.9"')
        s.rect("#ffffff", x + w * 0.3, y + h * 0.2, max(0.5, w * 0.4), max(0.5, h * 0.6), 'opacity="0.5"')
    s.rain(200, "#a9b1d6", 0.2)
    return s


def kanagawa():
    s = Svg(16)
    s.rect(s.lin([(0, "#16161d"), (0.5, "#223249"), (1, "#1f1f28")]))
    s.circle(205, 70, 26, "#ffa066", 'opacity="0.85"')
    s.glow(205, 70, 60, "#ffa066", 0.25)
    s.add('<path d="M175 80 L235 80" stroke="#16161d" stroke-width="2" opacity="0.5"/>')
    for row in range(9):
        y = 110 + row * 22
        c = ["#7e9cd8", "#6a8ac0", "#4a6a9a", "#2d4f67"][row % 4]
        d = f"M-10 {y}"
        for i in range(10):
            x = -10 + i * 32
            d += f" q8 -14 20 -8 q6 3 2 8 q-4 3 -1 6 q4 4 11 -2"
        d += f" L{W + 10} {H} L-10 {H} Z"
        s.path(d, c, f'opacity="{0.35 + row * 0.06:.2f}"')
        for i in range(10):
            s.circle(-10 + i * 32 + 20, y - 8, 1.2, "#dcd7ba", 'opacity="0.7"')
    return s


def operator():
    s = Svg(17)
    s.rect(s.lin([(0, "#010703"), (1, "#031408")]))
    grid = 7
    for _ in range(70):
        x, y = s.r.randrange(0, W // grid) * grid, s.r.randrange(0, H // grid) * grid
        d = f"M{x} {y}"
        for _ in range(s.r.randint(2, 6)):
            if s.r.random() < 0.5:
                x += s.r.choice([-1, 1]) * s.r.randint(1, 5) * grid
            else:
                y += s.r.choice([-1, 1]) * s.r.randint(1, 5) * grid
            d += f" L{x} {y}"
        c = s.r.choice(["#39ff7a", "#1f9c4a", "#7affb0"])
        s.path(d, extra=f'stroke="{c}" stroke-width="0.6" opacity="{s.r.uniform(0.2, 0.55):.2f}"')
        s.circle(x, y, 1.4, "none", f'stroke="{c}" stroke-width="0.5" opacity="0.7"')
    for _ in range(10):
        x, y = s.r.uniform(0, W), s.r.uniform(0, H)
        s.glow(x, y, 8, "#39ff7a", 0.4)
        s.rect("#0a2a14", x - 6, y - 4, 12, 8, 'stroke="#39ff7a" stroke-width="0.4" opacity="0.8"')
    return s


def oilslick():
    s = Svg(18)
    s.rect("#030407")
    for _ in range(16):
        c = s.r.choice(["#3ae0c8", "#c05aff", "#3a7aff", "#5aff9a", "#ff5ad0"])
        s.add(f'<ellipse cx="{s.r.uniform(0, W):.0f}" cy="{s.r.uniform(0, H):.0f}" rx="{s.r.uniform(20, 70):.0f}" ry="{s.r.uniform(10, 35):.0f}" '
              f'fill="{c}" opacity="{s.r.uniform(0.12, 0.3):.2f}" {s.blur(12)} transform="rotate({s.r.uniform(0, 180):.0f} {W/2} {H/2})"/>')
    for i in range(18):
        y = s.r.uniform(0, H)
        c = s.r.choice(["#3ae0c8", "#c05aff", "#7affea"])
        s.path(f"M-10 {y:.0f} C70 {y - 40:.0f} 160 {y + 40:.0f} {W + 10} {y - 10:.0f}", extra=f'stroke="{c}" stroke-width="0.5" opacity="0.3"')
    return s


def sakura():
    s = Svg(19)
    s.rect(s.lin([(0, "#fff7f9"), (1, "#f8dfe6")]))
    s.glow(220, 60, 90, "#ffffff", 0.7)

    def branch(x, y, a, l, w, depth):
        if depth == 0:
            for _ in range(3):
                bx, by = x + s.r.uniform(-4, 4), y + s.r.uniform(-4, 4)
                for p in range(5):
                    pa = p * 1.2566 + s.r.uniform(0, 0.3)
                    s.circle(bx + math.cos(pa) * 1.8, by + math.sin(pa) * 1.8, 1.6, s.r.choice(["#f7a8c0", "#fbc4d4", "#f48fb1"]), 'opacity="0.85"')
                s.circle(bx, by, 0.7, "#d6577f")
            return
        x2, y2 = x + math.cos(a) * l, y + math.sin(a) * l
        s.path(f"M{x:.1f} {y:.1f} Q{(x + x2) / 2 + s.r.uniform(-4, 4):.1f} {(y + y2) / 2 + s.r.uniform(-4, 4):.1f} {x2:.1f} {y2:.1f}",
               extra=f'stroke="#5a3440" stroke-width="{w:.2f}" stroke-linecap="round" opacity="0.8"')
        for da in (-0.5, 0.45):
            branch(x2, y2, a + da + s.r.uniform(-0.25, 0.25), l * 0.72, w * 0.65, depth - 1)
    branch(-5, 30, 0.35, 55, 4.5, 6)
    branch(W + 5, 250, 3.6, 50, 4, 5)
    for _ in range(50):
        x, y = s.r.uniform(0, W), s.r.uniform(0, H)
        s.add(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="1.6" ry="0.9" fill="#f7a8c0" opacity="{s.r.uniform(0.4, 0.9):.2f}" transform="rotate({s.r.uniform(0, 180):.0f} {x:.1f} {y:.1f})"/>')
    return s


def sky():
    s = Svg(20)
    s.rect(s.lin([(0, "#5a9ee0"), (0.6, "#a8d0f2"), (1, "#e6f2fb")]))
    s.glow(225, 45, 70, "#fff6c8", 0.8)
    s.circle(225, 45, 13, "#fff9e0")
    for _ in range(14):
        s.cloud(s.r.uniform(-10, W + 10), s.r.uniform(60, 280), s.r.uniform(6, 14), "#ffffff", s.r.uniform(1, 2.5), s.r.uniform(0.6, 0.95))
    return s


def sandstone():
    s = Svg(21)
    s.rect(s.lin([(0, "#f4e6cc"), (0.5, "#f0cf9a"), (1, "#e6b070")]))
    s.glow(80, 80, 70, "#fff2c8", 0.7)
    s.circle(80, 80, 18, "#fff4d6")
    for i, c in enumerate(["#e2b47a", "#d49a5c", "#bf7d42", "#a0602c"]):
        b = 150 + i * 36
        s.ridge(b + 20, b - 10, 3 + i, c, sharp=False)
    for _ in range(3):
        x = s.r.uniform(30, 250)
        y = 170 + s.r.uniform(0, 80)
        s.path(f"M{x} {y} l0 -14 M{x} {y-8} l-4 0 l0 -5 M{x} {y-6} l4 0 l0 -6", extra='stroke="#5a7d4a" stroke-width="2" stroke-linecap="round" opacity="0.85"')
    return s


def gruvbox():
    s = Svg(22)
    s.rect(s.lin([(0, "#1d2021"), (0.6, "#3c3836"), (1, "#504945")]))
    cols = ["#fb4934", "#fe8019", "#fabd2f", "#b8bb26", "#83a598"]
    for i, c in enumerate(cols):  # 70s stripes
        s.path(f"M-10 {130 + i * 9} C80 {90 + i * 9} 180 {170 + i * 9} {W + 10} {120 + i * 9} L{W + 10} {128 + i * 9} C180 {178 + i * 9} 80 {98 + i * 9} -10 {138 + i * 9} Z", c, 'opacity="0.85"')
    s.circle(200, 70, 28, s.lin([(0, "#fabd2f"), (1, "#fe8019")]))
    for i in range(5):  # sun stripes, cut to the sun's width
        y, hh = 72 + i * 5, 1 + i * 0.6
        dy = min(28, max(abs(y - 70), abs(y + hh - 70)))
        half = math.sqrt(max(0, 28 * 28 - dy * dy))
        s.rect("#3c3836", 200 - half, y, 2 * half, hh)
    s.ridge(250, 205, 5, "#32302f", sharp=False)
    s.ridge(288, 240, 4, "#282828", sharp=False)
    return s


def copper():
    s = Svg(23)
    s.rect(s.lin([(0, "#1c1512"), (1, "#0e0a08")]))
    def gear(cx, cy, r, teeth, fill, a):
        d = ""
        for t in range(teeth * 2):
            ang = t * math.pi / teeth
            rr = r if t % 2 == 0 else r * 0.82
            for k in (-0.5, 0.5):
                aa = ang + k * math.pi / teeth
                d += ("M" if not d else "L") + f"{cx + math.cos(aa) * rr:.1f} {cy + math.sin(aa) * rr:.1f} "
        d += "Z"
        s.path(d + f" M{cx + r*0.3:.1f} {cy:.1f} A{r*0.3:.1f} {r*0.3:.1f} 0 1 0 {cx - r*0.3:.1f} {cy:.1f} A{r*0.3:.1f} {r*0.3:.1f} 0 1 0 {cx + r*0.3:.1f} {cy:.1f} Z",
               fill, f'fill-rule="evenodd" opacity="{a}"')
    g = s.lin([(0, "#f0b67f"), (0.5, "#d9824a"), (1, "#7a3a18")], 0, 0, 1, 1)
    for cx, cy, r, t, a in [(220, 60, 46, 14, 0.35), (150, 120, 26, 10, 0.3), (40, 200, 52, 16, 0.25), (240, 240, 34, 12, 0.3), (110, 268, 22, 9, 0.25)]:
        gear(cx, cy, r, t, g, a)
    for y in (100, 180):
        s.rect(s.lin([(0, "#7a3a18"), (0.5, "#f0b67f"), (1, "#7a3a18")]), 0, y, W, 5, 'opacity="0.25"')
    return s


SCENES = {f.__name__: f for f in [synthwave, neonrose, nightshade, dracula, mocha, rosepine, everforest, cabin,
                                   nord, oceandeep, abyss, blackice, ember, bloodmoon, tokyo, kanagawa, operator,
                                   oilslick, sakura, sky, sandstone, gruvbox, copper]}


# ---- 70s retro family (Gruvbox style: rainbow stripes, striped suns) ------

def band(s, colors, y0, amp, ph, thick, freq=0.018, slope=0.0, op=0.92):
    """Stacked wavy stripes, one per colour."""
    for i, c in enumerate(colors):
        top = [(x, y0 + i * thick + slope * x + amp * math.sin(x * freq + ph)) for x in range(-10, W + 15, 5)]
        d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in top)
        d += " L" + " L".join(f"{x:.1f} {y + thick + 0.4:.1f}" for x, y in reversed(top)) + " Z"
        s.path(d, c, f'opacity="{op}"')


def striped_sun(s, cx, cy, r, grad, gap_color, n=6, start=0.05):
    s.circle(cx, cy, r, grad)
    for i in range(n):
        y = cy + r * start + i * r * 0.16
        hh = 0.6 + i * r * 0.025
        dy = min(r, max(abs(y - cy), abs(y + hh - cy)))
        half = math.sqrt(max(0, r * r - dy * dy))
        s.rect(gap_color, cx - half, y, 2 * half, hh)


def disco():
    s = Svg(31)
    s.rect(s.lin([(0, "#1a0f0a"), (0.6, "#2e1a10"), (1, "#3a2214")]))
    s.stars(40, 0, 110, ("#f7d26a", "#ffffff"), amin=0.3)
    s.glow(205, 62, 60, "#f4a62a", 0.3)
    striped_sun(s, 205, 62, 30, s.lin([(0, "#f7d26a"), (0.6, "#f4a62a"), (1, "#e0531f")]), "#1f120b")
    band(s, ["#c2410c", "#e0531f", "#f4a62a", "#f7d26a", "#8a5a2b"], 118, 18, 0.4, 7.5, 0.02, -0.08)
    s.ridge(262, 222, 4, "#2a1810", sharp=False)
    s.ridge(288, 252, 3, "#1a0f0a", sharp=False)
    return s


def route66():
    s = Svg(32)
    s.rect(s.lin([(0, "#15111a"), (0.4, "#3a1f3a"), (0.62, "#c2453a"), (0.7, "#ff8a3d")]), 0, 0, W, 175)
    band(s, ["#ff4d3d", "#ff8a3d", "#ffc94d", "#2ec4b6", "#1b7f8a"], 30, 7, 1.2, 5, 0.022, 0, 0.75)
    striped_sun(s, 137, 175, 46, s.lin([(0, "#ffe08a"), (0.5, "#ff8a3d"), (1, "#ff4d3d")]), "#5a1f30", 7, -0.9)
    for x, w, h in [(0, 60, 26), (40, 30, 40), (190, 50, 34), (228, 50, 22)]:  # mesas
        s.path(f"M{x} 175 L{x + 6} {175 - h} L{x + w - 6} {175 - h} L{x + w} 175 Z", "#2a1420")
    s.rect(s.lin([(0, "#3a1f26"), (1, "#120a10")]), 0, 175, W, H - 175)
    s.path(f"M131 175 L143 175 L230 {H} L44 {H} Z", "#1a1216")
    for i in range(9):
        y0 = 175 + (i / 9) ** 1.6 * (H - 175)
        y1 = 175 + ((i + 0.5) / 9) ** 1.6 * (H - 175)
        w0, w1 = 0.4 + (y0 - 175) * 0.025, 0.4 + (y1 - 175) * 0.025
        s.path(f"M{137 - w0} {y0:.1f} L{137 + w0} {y0:.1f} L{137 + w1} {y1:.1f} L{137 - w1} {y1:.1f} Z", "#ffc94d", 'opacity="0.85"')
    return s


def surfshack():
    s = Svg(33)
    s.rect(s.lin([(0, "#0b1a1d"), (0.5, "#264653"), (1, "#e76f51")]), 0, 0, W, 150)
    striped_sun(s, 160, 118, 40, s.lin([(0, "#e9c46a"), (0.6, "#f4a261"), (1, "#e76f51")]), "#7a3a3a", 6, 0.0)
    s.rect("#12303a", 0, 150, W, H - 150)
    for k in range(7):  # wave stripes
        band(s, ["#264653", "#2a9d8f", "#8ab17d", "#e9c46a"][k % 4:k % 4 + 1], 150 + k * 20, 5, k * 1.3, 11, 0.05, 0, 0.9)
    # palm tree
    s.path("M40 290 C46 240 52 190 70 150", extra='stroke="#0b1a1d" stroke-width="5" stroke-linecap="round"')
    for a in (-2.6, -2.0, -1.2, -0.5, 0.2, 0.8):
        x2, y2 = 70 + math.cos(a) * 40, 150 + math.sin(a) * 26 + 10
        s.path(f"M70 150 Q{70 + math.cos(a) * 22:.1f} {150 + math.sin(a) * 22 - 8:.1f} {x2:.1f} {y2:.1f} Q{70 + math.cos(a) * 18:.1f} {150 + math.sin(a) * 14:.1f} 70 152 Z", "#0b1a1d")
    return s


def velvet():
    s = Svg(34)
    s.rect(s.lin([(0, "#14060e"), (1, "#2a0f1e")]))
    s.stars(70, 0, 160, ("#f6d9e4", "#e8a33d"), amin=0.3)
    cols = ["#e8a33d", "#f06b8a", "#d6336c", "#a3165a", "#6a0f3a"]
    for i, c in enumerate(cols):  # rainbow arches
        r = 150 - i * 16
        s.path(f"M{137 - r} 300 A{r} {r} 0 0 1 {137 + r} 300 L{137 + r - 16} 300 A{r - 16} {r - 16} 0 0 0 {137 - r + 16} 300 Z", c, 'opacity="0.9"')
    s.glow(137, 300, 70, "#e8a33d", 0.25)
    for _ in range(8):  # sparkles
        x, y = s.r.uniform(10, 265), s.r.uniform(10, 140)
        k = s.r.uniform(2, 4)
        s.path(f"M{x} {y - k} L{x + k * 0.25} {y} L{x} {y + k} L{x - k * 0.25} {y} Z M{x - k} {y} L{x} {y + k * 0.25} L{x + k} {y} L{x} {y - k * 0.25} Z", "#f6d9e4", 'opacity="0.8"')
    return s


def hemp_leaf(s, x, y, size, angle, fill, op=0.9):
    """Palmate leaf: 7 pointed leaflets fanned around the stalk direction."""
    g = f'<g transform="translate({x:.1f} {y:.1f}) rotate({angle:.0f})" opacity="{op}">'
    for frac, ang in zip([0.42, 0.66, 0.86, 1.0, 0.86, 0.66, 0.42], [-78, -52, -26, 0, 26, 52, 78]):
        l, w = size * frac, size * frac * 0.17
        g += (f'<path d="M0 0 Q{w:.1f} {-l * 0.45:.1f} 0 {-l:.1f} Q{-w:.1f} {-l * 0.45:.1f} 0 0 Z" fill="{fill}" '
              f'transform="rotate({ang})"/>')
    return g + '</g>'


def hemp_plant(s, x, base, h, greens):
    sway = s.r.uniform(-10, 10)
    s.path(f"M{x:.1f} {base:.1f} Q{x + sway:.1f} {base - h * 0.5:.1f} {x + sway * 0.6:.1f} {base - h:.1f}",
           extra='stroke="#3a4a14" stroke-width="1.6" stroke-linecap="round"')
    nodes = 5
    for k in range(1, nodes + 1):
        t = k / (nodes + 1)
        nx = x + sway * (2 * t * (1 - t)) + sway * 0.6 * t * t
        ny = base - h * t
        size = h * (0.32 - t * 0.14)
        side = -1 if k % 2 else 1
        s.add(hemp_leaf(s, nx, ny, size, side * s.r.uniform(48, 70), s.r.choice(greens)))
        s.add(hemp_leaf(s, nx, ny, size * 0.8, -side * s.r.uniform(40, 62), s.r.choice(greens), 0.8))
    s.add(hemp_leaf(s, x + sway * 0.6, base - h, h * 0.2, s.r.uniform(-8, 8), greens[0]))


def avocado():
    s = Svg(35)
    s.rect(s.lin([(0, "#14170a"), (0.6, "#262a14"), (1, "#3a3a1a")]))
    s.glow(200, 60, 70, "#c9b037", 0.25)
    s.circle(200, 60, 18, s.lin([(0, "#f2d27a"), (1, "#d98e1f")]))
    greens = ["#9aa83a", "#7f8f2a", "#6b7f1f", "#b4bf4a"]
    for x, h in [(-4, 150), (26, 110), (250, 140), (280, 100)]:  # tall plants framing the sides
        hemp_plant(s, x, 290, h, greens)
    for i in range(7):  # low row along the bottom
        hemp_plant(s, 40 + i * 32 + s.r.uniform(-6, 6), 292, s.r.uniform(36, 56), greens)
    band(s, ["#b5491c", "#d98e1f", "#c9b037", "#9aa83a", "#6b7f1f"], 214, 6, 0.8, 4.5, 0.03, 0, 0.75)
    return s


def cosmicfunk():
    s = Svg(36)
    s.rect(s.lin([(0, "#0c0618"), (1, "#1c1030")]))
    s.stars(220, 0, H, ("#ffffff", "#ffd23f", "#f5e6ff"), big=0.05)
    band(s, ["#5e2bff", "#c04cfd", "#ff3864", "#ff9f1c", "#ffd23f"], 150, 30, 2.2, 7, 0.016, -0.18)
    s.glow(200, 95, 55, "#c04cfd", 0.35)
    s.circle(200, 95, 26, s.lin([(0, "#ffd23f"), (0.5, "#ff9f1c"), (1, "#ff3864")], 0, 0, 1, 1))
    for i, c in enumerate(["#ff3864", "#ff9f1c", "#ffd23f"]):
        s.add(f'<ellipse cx="200" cy="95" rx="{46 - i * 4}" ry="{9 - i}" fill="none" stroke="{c}" stroke-width="1.6" opacity="0.85" transform="rotate(-16 200 95)"/>')
    s.path("M174 95 A26 26 0 0 1 226 95", "none", 'stroke="#0c0618" stroke-width="0"')
    return s


SCENES.update({f.__name__: f for f in [disco, route66, surfshack, velvet, avocado, cosmicfunk]})


# ---- vintage set (2026-11-02) ---------------------------------------------

def rays(s, cx, cy, n, r, c1, c2, a=0.8, start=math.pi, end=2 * math.pi):
    for i in range(n):
        a0 = start + (end - start) * i / n
        a1 = start + (end - start) * (i + 1) / n
        c = c1 if i % 2 == 0 else c2
        s.path(f"M{cx} {cy} L{cx + math.cos(a0) * r:.1f} {cy + math.sin(a0) * r:.1f} L{cx + math.cos(a1) * r:.1f} {cy + math.sin(a1) * r:.1f} Z", c, f'opacity="{a}"')


def grain(s, n, color, amax=0.12):
    for _ in range(n):
        s.circle(s.r.uniform(0, W), s.r.uniform(0, H), s.r.uniform(0.2, 0.5), color, f'opacity="{s.r.uniform(0.03, amax):.2f}"')


def blackvinyl():
    s = Svg(41)
    s.rect("#050505")
    band(s, ["#8a3a1c", "#d9542b", "#e8b04a", "#f2e4c4"], 14, 3, 0.5, 3, 0.03, 0, 0.85)
    cx, cy = 175, 190
    s.circle(cx, cy, 98, "#0c0c0c")
    for i in range(30):
        s.circle(cx, cy, 96 - i * 2.2, "none", f'stroke="{"#1c1c1c" if i % 2 else "#141414"}" stroke-width="0.8"')
    s.path(f"M{cx - 70} {cy - 60} A92 92 0 0 1 {cx + 20} {cy - 92}", extra='stroke="#ffffff" stroke-width="3" opacity="0.06" stroke-linecap="round"')
    s.path(f"M{cx + 60} {cy + 66} A90 90 0 0 1 {cx - 10} {cy + 92}", extra='stroke="#ffffff" stroke-width="2" opacity="0.05" stroke-linecap="round"')
    s.circle(cx, cy, 30, s.lin([(0, "#f2c14e"), (1, "#d9542b")]))
    for i, c in enumerate(["#8a3a1c", "#f2e4c4"]):
        s.circle(cx, cy, 24 - i * 6, "none", f'stroke="{c}" stroke-width="1.2" opacity="0.7"')
    s.circle(cx, cy, 2.4, "#050505")
    s.path("M30 40 L52 150", extra='stroke="#b8b0a0" stroke-width="2.4" stroke-linecap="round"')
    s.circle(30, 40, 7, "#2a2620", 'stroke="#b8b0a0" stroke-width="1"')
    return s


def nightdrive():
    s = Svg(42)
    s.rect(s.lin([(0, "#000000"), (1, "#0d0d10")]))
    s.stars(150, 0, 170, ("#eef0f3", "#c9ced6"))
    striped_sun(s, 80, 72, 26, s.lin([(0, "#f3efe4"), (1, "#c9ced6")]), "#000000", 5, 0.1)
    band(s, ["#7a0f1a", "#e63946", "#c9ced6", "#eef0f3"], 128, 10, 2.0, 4, 0.02, 0.05, 0.9)
    s.ridge(232, 196, 7, "#121216")
    s.path(f"M0 232 L{W} 232", extra='stroke="#e63946" stroke-width="0.6" opacity="0.8"')
    s.rect("#070708", 0, 232, W, H - 232)
    for i in range(6):
        y = 238 + i * 9
        s.rect("#c9ced6", 130 - i * 3, y, 15 + i * 6, 1.2, 'opacity="0.35"')
    return s


def artdeco():
    s = Svg(43)
    s.rect(s.lin([(0, "#050403"), (1, "#0f0c07")]))
    rays(s, 137, 300, 36, 380, "#d4af37", "#050403", 0.16)
    for i in range(7):
        r = 40 + i * 22
        s.path(f"M{137 - r} 300 A{r} {r} 0 0 1 {137 + r} 300", extra=f'stroke="#d4af37" stroke-width="{0.8 if i % 2 else 1.6}" opacity="0.6"')
    for x in (30, 245):  # deco fans
        for k in range(9):
            a = math.pi + k * math.pi / 8
            s.path(f"M{x} 70 L{x + math.cos(a) * 26:.1f} {70 + math.sin(a) * 26:.1f}", extra='stroke="#f3e5ab" stroke-width="0.6" opacity="0.6"')
        s.path(f"M{x - 26} 70 A26 26 0 0 1 {x + 26} 70", extra='stroke="#d4af37" stroke-width="1.2" opacity="0.8"')
    for y in (8, 12):
        s.rect("#d4af37", 0, y, W, 0.6, 'opacity="0.7"')
    return s


def blackstripe():
    s = Svg(44)
    s.rect("#070707")
    band(s, ["#c2410c", "#ff7a1a", "#ffd23f", "#f5efe0"], 96, 0, 0, 3.2, 0.0, -0.32, 0.95)
    band(s, ["#c2410c", "#ff7a1a", "#ffd23f", "#f5efe0"], 250, 0, 0, 3.2, 0.0, -0.32, 0.35)
    s.circle(215, 210, 24, "none", 'stroke="#ffd23f" stroke-width="1.4" opacity="0.9"')
    for i in range(5):
        y = 212 + i * 3.6
        dy = abs(y - 210)
        half = math.sqrt(max(0, 22 * 22 - dy * dy))
        s.rect("#ff7a1a", 215 - half, y, 2 * half, 1.4, 'opacity="0.8"')
    grain(s, 300, "#ffffff", 0.06)
    return s


def aurora():
    s = Svg(45)
    s.rect(s.lin([(0, "#0a181d"), (0.6, "#14343a"), (1, "#1d4a4a")]))
    s.stars(120, 0, 150, ("#f1e7cf",))
    band(s, ["#e9c46a", "#f4a261", "#8ab17d", "#2a9d8f"], 40, 14, 0.6, 7, 0.022, 0.12, 0.85)
    for c, b, t, n in [("#264653", 210, 128, 6), ("#1b343d", 238, 170, 8), ("#10232a", 262, 214, 9)]:
        pts = s.ridge(b, t, n, c)
        for x, y in pts:
            if y < b - 26:
                s.path(f"M{x - 8} {y + 10} L{x} {y} L{x + 8} {y + 10} L{x + 4} {y + 7} L{x} {y + 11} L{x - 4} {y + 7} Z", "#f1e7cf", 'opacity="0.9"')
    s.rect("#0d2026", 0, 262, W, 30)
    for i, c in enumerate(["#e9c46a", "#f4a261", "#8ab17d", "#2a9d8f"]):
        s.rect(c, 30 + i * 8, 266 + i * 5, 215 - i * 16, 1.2, 'opacity="0.4"')
    return s


def sunburst():
    s = Svg(46)
    s.rect("#2b1a10")
    rays(s, 137, 288, 24, 420, "#e07b39", "#f2b134", 0.55)
    s.rect(s.lin([(0, "#2b1a10", 0.2), (1, "#2b1a10", 0.85)]), 0, 0, W, H)
    striped_sun(s, 137, 288, 70, s.lin([(0, "#ffd27a"), (1, "#e07b39")]), "#2b1a10", 7, -0.95)
    return s


def woodstock():
    s = Svg(47)
    s.rect(s.lin([(0, "#2a1a14"), (0.55, "#9a4a22"), (0.8, "#e9a13b")]), 0, 0, W, 170)
    striped_sun(s, 90, 120, 38, s.lin([(0, "#fff0b0"), (1, "#e9b949")]), "#b05a28", 6, 0.05)
    s.rect("#2a3a16", 0, 160, W, H - 160)
    band(s, ["#8fae4a", "#6d8a35", "#4e6a28", "#3a501e", "#2a3a16"], 150, 12, 0.3, 18, 0.025, 0, 1)
    for _ in range(40):
        x, y = s.r.uniform(0, W), s.r.uniform(175, 285)
        c = s.r.choice(["#f2e6c8", "#e9b949", "#e07a5f", "#c77dff"])
        for k in range(5):
            a = k * 1.2566
            s.circle(x + math.cos(a) * 1.4, y + math.sin(a) * 1.4, 1.1, c, 'opacity="0.9"')
        s.circle(x, y, 0.7, "#3a2a14")
    return s


def diner():
    s = Svg(48)
    s.rect(s.lin([(0, "#0f2e2e"), (1, "#1f6f6f")]), 0, 0, W, 150)
    for y, c, hh in [(110, "#f7f1e3", 3), (114, "#e63946", 2.5), (117.5, "#f7f1e3", 1)]:
        s.rect(c, 0, y, W, hh)
    for _ in range(9):  # atomic starbursts
        x, y, r = s.r.uniform(10, 265), s.r.uniform(15, 100), s.r.uniform(4, 9)
        for k in range(8):
            a = k * math.pi / 4
            rr = r if k % 2 == 0 else r * 0.5
            s.path(f"M{x} {y} L{x + math.cos(a) * rr:.1f} {y + math.sin(a) * rr:.1f}", extra='stroke="#f2c14e" stroke-width="0.7" opacity="0.8"')
    s.rect("#0b0b0b", 0, 150, W, H - 150)
    rows = 10
    for r_ in range(rows):  # perspective checkerboard
        y0 = 150 + (r_ / rows) ** 1.5 * (H - 150)
        y1 = 150 + ((r_ + 1) / rows) ** 1.5 * (H - 150)
        k0, k1 = 0.25 + 0.75 * (y0 - 150) / (H - 150), 0.25 + 0.75 * (y1 - 150) / (H - 150)
        for c_ in range(-12, 13):
            if (c_ + r_) % 2:
                continue
            xa0, xb0 = 137 + c_ * 22 * k0, 137 + (c_ + 1) * 22 * k0
            xa1, xb1 = 137 + c_ * 22 * k1, 137 + (c_ + 1) * 22 * k1
            s.path(f"M{xa0:.1f} {y0:.1f} L{xb0:.1f} {y0:.1f} L{xb1:.1f} {y1:.1f} L{xa1:.1f} {y1:.1f} Z", "#f7f1e3", 'opacity="0.85"')
    return s


def atomic():
    s = Svg(49)
    s.rect(s.lin([(0, "#102a2e"), (1, "#1c4448")]))
    for _ in range(14):  # boomerangs
        x, y, k, a = s.r.uniform(0, W), s.r.uniform(0, H), s.r.uniform(0.6, 1.4), s.r.uniform(0, 360)
        c = s.r.choice(["#f2b134", "#ef7a5a", "#f4ead2", "#7fc8b8"])
        s.path(f"M{x} {y} q{8*k} {-10*k} {18*k} {-4*k} q{-8*k} {1*k} {-12*k} {8*k} q{8*k} {2*k} {12*k} {12*k} q{-12*k} {-4*k} {-18*k} {-16*k} z", c,
               f'opacity="0.75" transform="rotate({a:.0f} {x:.1f} {y:.1f})"')
    for _ in range(10):
        x, y, r = s.r.uniform(0, W), s.r.uniform(0, H), s.r.uniform(3, 7)
        for k in range(4):
            a = k * math.pi / 4
            s.path(f"M{x - math.cos(a) * r:.1f} {y - math.sin(a) * r:.1f} L{x + math.cos(a) * r:.1f} {y + math.sin(a) * r:.1f}", extra='stroke="#f4ead2" stroke-width="0.6" opacity="0.8"')
    for ang in (0, 60, 120):
        s.add(f'<ellipse cx="205" cy="200" rx="34" ry="11" fill="none" stroke="#f2b134" stroke-width="1.2" opacity="0.7" transform="rotate({ang} 205 200)"/>')
    s.circle(205, 200, 5, "#ef7a5a")
    return s


def mod():
    s = Svg(50)
    s.rect("#1f1008")
    cols = ["#f08a24", "#f2d49b", "#8a3a14", "#c75a1a"]
    for gy in range(0, H + 40, 46):
        for gx in range(-10, W + 40, 46):
            ox = 23 if (gy // 46) % 2 else 0
            for i in range(6):
                s.circle(gx + ox, gy, 22 - i * 3.6, cols[i % 4], 'opacity="0.85"')
    s.rect("#1f1008", 0, 0, W, H, 'opacity="0.35"')
    return s


def cassette():
    s = Svg(51)
    s.rect(s.lin([(0, "#2a1d15"), (1, "#1a110b")]))
    x, y, w, h = 40, 22, 195, 120
    s.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="7" fill="#3a2a20" stroke="#5a4232" stroke-width="1.2"/>')
    s.add(f'<rect x="{x + 10}" y="{y + 8}" width="{w - 20}" height="70" rx="3" fill="#f2e6cf"/>')
    for i, c in enumerate(["#e05a3a", "#f29e4c", "#f2c14e", "#7fb069"]):
        s.rect(c, x + 10, y + 14 + i * 6, w - 20, 5)
    s.add(f'<rect x="{x + 52}" y="{y + 44}" width="{w - 104}" height="26" rx="12" fill="#1a110b"/>')
    for cx in (x + 66, x + w - 66):
        s.circle(cx, y + 57, 10, "#f2e6cf")
        for k in range(6):
            a = k * math.pi / 3
            s.rect("#3a2a20", cx + math.cos(a) * 6 - 1, y + 57 + math.sin(a) * 6 - 1, 2, 2)
        s.circle(cx, y + 57, 3.5, "#3a2a20")
    s.path(f"M{x + 30} {y + h} L{x + 40} {y + 92} L{x + w - 40} {y + 92} L{x + w - 30} {y + h} Z", "#2e2118")
    band(s, ["#e05a3a", "#f29e4c", "#f2c14e", "#7fb069"], 176, 16, 1.5, 6, 0.03, 0)
    s.path(f"M{x + 66} {y + 67} C 60 230 210 200 240 288", extra='stroke="#5a3a28" stroke-width="2.2" opacity="0.8"')
    return s


def sepia():
    s = Svg(52)
    s.rect(s.lin([(0, "#3b2a1a"), (0.5, "#8a6a48"), (1, "#c8ab80")]), 0, 0, W, 200)
    s.glow(190, 90, 60, "#f0dcb0", 0.5)
    s.circle(190, 90, 16, "#efdfc0", 'opacity="0.9"')
    s.ridge(200, 130, 6, "#6a5038")
    s.ridge(210, 160, 8, "#4e3a28")
    s.rect(s.lin([(0, "#9a7c58"), (1, "#3b2a1a")]), 0, 205, W, H - 205)
    for i in range(10):
        s.rect("#efdfc0", s.r.uniform(0, 200), 212 + i * 7, s.r.uniform(30, 80), 0.6, 'opacity="0.25"')
    s.forest(214, 18, 34, 12, "#2e2216")
    grain(s, 900, "#1a120a", 0.18)
    for _ in range(6):
        x = s.r.uniform(0, W)
        s.path(f"M{x:.1f} 0 L{x + s.r.uniform(-4, 4):.1f} {H}", extra='stroke="#efdfc0" stroke-width="0.3" opacity="0.25"')
    s.rect(s.rad([(0.55, "#000000", 0), (1, "#140c06", 0.75)], 0.5, 0.5, 0.75))
    return s


def vhs():
    s = Svg(53)
    s.rect(s.lin([(0, "#0e0614"), (0.6, "#2a0e3a"), (1, "#4a1250")]), 0, 0, W, 160)
    s.stars(80, 0, 110, ("#f7e6ff", "#4fd8ff"))
    striped_sun(s, 137, 140, 44, s.lin([(0, "#ffe66b"), (0.5, "#ff4fa3"), (1, "#9b30ff")]), "#2a0e3a", 7, -0.2)
    s.ridge(160, 128, 10, "#1a0a24")
    s.rect("#0e0614", 0, 160, W, H - 160)
    for k in range(-12, 13):
        s.path(f"M137 160 L{137 + k * 40} {H}", extra='stroke="#4fd8ff" stroke-width="0.5" opacity="0.55"')
    for i in range(1, 12):
        y = 160 + (i / 11) ** 2 * (H - 160)
        s.path(f"M0 {y:.1f} L{W} {y:.1f}", extra='stroke="#4fd8ff" stroke-width="0.5" opacity="0.6"')
    for _ in range(5):  # tracking glitches
        y = s.r.uniform(0, H)
        s.rect(s.r.choice(["#ff4fa3", "#4fd8ff", "#ffffff"]), s.r.uniform(-40, 60), y, s.r.uniform(120, 260), s.r.uniform(0.6, 2), 'opacity="0.25"')
    for y in range(0, H, 2):
        s.rect("#000000", 0, y, W, 0.5, 'opacity="0.18"')
    return s


def bohemian():
    s = Svg(54)
    s.rect(s.lin([(0, "#2e160f"), (1, "#3a1d14")]))
    for _ in range(18):  # paisleys
        x, y, k, a = s.r.uniform(0, W), s.r.uniform(0, H), s.r.uniform(1.6, 3.2), s.r.uniform(0, 360)
        g = f'<g transform="translate({x:.1f} {y:.1f}) rotate({a:.0f}) scale({k:.2f})" opacity="0.8">'
        for i, c in enumerate(["#3f8f8a", "#e3a857", "#f5e2c8", "#c8553d"]):
            sc = 1 - i * 0.22
            g += f'<path d="M0 {-14*sc:.1f} C{12*sc:.1f} {-14*sc:.1f} {14*sc:.1f} {6*sc:.1f} 0 {12*sc:.1f} C{-10*sc:.1f} {6*sc:.1f} {-6*sc:.1f} {-4*sc:.1f} {-2*sc:.1f} {-6*sc:.1f} C{-8*sc:.1f} {-8*sc:.1f} {-6*sc:.1f} {-14*sc:.1f} 0 {-14*sc:.1f} Z" fill="{c}"/>'
        g += '<circle cx="1" cy="2" r="1.5" fill="#2e160f"/></g>'
        s.add(g)
    for _ in range(60):
        s.circle(s.r.uniform(0, W), s.r.uniform(0, H), 0.9, "#e3a857", 'opacity="0.5"')
    return s


def lavalamp():
    s = Svg(55)
    s.rect(s.lin([(0, "#120815"), (1, "#26102c")]))
    s.glow(137, 150, 140, "#ff3c7d", 0.25)
    for _ in range(14):
        x, y = s.r.uniform(0, W), s.r.uniform(0, H)
        rx, ry = s.r.uniform(14, 38), s.r.uniform(18, 46)
        c = s.r.choice(["#ff8c42", "#ff3c7d", "#ffd23f", "#c04cfd"])
        d = (f"M{x} {y - ry} C{x + rx * 1.1} {y - ry} {x + rx * 0.8} {y + ry * 0.2} {x + rx * 0.4} {y + ry * 0.6} "
             f"C{x + rx * 0.2} {y + ry} {x - rx * 0.5} {y + ry} {x - rx * 0.7} {y + ry * 0.4} C{x - rx * 1.2} {y - ry * 0.2} {x - rx * 0.9} {y - ry} {x} {y - ry} Z")
        s.path(d, c, 'opacity="0.75"')
    return s


def safari():
    s = Svg(56)
    s.rect(s.lin([(0, "#3a1a10"), (0.5, "#d9722b"), (0.75, "#f2c14e")]), 0, 0, W, 200)
    striped_sun(s, 160, 160, 58, s.lin([(0, "#fff0b0"), (1, "#f29e4c")]), "#d9722b", 7, -0.2)
    s.ridge(205, 186, 5, "#7a3a1a", sharp=False)
    s.rect(s.lin([(0, "#5a2e14"), (1, "#24120a")]), 0, 200, W, H - 200)
    # acacia
    s.path("M70 236 L74 160 M74 190 L54 168 M74 180 L96 160", extra='stroke="#1a0c06" stroke-width="3.2" stroke-linecap="round"')
    s.add('<ellipse cx="76" cy="156" rx="40" ry="8" fill="#1a0c06"/><ellipse cx="56" cy="166" rx="18" ry="5" fill="#1a0c06"/><ellipse cx="100" cy="160" rx="20" ry="5" fill="#1a0c06"/>')
    s.rect("#1a0c06", 0, 234, W, H - 234, 'opacity="0.55"')
    for _ in range(7):
        x, y = s.r.uniform(120, 260), s.r.uniform(40, 110)
        s.path(f"M{x} {y} q2 -2 4 0 q2 -2 4 0", extra='stroke="#2a1208" stroke-width="0.8"')
    return s


def harvest():
    s = Svg(57)
    s.rect(s.lin([(0, "#2a170e"), (0.6, "#6a3218"), (1, "#c0622a")]), 0, 0, W, 170)
    s.glow(210, 70, 50, "#f2c14e", 0.4)
    s.circle(210, 70, 18, "#f2c14e")
    for i, c in enumerate(["#c0392b", "#e8862e", "#d9a035", "#8a4a1c", "#5a2e14"]):
        s.ridge(150 + i * 30 + 30, 140 + i * 30, 3 + i, c, sharp=False)
    for _ in range(18):  # round trees
        x, y = s.r.uniform(0, W), s.r.uniform(150, 270)
        c = s.r.choice(["#c0392b", "#e8862e", "#d9a035", "#a0522d"])
        s.rect("#2a170e", x - 0.8, y, 1.6, 8)
        s.circle(x, y, s.r.uniform(4, 8), c)
    for _ in range(40):
        x, y = s.r.uniform(0, W), s.r.uniform(0, H)
        s.add(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="1.8" ry="0.9" fill="{s.r.choice(["#e8862e", "#c0392b", "#d9a035"])}" opacity="0.8" transform="rotate({s.r.uniform(0, 180):.0f} {x:.1f} {y:.1f})"/>')
    return s


SCENES.update({f.__name__: f for f in [blackvinyl, nightdrive, artdeco, blackstripe, aurora, sunburst, woodstock, diner,
                                       atomic, mod, cassette, sepia, vhs, bohemian, lavalamp, safari, harvest]})


def jukebox():
    s = Svg(58)
    s.rect(s.lin([(0, "#14060a"), (1, "#2a0e12")]))
    cx, base = 137, 300
    s.glow(cx, 150, 150, "#ff6a3d", 0.18)
    tubes = ["#3fa7d6", "#ffd23f", "#ff9f1c", "#e63946"]
    for i, c in enumerate(tubes):  # neon arch tubes
        r = 128 - i * 9
        d = f"M{cx - r} {base} L{cx - r} 150 A{r} {r} 0 0 1 {cx + r} 150 L{cx + r} {base}"
        s.path(d, extra=f'stroke="{c}" stroke-width="7" opacity="0.35" {s.blur(3)}')
        s.path(d, extra=f'stroke="{c}" stroke-width="2.6" opacity="0.9"')
    r = 92
    s.path(f"M{cx - r} {base} L{cx - r} 150 A{r} {r} 0 0 1 {cx + r} 150 L{cx + r} {base} Z", "#1a080c", 'opacity="0.9"')
    for i in range(9):  # chrome grille at the top of the arch
        y = 74 + i * 4
        half = math.sqrt(max(0, 80 * 80 - (y - 150) ** 2)) * 0.9
        s.rect("#d8d2c8", cx - half, y, 2 * half, 1, 'opacity="0.28"')
    for x in (cx - 112, cx + 112):  # bubble tubes
        for _ in range(10):
            s.circle(x + s.r.uniform(-1.5, 1.5), s.r.uniform(150, 286), s.r.uniform(0.8, 1.6), "none", 'stroke="#fbe8d0" stroke-width="0.4" opacity="0.7"')
    s.stars(60, 0, 70, ("#fbe8d0", "#ffd23f"), amin=0.2)
    return s


SCENES.update({"jukebox": jukebox})


def drivein():
    s = Svg(59)
    s.rect(s.lin([(0, "#0b1422"), (0.5, "#2e2a48"), (0.78, "#a8584a"), (0.8, "#c86a4a")]), 0, 0, W, 222)
    s.stars(110, 0, 120, ("#f6e7d0", "#ffffff"))
    x, y, w, h = 58, 52, 160, 92
    for px in (x + 18, x + w - 22):
        s.rect("#120c10", px, y + h, 4, 222 - y - h)
    s.glow(x + w / 2, y + h / 2, 110, "#f6e7d0", 0.12)
    s.rect("#2a2230", x - 3, y - 3, w + 6, h + 6)
    s.rect(s.lin([(0, "#3a3550"), (1, "#5a3e48")]), x, y, w, h)
    sx, sy, sr = x + w / 2, y + h * 0.62, 26
    s.add(f'<clipPath id="scr"><rect x="{x}" y="{y}" width="{w}" height="{h}"/></clipPath>')
    s.add('<g clip-path="url(#scr)">')
    striped_sun(s, sx, sy, sr, s.lin([(0, "#ffd27a"), (1, "#ff8c61")]), "#4a3a4c", 5, 0.05)
    s.ridge(y + h, y + h - 18, 6, "#2a2436")
    s.add('</g>')
    s.rect(s.lin([(0, "#1a1218"), (1, "#0b0709")]), 0, 222, W, H - 222)
    for row, yy in enumerate((246, 272)):  # parked cars
        for i in range(6):
            cx = 22 + i * 46 + (row * 20)
            s.path(f"M{cx - 18} {yy} L{cx - 16} {yy - 7} Q{cx - 8} {yy - 15} {cx + 6} {yy - 14} L{cx + 16} {yy - 7} L{cx + 19} {yy} Z", "#050304")
            s.circle(cx + 17, yy - 4, 0.9, "#ff8c61", 'opacity="0.7"')
    return s


def motel():
    s = Svg(60)
    s.rect(s.lin([(0, "#140a24"), (0.55, "#4a2250"), (1, "#c8606a")]))
    s.stars(90, 0, 130, ("#fde8f0", "#ffffff"))
    s.circle(60, 46, 12, "#fde8f0", 'opacity="0.9"')
    s.circle(65, 42, 11, "#1c0e2c")
    # neon sign on a pole
    px = 212
    s.rect("#0c0614", px - 2, 90, 4, 200)
    bx, by, bw, bh = px - 34, 42, 68, 40
    s.add(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" rx="6" fill="#1c0e2c"/>')
    for sw, op in ((5, 0.3), (1.6, 0.95)):
        s.add(f'<rect x="{bx + 3}" y="{by + 3}" width="{bw - 6}" height="{bh - 6}" rx="4" fill="none" stroke="#ff5fa2" stroke-width="{sw}" opacity="{op}"/>')
        s.path(f"M{bx - 16} {by + bh + 18} L{bx + 20} {by + bh + 18} L{bx + 20} {by + bh + 10} L{bx + 40} {by + bh + 24} L{bx + 20} {by + bh + 38} L{bx + 20} {by + bh + 30} L{bx - 16} {by + bh + 30} Z",
               extra=f'stroke="#5ee0d0" stroke-width="{sw}" opacity="{op}" stroke-linejoin="round"')
    for i in range(5):  # sign stars
        x0, y0 = bx + 12 + i * 11, by + 20
        s.path(f"M{x0} {y0 - 3} L{x0 + 0.8} {y0} L{x0} {y0 + 3} L{x0 - 0.8} {y0} Z M{x0 - 3} {y0} L{x0} {y0 + 0.8} L{x0 + 3} {y0} L{x0} {y0 - 0.8} Z", "#ffd27a")
    # palms
    for x0, hgt in ((24, 130), (54, 104)):
        s.path(f"M{x0} 288 C{x0 + 4} 240 {x0 + 8} {288 - hgt + 30} {x0 + 14} {288 - hgt}", extra='stroke="#0c0614" stroke-width="3.6" stroke-linecap="round"')
        tx, ty = x0 + 14, 288 - hgt
        for a in (-2.7, -2.1, -1.3, -0.5, 0.2, 0.9):
            s.path(f"M{tx} {ty} Q{tx + math.cos(a) * 16:.1f} {ty + math.sin(a) * 16 - 6:.1f} {tx + math.cos(a) * 30:.1f} {ty + math.sin(a) * 18 + 8:.1f}", extra='stroke="#0c0614" stroke-width="3" stroke-linecap="round"')
    # low motel building
    s.rect("#0c0614", 0, 250, W, 40)
    for i in range(9):
        dx = 74 + i * 22
        s.rect("#ffd27a" if i % 3 else "#5ee0d0", dx, 262, 8, 12, 'opacity="0.55"')
    s.rect("#ff5fa2", 0, 250, W, 1.2, 'opacity="0.7"')
    return s


SCENES.update({"drivein": drivein, "motel": motel})


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(SCENES)
    for n in names:
        svg = SCENES[n]().svg()
        src = os.path.join(OUT, n + ".svg")
        with open(src, "w") as fh:
            fh.write(svg)
        subprocess.run(["rsvg-convert", src, "-o", os.path.join(OUT, n + ".png")], check=True)
        os.remove(src)
        print("rendered", n)


if __name__ == "__main__":
    main()
