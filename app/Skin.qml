pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Active skin. Every colour / style the UI uses is a key of `s`.
// Skins come from skins/skinpack.json (edited live: saving the file re-skins
// a running player). Missing keys fall back to `defaults` (the Classic skin).
Singleton {
  id: sk

  readonly property var defaults: ({
    id: "classic", name: "Classic",
    font: "Noto Sans Mono", lcdFont: "Noto Sans Mono",
    radius: 0, bevel: true, texture: "brushed", stripes: "pin", titleSpacing: 1.6,
    bgImage: "", bgOpacity: 1,   // optional picture behind the panels (path relative to shell.qml)
    windowBg: "#101016",
    chromeTop: "#33343f", chromeBottom: "#1d1e25", plTop: "#2a2b34", plBottom: "#1b1c22",
    bevelLight: "#7a7c90", bevelDark: "#07070a",
    textureLight: "#08ffffff", textureDark: "#0c000000",
    titleTop: "#3b3d4c", titleBottom: "#23242d", titleText: "#f2e2b0", titleTextDim: "#9a9cac",
    stripeA: "#d8b45a", stripeB: "#6d5524", stripeDim: "#4a4b58",
    lcdBg: "#030604", lcdText: "#3dff4f", lcdDim: "#0d2611", lcdHint: "#1f6a2c",
    lcdAccent: "#ffffff", lcdWarn: "#e8d23a", lcdAlert: "#c23a2a", selBg: "#14307a",
    btnTop: "#565867", btnBottom: "#30313b", btnHover: "#666879",
    btnDownTop: "#24252e", btnDownBottom: "#363844",
    btnLight: "#9496aa", btnDark: "#17181e", btnEdge: "#08080c",
    btnGlyph: "#dfe1ec", btnText: "#dfe1ec", ledOn: "#3dff5c", ledOff: "#173a1d",
    thumbTop: "#b8bac8", thumbBottom: "#5d5f6e", thumbActiveTop: "#c9a95a", thumbActiveBottom: "#7c6630",
    volA: "#1f9c2c", volB: "#c8c81e", volC: "#d23c14",
    visTop: "#ff3a1a", visHigh: "#f0d22a", visMid: "#3ad83a", visBottom: "#1a8a2a",
    visBg: "#06110a", peak: "#d8dce8",
    label: "#b4b6c6", labelDim: "#4a4c58",
    badgeBg: "#15161c", badgeTop: "#ffe9a0", badgeBottom: "#c8861e"
  })

  property var pack: []
  property string name: "classic"
  property string wanted: "classic"
  property var s: defaults

  function select(id) {
    wanted = id
    const e = pack.find(x => x.id === id) || pack.find(x => x.id === "classic") || {}
    s = Object.assign({}, defaults, e)
    name = e.id || "classic"
  }
  function cycle(dir) {
    if (!pack.length) return
    const i = pack.findIndex(x => x.id === name)
    select(pack[(i + dir + pack.length) % pack.length].id)
  }
  function merged(e) { return Object.assign({}, defaults, e) }

  FileView {
    id: packFile
    path: decodeURIComponent(Qt.resolvedUrl("skins/skinpack.json").toString().replace("file://", ""))
    blockLoading: true
    watchChanges: true
    printErrors: true
    onFileChanged: reload()
    onLoaded: {
      try {
        sk.pack = JSON.parse(text()).skins || []
        sk.select(sk.wanted)
      } catch (e) {
        console.warn("swamp: bad skinpack.json: " + e)
      }
    }
  }
}
