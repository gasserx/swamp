import os, subprocess
def mark(tx=0, ty=0, k=1.0):
    st = 'font-family="Adwaita Sans" font-weight="700" fill="url(#gold)" stroke="#0d0d0d" stroke-width="{sw}" stroke-linejoin="round" paint-order="stroke"'
    # sWAMP: big W, the other letters smaller on the W's baseline, packed so they touch;
    # small letters drawn first so the W's outline sits over them
    return (f'<g transform="translate({tx} {ty}) scale({k})">'
            f'<text x="0" y="72" font-size="50" {st.format(sw=5)}>S</text>'
            f'<text x="88" y="72" font-size="50" letter-spacing="-2.5" {st.format(sw=5)}>AMP</text>'
            f'<text x="23" y="72" font-size="76" {st.format(sw=6)}>W</text>'
            '</g>')
gold = ('<defs><linearGradient id="gold" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="120" y2="140">'
        '<stop offset="0" stop-color="#fff1a6"/><stop offset="0.35" stop-color="#f5c518"/>'
        '<stop offset="0.7" stop-color="#d49a0a"/><stop offset="1" stop-color="#8a5f00"/></linearGradient></defs>')
def write(name, viewbox, body):
    open(name, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{viewbox}">{gold}{body}</svg>')
write("b_logo.svg", "-5 9 200 72", mark())
write("b_bar.svg", "-8 6 204 74", mark())
write("b_app.svg", "-5 -54 200 200", mark())
for n, w in (("b_logo", 800), ("b_bar", 300), ("b_app", 256)):
    subprocess.run(["rsvg-convert", "-w", str(w), n + ".svg", "-o", n + ".png"], check=True)
