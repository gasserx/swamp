//@ pragma UseQApplication
//@ pragma AppId swamp
// sWamp: a small retro MP3 player in the spirit of late-90s desktop amps.
// Run with `qs -p <this folder>` (or the `swamp` launcher); control a running instance with
// `swamp ipc <function> [arg]` (see IpcHandler below).
import QtQuick
import QtQuick.Shapes
import QtQuick.Dialogs
import QtMultimedia
import Quickshell
import Quickshell.Io

ShellRoot {
  id: root

  // size multiplier: 1 unit of the 275-wide design = u logical px
  // default size: ~37% of the screen width (1.6 on a 1200-px-wide logical screen)
  readonly property real defaultU: {
    const env = Number(Quickshell.env("SWAMP_SCALE") || 0)
    if (env > 0) return env
    const sc = Quickshell.screens.length ? Quickshell.screens[0] : null
    return sc ? Math.round(Math.max(1.2, Math.min(3, sc.width / 750)) * 10) / 10 : 1.6
  }
  property real u: defaultU
  readonly property real minU: 0.9
  readonly property real maxU: 4.5
  // the skin picker always uses the full player size
  // layout width in design units: 275, wider when maximized (the panels stretch, `ex` = extra)
  readonly property real pw: win.full ? Math.max(275, win.width / Math.max(0.01, win.height / contentH)) : 275
  readonly property real ex: pw - 275
  readonly property real contentH: 116 + (showPlaylist || skinPicker ? plHeight : 0)
  function setScale(v, quiet) {
    // never larger than the screen
    const sc = win.screen
    if (sc && sc.width > 0) v = Math.min(v, (sc.width - 16) / 275, (sc.height - 46) / contentH)
    v = Math.round(Math.max(minU, Math.min(maxU, v)) * 100) / 100
    if (Math.abs(v - u) < 0.005) return
    u = v
    if (!quiet) flash("SIZE: " + Math.round(u / defaultU * 100) + "%  (CTRL+0 RESETS)")
    saveTimer.restart()
  }
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("helper.py").toString().replace("file://", ""))
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/swamp.json"
  readonly property string musicDir: Quickshell.env("HOME") + "/Music"

  // ---- persistent settings -------------------------------------------------
  property int current: -1
  property real volume: 0.7
  property bool shuffle: false
  property int repeatMode: 2         // 0 off, 1 repeat the song, 2 repeat the playlist
  property bool showPlaylist: true
  property bool showRemaining: false
  property bool visOn: true
  property bool loaded: false

  // ---- transient -----------------------------------------------------------
  property string flashText: ""       // overrides the marquee briefly
  property int playWhenIndex: -1      // play this row as soon as it is probed
  property var levels: []             // spectrum, 19 x 0..16
  property var shown: []              // smoothed bars
  property var peaks: []
  property bool blink: true
  property bool skinPicker: false
  // skin browsing: step through skins on the live player, then keep or go back
  property bool skinBrowse: false
  property string browseFrom: ""
  readonly property int skinIndex: Skin.pack.findIndex(x => x.id === Skin.name)
  function startBrowse() { if (!skinBrowse) browseFrom = Skin.name; skinPicker = false; skinBrowse = true; stage.forceActiveFocus() }
  function endBrowse(keep) { if (!keep && browseFrom) Skin.select(browseFrom); skinBrowse = false }
  function browseTo(i) { if (Skin.pack.length) Skin.select(Skin.pack[Math.max(0, Math.min(Skin.pack.length - 1, i))].id) }

  // Snapshot mode (SWAMP_SNAP=<dir>, see skins/snap.sh): a demo playlist that looks like it is
  // playing; every skin is rendered once to <dir>/<id>.jpg for the skin picker, then it quits.
  readonly property string snapDir: Quickshell.env("SWAMP_SNAP") || ""
  readonly property bool snap: snapDir !== ""
  property int snapI: 0
  Timer { id: shotTimer; interval: 1200; onTriggered: root.snapStep() }
  function snapStep() {
    if (!Skin.pack.length) { shotTimer.restart(); return }
    if (snapI >= Skin.pack.length) { Qt.quit(); return }
    const id = Skin.pack[snapI].id
    if (Skin.name !== id) { Skin.select(id); shotTimer.restart(); return }
    const k = 2.4
    root.flashText = ""
    main.grabToImage(r => {
      r.saveToFile(snapDir + "/" + id + ".jpg")
      console.log("snap: " + id)
      snapI++
      if (snapI < Skin.pack.length) Skin.select(Skin.pack[snapI].id)
      shotTimer.restart()
    }, Qt.size(Math.round(root.pw * k), Math.round(116 * k)))
  }
  function snapSetup() {
    const demo = [
      ["The Velvet Hours", "Midnight Boulevard", 254], ["Lumen Drive", "Neon Avenue", 231],
      ["Copper Tides", "Saltwater Radio", 302], ["The Groove Assembly", "Mirrorball Heart", 268],
      ["Harlow & Finch", "Long Way to Memphis", 289], ["Desert Static", "Highway Mirage", 245],
      ["Sunday Arcade", "Polaroid Summer", 213], ["Moonlit Brass", "After Hours Swing", 276],
      ["The Lowland Kings", "Tumbleweed Waltz", 198], ["Kaleido", "Satellite Love", 241],
      ["Orchid Union", "Velvet Rain", 318], ["Tape Hiss Club", "Rewind the Night", 226],
      ["Marigold Sound", "Golden Hour Fade", 259], ["Retro Galaxy", "Cosmic Highway", 287]
    ]
    tracks.append(demo.map((d, i) => ({ path: "/snap/Demo/" + (i + 1) + ".mp3", artist: d[0], title: d[1], dur: d[2] * 1000,
                                         kbps: 320, khz: 44, ch: 2, sel: false })))
    current = 3
    showPlaylist = false; visOn = true; volume = 0.72
    shown = [5, 9, 13, 15, 14, 12, 13, 11, 9, 10, 8, 9, 7, 6, 7, 5, 4, 3, 2]
    peaks = shown.map(v => Math.min(16, v + 2))
    rebuildView()
    shotTimer.restart()
  }
  readonly property real posMs: snap ? 97000 : player.position
  readonly property real durMs: snap ? 268000 : player.duration

  readonly property bool playing: snap || player.playbackState === MediaPlayer.PlayingState
  readonly property bool paused: player.playbackState === MediaPlayer.PausedState
  readonly property var track: current >= 0 && current < tracks.count ? tracks.get(current) : null
  readonly property int plHeight: 172

  ListModel { id: tracks }
  // What the playlist shows: when tracks come from more than one folder, one
  // row per folder (click to open/close) with its tracks listed under it.
  // `ti` is the row's index into `tracks`; folder rows point at their first track.
  ListModel { id: view }
  property var openDirs: ({})
  property bool grouped: false
  property var groups: ({})          // dir -> { items: [track indices], dur }
  property var groupOrder: []
  property var selSet: ({})          // track indices currently selected
  readonly property string curDir: track ? dirOf(track.path) : ""
  function dirOf(p) { const i = p.lastIndexOf("/"); return i > 0 ? p.slice(0, i) : "/" }
  function trackRow(ti, n, d) {
    return { kind: "track", ti: ti, n: n, dir: d, label: "", count: 0, gdur: 0, open: false, dsel: false }
  }
  function rebuildView() {
    const order = [], g = {}
    let total = 0
    const sel = {}
    for (let k = 0; k < tracks.count; k++) {
      const t = tracks.get(k), d = dirOf(t.path)
      if (!g[d]) { g[d] = { items: [], dur: 0 }; order.push(d) }
      g[d].items.push(k); g[d].dur += t.dur; total += t.dur
      if (t.sel) sel[k] = true
    }
    groups = g; groupOrder = order; selSet = sel; totalTime = total
    grouped = order.length > 1
    const rows = []
    if (!grouped) {
      for (let k = 0; k < tracks.count; k++) rows.push(trackRow(k, k + 1, ""))
    } else {
      // label folders relative to the deepest folder they all share
      let common = order[0].split("/")
      for (const d of order) {
        const parts = d.split("/"); let i = 0
        while (i < common.length && i < parts.length && common[i] === parts[i]) i++
        common = common.slice(0, i)
      }
      const cut = common.join("/").length
      for (const d of order) {
        const gr = g[d], open = !!openDirs[d]
        let label = d.slice(cut).replace(/^\/+/, "")
        if (!label) label = d.split("/").pop() || d
        rows.push({ kind: "dir", ti: gr.items[0], n: 0, dir: d, label: label, count: gr.items.length,
                    gdur: gr.dur, open: open, dsel: false })
        if (open) gr.items.forEach((ti, j) => rows.push(trackRow(ti, j + 1, d)))
      }
    }
    const y = list.contentY
    view.clear()
    if (rows.length) view.append(rows)
    list.contentY = Math.min(y, Math.max(0, list.contentHeight - list.height))
  }
  Timer { id: viewTimer; interval: 200; onTriggered: root.rebuildView() }
  // open/close one folder: insert or remove just its rows
  function toggleDir(r) {
    const v = view.get(r), d = v.dir, gr = groups[d]
    const o = Object.assign({}, openDirs)
    if (v.open) {
      delete o[d]
      view.setProperty(r, "open", false)
      if (gr && gr.items.length) view.remove(r + 1, gr.items.length)
    } else {
      o[d] = true
      view.setProperty(r, "open", true)
      if (gr) for (let j = gr.items.length - 1; j >= 0; j--) view.insert(r + 1, trackRow(gr.items[j], j + 1, d))
    }
    openDirs = o
    saveTimer.restart()
  }
  // track indices a playlist row stands for
  function rowTracks(r) {
    const v = view.get(r)
    if (v.kind === "track") return [v.ti]
    return groups[v.dir] ? groups[v.dir].items : []
  }
  function setSel(want) {
    for (const k in selSet) if (!want[k]) tracks.setProperty(Number(k), "sel", false)
    for (const k in want) if (!selSet[k]) tracks.setProperty(Number(k), "sel", true)
    selSet = want
  }
  property var dselRows: []
  function selectRows(rows) {
    const want = {}
    for (const r of rows) for (const ti of rowTracks(r)) want[ti] = true
    setSel(want)
    for (const r of dselRows) if (r < view.count) view.setProperty(r, "dsel", false)
    dselRows = rows.filter(r => view.get(r).kind === "dir")
    for (const r of dselRows) view.setProperty(r, "dsel", true)
  }


  component Info: Bevel {
    property string value: ""
    sunken: true
    fill: Skin.s.lcdBg
    height: 9
    Text {
      textFormat: Text.PlainText
      anchors.right: parent.right; anchors.rightMargin: 1.5
      anchors.verticalCenter: parent.verticalCenter
      text: parent.value
      color: Skin.s.lcdText
      font.family: Skin.s.lcdFont; font.pointSize: 4.875; font.bold: true
    }
  }
  // the skin's background picture; it spans main panel + playlist, `panelY` = where this panel starts
  component SkinPicture: Item {
    property real panelY: 0
    anchors.fill: parent
    clip: true
    visible: Skin.s.bgImage !== ""
    Image {
      y: -parent.panelY
      width: root.pw; height: 116 + 172
      fillMode: Image.PreserveAspectCrop
      verticalAlignment: Image.AlignTop
      source: Skin.s.bgImage !== "" ? Qt.resolvedUrl(Skin.s.bgImage) : ""
      sourceSize: Qt.size(1100, 1152)
      opacity: Skin.s.bgOpacity
      smooth: true; mipmap: true
      asynchronous: true
    }
  }
  component Lbl: Text {
    textFormat: Text.PlainText
    color: Skin.s.label
    font.family: Skin.s.font; font.pointSize: 3.75; font.bold: true
  }


  function fileUrl(p) {
    if (p.indexOf("://") >= 0) return p
    return "file://" + p.split("/").map(encodeURIComponent).join("/")
  }
  function urlToPath(u) {
    const s = u.toString()
    return s.startsWith("file://") ? decodeURIComponent(s.slice(7)) : s
  }
  function fmt(ms) {
    if (!ms || ms < 0) ms = 0
    const t = Math.floor(ms / 1000)
    const m = Math.floor(t / 60), s = t % 60
    return m + ":" + (s < 10 ? "0" : "") + s
  }
  function trackName(i) {
    if (i < 0 || i >= tracks.count) return ""
    const t = tracks.get(i)
    return (t.artist ? t.artist + " - " : "") + t.title
  }
  // Hyprland has no minimize: park the window on a hidden special workspace,
  // and bring it back to whatever workspace is active (bar button / launcher).
  readonly property string winSel: "title:^(sWamp)$"
  function minimize() {
    Quickshell.execDetached(["hyprctl", "dispatch",
      "hl.dsp.window.move({ workspace = \"special:swamp\", follow = false, window = \"" + winSel + "\" })"])
  }
  function toggleFullscreen() {
    Quickshell.execDetached(["hyprctl", "dispatch",
      "hl.dsp.window.fullscreen({ mode = \"maximized\", window = \"" + winSel + "\" })"])
  }
  function restore() {
    Quickshell.execDetached(["bash", "-c",
      // focusing makes Hyprland warp the pointer to the window's centre: put it back where it was
      "ws=$(hyprctl activeworkspace -j | jq -r .id); pos=$(hyprctl cursorpos | tr -d ' '); "
      + "hyprctl --batch \"dispatch hl.dsp.window.move({ workspace = '$ws', window = '" + winSel + "' }) ; "
      + "dispatch hl.dsp.focus({ window = '" + winSel + "' }) ; "
      + "dispatch hl.dsp.cursor.move({ x = ${pos%,*}, y = ${pos#*,} })\""])
  }
  function flash(msg) { flashText = msg; flashTimer.restart() }

  // ---- adding tracks -------------------------------------------------------
  Component {
    id: probeJob
    Process {
      id: job
      property bool playFirst: false
      property var pending: []
      // paths go in on stdin, not argv: stream URLs may carry credentials or tokens,
      // and process arguments are visible to other local users
      property string input: ""
      stdinEnabled: true
      onStarted: { write(input); stdinEnabled = false }
      // big libraries: collect lines and append them in chunks, not one by one
      function flush() {
        if (!pending.length) return
        const batch = pending; pending = []
        const first = tracks.count
        tracks.append(batch)
        if (playFirst) { playFirst = false; root.playIndex(first) }
        saveTimer.restart()
      }
      running: true
      stdout: SplitParser {
        onRead: line => {
          let t
          try { t = JSON.parse(line) } catch (e) { return }
          job.pending.push({ path: t.path, title: t.title, artist: t.artist, dur: t.dur,
                             kbps: t.kbps, khz: t.khz, ch: t.ch, sel: false })
          if (job.playFirst || job.pending.length >= 500) job.flush()
          else if (!flushTimer.running) flushTimer.start()
        }
      }
      property Timer flushTimer: Timer { interval: 120; onTriggered: job.flush() }
      onExited: { flush(); destroy() }
    }
  }
  // list file written by the launcher (0600 in $XDG_RUNTIME_DIR); the helper reads and deletes it
  function addListFile(file, playFirst) {
    flash("LOADING...")
    probeJob.createObject(root, { command: ["python3", helper, "probe", "-"], input: "@" + file + "\n", playFirst: !!playFirst })
  }
  function addPaths(paths, playFirst) {
    paths = paths.filter(p => p && p.length)
    if (!paths.length) return
    flash("LOADING " + paths.length + (paths.length === 1 ? " ITEM..." : " ITEMS..."))
    probeJob.createObject(root, { command: ["python3", helper, "probe", "-"], input: paths.join("\n") + "\n", playFirst: !!playFirst })
  }

  // ---- transport -----------------------------------------------------------
  function playIndex(i) {
    if (i < 0 || i >= tracks.count) return
    current = i
    player.source = fileUrl(tracks.get(i).path)
    player.play()
    saveTimer.restart()
  }
  function play() {
    if (paused) player.play()
    else if (current >= 0 && current < tracks.count) {
      if (playing) player.position = 0
      else playIndex(current)
    } else if (tracks.count) playIndex(0)
    else openDialog.open()
  }
  function pause() { if (playing) player.pause(); else if (paused) player.play() }
  function stop() { player.stop() }
  function nextIndex(dir) {
    if (!tracks.count) return -1
    if (shuffle && tracks.count > 1) {
      let n = current
      while (n === current) n = Math.floor(Math.random() * tracks.count)
      return n
    }
    const n = current + dir
    if (n >= tracks.count) return repeatMode === 2 ? 0 : -1
    if (n < 0) return repeatMode === 2 ? tracks.count - 1 : 0
    return n
  }
  function next() { const n = nextIndex(1); if (n >= 0) playIndex(n) }
  function prev() {
    if (player.position > 3000 && !shuffle) { player.position = 0; return }
    const n = nextIndex(-1); if (n >= 0) playIndex(n)
  }
  function seekBy(ms) {
    if (player.seekable) player.position = Math.max(0, Math.min(player.duration, player.position + ms))
  }
  function setVolume(v) {
    volume = Math.max(0, Math.min(1, v))
    flash("VOLUME: " + Math.round(volume * 100) + "%")
    saveTimer.restart()
  }

  // ---- playlist edit -------------------------------------------------------
  function selectOnly(i) { const w = {}; w[i] = true; setSel(w) }
  function removeSelected() {
    const ks = Object.keys(selSet).map(Number).sort((a, b) => b - a)
    if (!ks.length) return
    let cur = current
    for (const k of ks) {
      if (k === current) { player.stop(); cur = -1 }
      else if (k < current && cur >= 0) cur--
    }
    // remove from the bottom up, one contiguous run at a time
    let i = 0
    while (i < ks.length) {
      let j = i
      while (j + 1 < ks.length && ks[j + 1] === ks[j] - 1) j++
      tracks.remove(ks[j], j - i + 1)
      i = j + 1
    }
    current = cur
    selSet = ({}); dselRows = []
    rebuildView()
    saveTimer.restart()
  }
  function clearList() { player.stop(); player.source = ""; tracks.clear(); selSet = ({}); dselRows = []; current = -1; saveTimer.restart() }

  // ---- state ---------------------------------------------------------------
  FileView {
    id: stateFile
    path: root.statePath
    blockLoading: true
    printErrors: false
  }
  // the playlist may hold stream URLs with credentials: keep the state file private
  // (created 0600 before the first save; FileView keeps an existing file's mode)
  property bool stateSecured: false
  Process {
    running: !root.snap
    command: ["sh", "-c", "umask 077; mkdir -p \"$(dirname \"$0\")\" && : >> \"$0\" && chmod 600 \"$0\"", root.statePath]
    onExited: root.stateSecured = true
  }
  Component.onCompleted: {
    if (snap) { snapSetup(); return }
    try {
      const s = JSON.parse(stateFile.text() || "{}")
      const saved = (s.tracks || []).map(t => Object.assign({ sel: false, artist: "", dur: 0, kbps: 0, khz: 0, ch: 2 }, t))
      if (saved.length) tracks.append(saved)
      if (s.volume !== undefined) volume = s.volume
      shuffle = !!s.shuffle
      repeatMode = s.repeatMode !== undefined ? s.repeatMode : (s.repeat === false ? 0 : 2)
      showPlaylist = s.showPlaylist !== undefined ? s.showPlaylist : true
      showRemaining = !!s.showRemaining
      visOn = s.visOn !== undefined ? s.visOn : true
      if (s.openDirs) for (const d of s.openDirs) openDirs[d] = true
      Skin.select(s.skin || "disco")
      if (s.scale && !Quickshell.env("SWAMP_SCALE")) u = Math.max(minU, Math.min(maxU, s.scale))
      current = s.current !== undefined && s.current < tracks.count ? s.current : -1
      if (current >= 0) player.source = fileUrl(tracks.get(current).path)
    } catch (e) {}
    loaded = true
    rebuildView()
    viewTimer.stop()
    const args = (Quickshell.env("SWAMP_OPEN") || "").split("\n").filter(a => a)
    if (args.length) { clearList(); addPaths(args, true) }
  }
  Timer {
    id: saveTimer
    interval: 600
    onTriggered: {
      if (!root.loaded) return
      if (!root.stateSecured) { restart(); return }
      const list = []
      for (let k = 0; k < tracks.count; k++) {
        const t = tracks.get(k)
        list.push({ path: t.path, title: t.title, artist: t.artist, dur: t.dur, kbps: t.kbps, khz: t.khz, ch: t.ch })
      }
      stateFile.setText(JSON.stringify({
        tracks: list, current: root.current, volume: root.volume, shuffle: root.shuffle,
        repeatMode: root.repeatMode, showPlaylist: root.showPlaylist, showRemaining: root.showRemaining,
        visOn: root.visOn, skin: Skin.name, scale: root.u,
        openDirs: Object.keys(root.openDirs)
      }))
    }
  }
  onShuffleChanged: saveTimer.restart()
  function cycleRepeat() {
    repeatMode = (repeatMode + 1) % 3
    flash("REPEAT: " + ["OFF", "THIS SONG", "WHOLE PLAYLIST"][repeatMode])
  }
  onRepeatModeChanged: saveTimer.restart()
  onShowPlaylistChanged: saveTimer.restart()
  onShowRemainingChanged: saveTimer.restart()
  onVisOnChanged: saveTimer.restart()
  Connections {
    target: Skin
    function onNameChanged() { saveTimer.restart(); root.flash("SKIN: " + Skin.s.name.toUpperCase()) }
  }

  Timer { id: flashTimer; interval: 1600; onTriggered: root.flashText = "" }
  Timer { interval: 500; repeat: true; running: root.paused; onTriggered: root.blink = !root.blink; onRunningChanged: root.blink = true }

  // ---- audio ---------------------------------------------------------------
  MediaPlayer {
    id: player
    audioOutput: AudioOutput { volume: root.volume * root.volume }
    onMediaStatusChanged: {
      if (mediaStatus === MediaPlayer.EndOfMedia) {
        if (root.repeatMode === 1 && root.current >= 0) { root.playIndex(root.current); return }
        const n = root.nextIndex(1)
        if (n >= 0) root.playIndex(n)
      }
    }
    onErrorOccurred: (err, msg) => root.flash("ERROR: " + (msg || "cannot play this file"))
  }

  // spectrum from the output monitor while something is playing
  Process {
    running: root.playing && root.visOn && win.visible && !root.snap
    command: ["python3", root.helper, "spectrum"]
    stdout: SplitParser { onRead: line => root.levels = line.split(" ").map(Number) }
    onRunningChanged: if (!running) root.levels = []
  }
  Timer {
    interval: 33
    repeat: true
    // keeps running after VIS is switched off (or playback stops) until the bars have fallen to the bottom
    running: !root.snap && ((root.visOn && root.playing) || root.shown.some(v => v > 0) || root.peaks.some(v => v > 0))
    onTriggered: {
      const s = [], p = []
      for (let i = 0; i < 19; i++) {
        const target = root.playing && root.visOn ? (root.levels[i] || 0) : 0
        const cur = root.shown[i] || 0
        const v = target > cur ? target : Math.max(0, cur - 0.9)
        s.push(v)
        const pk = root.peaks[i] || 0
        p.push(v >= pk ? v : Math.max(0, pk - 0.25))
      }
      root.shown = s
      root.peaks = p
    }
  }

  // ---- control from outside -----------------------------------------------
  IpcHandler {
    target: "swamp"
    // paths are newline-separated so one call can hand over many files
    function add(paths: string): void { root.addPaths(paths.split("\n"), false) }
    function open(paths: string): void { root.clearList(); root.addPaths(paths.split("\n"), true) }
    function enqueue(paths: string): void { root.addPaths(paths.split("\n"), !root.playing && !root.paused) }
    function openList(file: string): void { root.clearList(); root.addListFile(file, true) }
    function enqueueList(file: string): void { root.addListFile(file, !root.playing && !root.paused) }
    function toggle(): void { if (root.playing) player.pause(); else root.play() }
    function play(): void { root.play() }
    function pause(): void { root.pause() }
    function stop(): void { root.stop() }
    function next(): void { root.next() }
    function prev(): void { root.prev() }
    function restore(): void { root.restore() }
    function fullscreen(): void { root.toggleFullscreen() }
    function minimize(): void { root.minimize() }
    function skin(id: string): void { Skin.select(id) }
    function picker(): void { root.skinPicker = !root.skinPicker }
    function browse(): void { root.startBrowse() }
    function browseDone(keep: bool): void { root.endBrowse(keep) }
    function scale(v: string): void { root.setScale(Number(v)) }
    function skins(): string { return Skin.pack.map(x => x.id + "\t" + x.name).join("\n") }
    function status(): string {
      const st = root.playing ? "playing" : root.paused ? "paused" : "stopped"
      return st + "\t" + (root.track ? root.trackName(root.current) : "")
    }
    function quit(): void { Qt.quit() }
  }

  FloatingWindow {
    id: win
    title: root.snap ? "sWamp snapshots" : "sWamp"
    color: Skin.s.windowBg
    readonly property real w: Math.round(275 * root.u)
    readonly property real h: Math.round(root.contentH * root.u)
    implicitWidth: w
    implicitHeight: h
    minimumSize: Qt.size(Math.round(275 * root.minU), Math.round(116 * root.minU))
    // content scale that fits the actual window (it can be resized by Hyprland too)
    readonly property real fit: full ? height / root.contentH : Math.min(width / 275, height / root.contentH)
    // maximized (fills the screen, bar stays visible): the player just scales to fit, its saved size stays.
    // Hyprland is asked for the real state whenever the window size changes.
    property bool full: false
    Process {
      id: fullCheck
      command: ["bash", "-c", "hyprctl clients -j | jq -r '.[] | select(.title == \"sWamp\") | .fullscreen' | head -1"]
      stdout: SplitParser { onRead: line => win.full = line.trim() !== "" && line.trim() !== "0" }
    }
    // Float the window if no Hyprland rule did (install.sh adds one, but the
    // plugin also works without it).
    Process {
      id: floatCheck
      command: ["bash", "-c", "hyprctl clients -j | jq -r '.[] | select(.title == \"sWamp\") | .floating' | head -1"]
      stdout: SplitParser {
        onRead: line => {
          if (line.trim() === "false")
            Quickshell.execDetached(["bash", "-c",
              "hyprctl dispatch 'hl.dsp.window.float({ action = \"toggle\", window = \"title:^(sWamp)$\" })' && "
              + "hyprctl dispatch 'hl.dsp.window.center({ window = \"title:^(sWamp)$\" })'"])
        }
      }
    }
    Timer { interval: 400; running: !root.snap; onTriggered: floatCheck.running = true }
    Timer { id: fullTimer; interval: 120; onTriggered: if (!root.snap) { fullCheck.running = false; fullCheck.running = true } }
    // after a compositor resize, adopt that size and snap the window back to the player's proportions
    // Hyprland ignores client-side size changes of a mapped floating window,
    // so ask the compositor for the size the player wants
    onWChanged: resizeTimer.restart()
    onHChanged: resizeTimer.restart()
    Timer {
      id: resizeTimer
      interval: 30
      onTriggered: if (!root.snap && !win.full && (win.width !== win.w || win.height !== win.h))
        // keeps the top-left corner in place and the window on screen (helper.py place)
        Quickshell.execDetached(["python3", root.helper, "place", "sWamp", String(win.w), String(win.h)])
    }
    onWidthChanged: { fullTimer.restart(); snapTimer.restart() }
    onHeightChanged: { fullTimer.restart(); snapTimer.restart() }
    Timer {
      id: snapTimer
      interval: 350
      // follow whichever side the user dragged more, then snap back to the player's shape
      onTriggered: {
        if (root.snap || win.full || grip.pressed || win.width <= 0 || win.height <= 0) return
        const fW = win.width / 275, fH = win.height / root.contentH
        const f = Math.abs(fW - root.u) >= Math.abs(fH - root.u) ? fW : fH
        if (Math.abs(f - root.u) > 0.01) root.setScale(f, true)
        if (win.width !== win.w || win.height !== win.h) resizeTimer.restart()
      }
    }

    FileDialog {
      id: openDialog
      title: "Add files"
      fileMode: FileDialog.OpenFiles
      currentFolder: root.fileUrl(root.musicDir)
      nameFilters: ["Audio (*.mp3 *.flac *.ogg *.opus *.m4a *.aac *.wav *.wma *.m3u *.m3u8)", "All files (*)"]
      onAccepted: root.addPaths(selectedFiles.map(root.urlToPath), !root.playing && !root.paused)
    }
    FolderDialog {
      id: dirDialog
      title: "Add folder (local or a mounted network share)"
      currentFolder: root.fileUrl(root.musicDir)
      onAccepted: root.addPaths([root.urlToPath(selectedFolder)], !root.playing && !root.paused)
    }

    Item {
      id: stage
      width: root.pw
      height: 116 + root.plHeight
      scale: win.fit
      transformOrigin: Item.TopLeft
      x: Math.max(0, (win.width - root.pw * win.fit) / 2)
      y: Math.max(0, (win.height - root.contentH * win.fit) / 2)
      focus: true

      WheelHandler {
        acceptedModifiers: Qt.ControlModifier
        onWheel: ev => root.setScale(root.u * (ev.angleDelta.y > 0 ? 1.08 : 1 / 1.08))
      }

      Keys.onPressed: e => {
        if (urlBox.visible) return
        if (e.key === Qt.Key_Escape && root.skinPicker) { root.skinPicker = false; e.accepted = true; return }
        if (root.skinBrowse) {
          const bk = e.key
          if (bk === Qt.Key_Left || bk === Qt.Key_Up) { Skin.cycle(-1); e.accepted = true; return }
          if (bk === Qt.Key_Right || bk === Qt.Key_Down || bk === Qt.Key_K) { Skin.cycle((e.modifiers & Qt.ShiftModifier) ? -1 : 1); e.accepted = true; return }
          if (bk === Qt.Key_Return || bk === Qt.Key_Enter) { root.endBrowse(true); e.accepted = true; return }
          if (bk === Qt.Key_Escape) { root.endBrowse(false); e.accepted = true; return }
        }
        const k = e.key
        if (e.modifiers & Qt.ControlModifier) {
          if (k === Qt.Key_Plus || k === Qt.Key_Equal) { root.setScale(root.u * 1.1); e.accepted = true; return }
          if (k === Qt.Key_Minus) { root.setScale(root.u / 1.1); e.accepted = true; return }
          if (k === Qt.Key_0) { root.setScale(root.defaultU); e.accepted = true; return }
        }
        if (k === Qt.Key_F11) root.toggleFullscreen()
        else if (k === Qt.Key_Z) root.prev()
        else if (k === Qt.Key_X) root.play()
        else if (k === Qt.Key_C) root.pause()
        else if (k === Qt.Key_V) root.stop()
        else if (k === Qt.Key_B) root.next()
        else if (k === Qt.Key_L) openDialog.open()
        else if (k === Qt.Key_Space) { if (root.playing) player.pause(); else root.play() }
        else if (k === Qt.Key_Left) root.seekBy(-5000)
        else if (k === Qt.Key_Right) root.seekBy(5000)
        else if (k === Qt.Key_Up) root.setVolume(root.volume + 0.05)
        else if (k === Qt.Key_Down) root.setVolume(root.volume - 0.05)
        else if (k === Qt.Key_S) root.shuffle = !root.shuffle
        else if (k === Qt.Key_R) root.cycleRepeat()
        else if (k === Qt.Key_K) { root.startBrowse(); Skin.cycle((e.modifiers & Qt.ShiftModifier) ? -1 : 1) }
        else if (k === Qt.Key_Delete) root.removeSelected()
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
          const ks = Object.keys(root.selSet).map(Number)
          if (ks.length) root.playIndex(Math.min.apply(null, ks))
        } else if (k === Qt.Key_A && (e.modifiers & Qt.ControlModifier)) {
          const w = {}; for (let i = 0; i < tracks.count; i++) w[i] = true; root.setSel(w)
        } else return
        e.accepted = true
      }

      DropArea {
        anchors.fill: parent
        onDropped: d => { if (d.hasUrls) root.addPaths(d.urls.map(root.urlToPath), !root.playing && !root.paused) }
      }

      // ================= main panel =================
      Item {
        id: main
        width: root.pw
        height: 116

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop { position: 0; color: Skin.s.chromeTop }
            GradientStop { position: 1; color: Skin.s.chromeBottom }
          }
        }
        // surface texture: brushed | scan | dots | none
        Repeater {
          model: Skin.s.texture === "brushed" ? 50 : Skin.s.texture === "scan" ? 85 : 0
          Rectangle {
            required property int index
            readonly property bool scan: Skin.s.texture === "scan"
            y: 14 + index * (scan ? 1.2 : 2.04)
            width: root.pw
            height: scan ? 0.45 : 0.5
            color: scan ? Skin.s.textureDark : (index % 3 ? Skin.s.textureLight : Skin.s.textureDark)
          }
        }
        Image {
          visible: Skin.s.texture === "dots"
          x: 1; y: 15; width: root.pw - 2; height: 100
          fillMode: Image.Tile
          smooth: true
          sourceSize: Qt.size(3, 3)
          source: "data:image/svg+xml;utf8," + encodeURIComponent("<svg xmlns='http://www.w3.org/2000/svg' width='3' height='3'>"
                  + "<circle cx='1.5' cy='1.5' r='0.55' fill='" + Skin.s.textureDark + "'/></svg>")
        }
        SkinPicture { panelY: 0 }
        Bevel { anchors.fill: parent; fill: "transparent"; light: Skin.s.bevelLight; dark: Skin.s.bevelDark }

        TitleBar {
          x: 1
          y: 1
          width: root.pw - 2
          title: ""
          wordmark: "assets/logo-wa.png"
          onDragStarted: win.startSystemMove()
          onDoubleClicked: root.showPlaylist = !root.showPlaylist
          onRightClicked: root.skinPicker = !root.skinPicker
          Btn { icon: "min"; width: 9; height: 9; onClicked: root.minimize() }
          Btn { icon: win.full ? "unmax" : "max"; width: 9; height: 9; onClicked: root.toggleFullscreen() }
          Btn { icon: "close"; width: 9; height: 9; onClicked: Qt.quit() }
        }

        // ---- LCD: status, time, visualizer ----
        Bevel {
          id: lcd
          x: 9; y: 19; width: 95; height: 44
          sunken: true
          fill: Skin.s.lcdBg

          Shape {
            x: 5; y: 6; width: 6; height: 7
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeWidth: -1
              fillColor: root.playing ? Skin.s.lcdText : root.paused ? Skin.s.lcdWarn : Skin.s.lcdAlert
              PathSvg {
                path: root.playing ? "M 0 0 L 6 3.5 L 0 7 Z"
                    : root.paused ? "M 0 0 L 2 0 L 2 7 L 0 7 Z M 4 0 L 6 0 L 6 7 L 4 7 Z"
                    : "M 0 0.5 L 6 0.5 L 6 6.5 L 0 6.5 Z"
              }
            }
          }

          Row {
            id: clock
            x: 26; y: 3
            spacing: 2.4
            readonly property int ms: root.showRemaining && root.durMs > 0
                                      ? root.durMs - root.posMs : root.posMs
            readonly property int secs: Math.floor(ms / 1000)
            readonly property string mm: { const m = Math.min(99, Math.floor(secs / 60)); return (m < 10 ? "0" : "") + m }
            readonly property string ss: { const s = secs % 60; return (s < 10 ? "0" : "") + s }
            readonly property bool idle: !root.snap && player.playbackState === MediaPlayer.StoppedState
            opacity: root.paused && !root.blink ? 0.12 : 1
            Seg { ch: root.showRemaining && !clock.idle ? "-" : " " }
            Seg { ch: clock.idle ? " " : clock.mm[0] }
            Seg { ch: clock.idle ? " " : clock.mm[1] }
            Item {
              width: 2; height: 13
              Rectangle { y: 3.5; width: 1.6; height: 1.6; color: clock.idle ? Skin.s.lcdDim : Skin.s.lcdText }
              Rectangle { y: 8.5; width: 1.6; height: 1.6; color: clock.idle ? Skin.s.lcdDim : Skin.s.lcdText }
            }
            Seg { ch: clock.idle ? " " : clock.ss[0] }
            Seg { ch: clock.idle ? " " : clock.ss[1] }
          }
          MouseArea {
            x: clock.x; y: clock.y; width: clock.width; height: clock.height
            onClicked: root.showRemaining = !root.showRemaining
          }

          // spectrum analyzer
          Item {
            id: vis
            x: 4; y: 21; width: 87; height: 19
            Repeater {
              model: 19
              Item {
                id: bar
                required property int index
                x: index * 4.6
                width: 3.6
                height: vis.height
                readonly property real lv: (root.shown[index] || 0) / 16
                readonly property real pk: (root.peaks[index] || 0) / 16
                Rectangle { anchors.fill: parent; color: Skin.s.visBg }
                Item {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: parent.height * bar.lv
                  clip: true
                  Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: vis.height
                    gradient: Gradient {
                      GradientStop { position: 0.0; color: Skin.s.visTop }
                      GradientStop { position: 0.35; color: Skin.s.visHigh }
                      GradientStop { position: 0.7; color: Skin.s.visMid }
                      GradientStop { position: 1.0; color: Skin.s.visBottom }
                    }
                  }
                }
                Rectangle {
                  visible: bar.pk > 0.02
                  y: vis.height * (1 - bar.pk) - 0.8
                  width: parent.width
                  height: 0.8
                  color: Skin.s.peak
                }
              }
            }
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              visible: !root.visOn
              text: "VIS OFF"
              color: Skin.s.lcdHint
              font.family: Skin.s.lcdFont
              font.pointSize: 4.125
              font.bold: true
            }
            MouseArea { anchors.fill: parent; onClicked: root.visOn = !root.visOn }
          }
        }

        // ---- song marquee ----
        Bevel {
          id: marqueeBox
          x: 110; y: 19; width: 156 + root.ex; height: 13
          sunken: true
          fill: Skin.s.lcdBg
          Item {
            id: clipper
            x: 2; y: 1; width: parent.width - 4; height: parent.height - 2
            clip: true
            readonly property string txt: root.flashText !== "" ? root.flashText
              : root.track ? (root.current + 1) + ". " + root.trackName(root.current)
                             + (root.track.dur ? " (" + root.fmt(root.track.dur) + ")" : "")
              : "SWAMP  -  DROP FILES HERE OR PRESS L"
            readonly property bool scrolls: t1.implicitWidth > width
            Row {
              id: marq
              y: (clipper.height - t1.height) / 2
              Text { id: t1; textFormat: Text.PlainText; text: clipper.txt.toUpperCase(); color: Skin.s.lcdText; font.family: Skin.s.lcdFont; font.pointSize: 5.25; font.bold: true }
              Text { textFormat: Text.PlainText; visible: clipper.scrolls; text: "   ***   "; color: Skin.s.lcdText; font: t1.font }
              Text { textFormat: Text.PlainText; visible: clipper.scrolls; text: t1.text; color: Skin.s.lcdText; font: t1.font }
            }
            NumberAnimation {
              target: marq
              property: "x"
              running: clipper.scrolls && root.flashText === ""
              from: 0
              to: -(marq.width - t1.implicitWidth)
              duration: Math.max(1, -to * 55)
              loops: Animation.Infinite
              onRunningChanged: if (!running) marq.x = 0
            }
            Connections {
              target: clipper
              function onTxtChanged() { marq.x = 0 }
            }
          }
        }

        // ---- kbps / khz / mono-stereo ----
        Info { x: 110; y: 36; width: 20; value: root.track && root.track.kbps ? String(root.track.kbps) : "" }
        Lbl { x: 132; y: 38; text: "kbps" }
        Info { x: 152; y: 36; width: 14; value: root.track && root.track.khz ? String(root.track.khz) : "" }
        Lbl { x: 168; y: 38; text: "kHz" }
        Lbl { x: 214 + root.ex; y: 38; text: "mono"; color: root.track && root.track.ch === 1 && !clock.idle ? Skin.s.lcdText : Skin.s.labelDim }
        Lbl { x: 236 + root.ex; y: 38; text: "stereo"; color: root.track && root.track.ch > 1 && !clock.idle ? Skin.s.lcdText : Skin.s.labelDim }

        // ---- volume + panel toggles ----
        Lbl { x: 110; y: 52; text: "VOL" }
        HSlider {
          x: 124; y: 50; width: 78 + root.ex; height: 9
          fillStyle: true
          thumbW: 9
          value: root.volume
          onMoved: v => root.setVolume(v)
        }
        Btn { x: 208 + root.ex; y: 49; width: 28; height: 11; label: "VIS"; labelSize: 5; checkable: true; checked: root.visOn; onClicked: root.visOn = checked }
        Btn { x: 238 + root.ex; y: 49; width: 28; height: 11; label: "PL"; labelSize: 5; checkable: true; checked: root.showPlaylist; onClicked: root.showPlaylist = checked }

        // ---- seek bar ----
        HSlider {
          id: seek
          x: 9; y: 68; width: 257 + root.ex; height: 10
          thumbW: 22
          active: root.snap || (player.seekable && player.duration > 0)
          value: root.durMs > 0 ? root.posMs / root.durMs : 0
          onMoved: v => root.flash("SEEK TO " + root.fmt(v * player.duration) + " / " + root.fmt(player.duration) + " (" + Math.round(v * 100) + "%)")
          onReleased: v => { player.position = v * player.duration; root.flashText = "" }
        }

        // ---- transport ----
        Row {
          x: 9; y: 84
          spacing: 0
          Btn { icon: "prev"; onClicked: root.prev() }
          Btn { icon: "play"; onClicked: root.play() }
          Btn { icon: "pause"; onClicked: root.pause() }
          Btn { icon: "stop"; onClicked: root.stop() }
          Btn { icon: "next"; onClicked: root.next() }
        }
        Btn { x: 130; y: 85; width: 22; height: 16; icon: "eject"; onClicked: openDialog.open() }
        Btn { x: 158 + root.ex; y: 86; width: 46; height: 14; label: "SHUFFLE"; checkable: true; checked: root.shuffle; onClicked: root.shuffle = checked }
        Btn { x: 206 + root.ex; y: 86; width: 34; height: 14; label: "REPEAT"; labelSize: 4.6; led: true; ledText: root.repeatMode === 1 ? "1" : ""; checked: root.repeatMode > 0; onClicked: root.cycleRepeat() }

        // badge: music note, opens the skin picker
        Bevel {
          x: 246 + root.ex; y: 85; width: 20; height: 16
          sunken: true
          fill: Skin.s.badgeBg
          Shape {
            anchors.centerIn: parent
            width: 8; height: 12.2
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeWidth: -1
              fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: 12
                GradientStop { position: 0; color: Skin.s.badgeTop }
                GradientStop { position: 1; color: Skin.s.badgeBottom }
              }
              PathSvg { path: "M 4.4 0 L 5.4 0 C 5.8 2.2 8.2 3 7.8 6.4 C 7.3 4.6 6.4 3.9 5.4 3.6 L 5.4 10 C 5.4 11.4 4 12.2 2.6 12.2 C 1.1 12.2 0 11.4 0 10.4 C 0 9.2 1.3 8.4 2.7 8.4 C 3.4 8.4 4 8.6 4.4 8.9 Z" }
            }
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.skinPicker = !root.skinPicker
            onContainsMouseChanged: if (containsMouse) root.flash("SKINS: " + Skin.s.name.toUpperCase() + "  (CLICK OR PRESS K)")
          }
        }

        Lbl {
          x: 9; y: 105
          text: root.tracksStatus
          color: Skin.s.labelDim
          font.pointSize: 3.45
        }
      }

      // ================= playlist =================
      Item {
        id: pl
        y: 116
        width: root.pw
        height: root.plHeight
        visible: root.showPlaylist

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop { position: 0; color: Skin.s.plTop }
            GradientStop { position: 1; color: Skin.s.plBottom }
          }
        }
        SkinPicture { panelY: 116 }
        Bevel { anchors.fill: parent; fill: "transparent"; light: Skin.s.bevelLight; dark: Skin.s.bevelDark }

        TitleBar {
          x: 1; y: 1; width: root.pw - 2
          title: "P L A Y L I S T"
          lit: false
          onDragStarted: win.startSystemMove()
          Btn { icon: "close"; width: 9; height: 9; onClicked: root.showPlaylist = false }
        }

        Bevel {
          id: listBox
          x: 6; y: 18; width: 263 + root.ex; height: pl.height - 18 - 22
          sunken: true
          fill: Skin.s.lcdBg

          ListView {
            id: list
            x: 2; y: 2
            width: parent.width - 12
            height: parent.height - 4
            clip: true
            model: view
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            property int anchorRow: -1
            delegate: Item {
              id: row
              required property int index
              required property string kind
              required property int ti
              required property int n
              required property string dir
              required property string label
              required property int count
              required property int gdur
              required property bool open
              required property bool dsel
              readonly property bool isDir: kind === "dir"
              readonly property var t: ti >= 0 && ti < tracks.count ? tracks.get(ti) : null
              readonly property bool sel: isDir ? dsel : (t ? t.sel : false)
              readonly property bool isCur: root.current >= 0 && (isDir ? root.curDir === dir : ti === root.current)
              width: list.width
              height: 8.6
              Rectangle { anchors.fill: parent; color: row.sel ? Skin.s.selBg : "transparent" }
              Text {
                textFormat: Text.PlainText
                id: num
                x: root.grouped && !row.isDir ? 7 : 1
                width: parent.width - durTxt.width - x - 5
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.isDir ? (row.open ? "\u25BE " : "\u25B8 ") + row.label + "  (" + row.count + ")"
                      : row.t ? row.n + ". " + (row.t.artist ? row.t.artist + " - " : "") + row.t.title : ""
                color: row.isCur ? Skin.s.lcdAccent : Skin.s.lcdText
                font.family: Skin.s.lcdFont; font.pointSize: 4.725; font.bold: row.isDir || row.isCur
              }
              Text {
                textFormat: Text.PlainText
                id: durTxt
                anchors.right: parent.right; anchors.rightMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                readonly property int ms: row.isDir ? row.gdur : (row.t ? row.t.dur : 0)
                text: ms > 0 ? root.fmt(ms) : ""
                color: num.color
                font: num.font
              }
              MouseArea {
                anchors.fill: parent
                onClicked: m => {
                  if (m.modifiers & Qt.ControlModifier) {
                    const on = !row.sel, w = Object.assign({}, root.selSet)
                    for (const k of root.rowTracks(row.index)) { if (on) w[k] = true; else delete w[k] }
                    root.setSel(w)
                    if (row.isDir) view.setProperty(row.index, "dsel", on)
                  } else if ((m.modifiers & Qt.ShiftModifier) && list.anchorRow >= 0) {
                    const a = Math.min(list.anchorRow, row.index), b = Math.max(list.anchorRow, row.index)
                    const rs = []; for (let r = a; r <= b; r++) rs.push(r)
                    root.selectRows(rs)
                  } else {
                    root.selectRows([row.index])
                    if (row.isDir) root.toggleDir(row.index)
                  }
                  if (!(m.modifiers & Qt.ShiftModifier)) list.anchorRow = row.index
                  stage.forceActiveFocus()
                }
                onDoubleClicked: root.playIndex(row.ti)
              }
            }
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              visible: tracks.count === 0
              horizontalAlignment: Text.AlignHCenter
              text: "drag & drop music here\nor use +FILE / +DIR / +URL below\n\nnetwork share? mount it, then +DIR"
              color: Skin.s.lcdHint
              font.family: Skin.s.lcdFont; font.pointSize: 4.5; font.bold: true
              lineHeight: 1.2
            }
          }

          // scrollbar
          Item {
            x: parent.width - 9; y: 2; width: 7; height: parent.height - 4
            visible: list.contentHeight > list.height
            Rectangle { anchors.fill: parent; color: Skin.s.visBg }
            Rectangle {
              width: parent.width
              height: Math.max(10, parent.height * list.height / Math.max(1, list.contentHeight))
              y: (parent.height - height) * (list.contentY / Math.max(1, list.contentHeight - list.height))
              color: sb.pressed ? Skin.s.thumbActiveTop : Skin.s.thumbBottom
              border.color: Skin.s.btnEdge; border.width: 0.5
            }
            MouseArea {
              id: sb
              anchors.fill: parent
              function go(my) { list.contentY = Math.max(0, Math.min(1, my / height)) * Math.max(0, list.contentHeight - list.height) }
              onPressed: m => go(m.y)
              onPositionChanged: m => go(m.y)
            }
          }
        }

        // footer buttons
        Row {
          x: 6; y: pl.height - 17
          spacing: 2
          visible: !urlBox.visible
          Btn { width: 30; height: 12; label: "+FILE"; labelSize: 5; onClicked: openDialog.open() }
          Btn { width: 28; height: 12; label: "+DIR"; labelSize: 5; onClicked: dirDialog.open() }
          Btn { width: 28; height: 12; label: "+URL"; labelSize: 5; onClicked: { urlBox.visible = true; urlInput.text = ""; urlInput.forceActiveFocus() } }
          Btn { width: 26; height: 12; label: "REM"; labelSize: 5; onClicked: root.removeSelected() }
          Btn { width: 26; height: 12; label: "CLR"; labelSize: 5; onClicked: root.clearList() }
        }

        // URL entry (http streams / files on a home server)
        Bevel {
          id: urlBox
          visible: false
          x: 6; y: pl.height - 17; width: 180; height: 12
          sunken: true
          fill: Skin.s.lcdBg
          TextInput {
            id: urlInput
            x: 2; width: parent.width - 4
            anchors.verticalCenter: parent.verticalCenter
            color: Skin.s.lcdText
            selectionColor: Skin.s.selBg
            font.family: Skin.s.lcdFont; font.pointSize: 4.5; font.bold: true
            clip: true
            Text {
              textFormat: Text.PlainText
              visible: !urlInput.text
              text: "http://server/song.mp3 or a path  [enter]"
              color: Skin.s.lcdHint
              font: urlInput.font
            }
            function submit() { if (text.trim()) root.addPaths([text.trim()], !root.playing && !root.paused); urlBox.visible = false; stage.forceActiveFocus() }
            Keys.onReturnPressed: submit()
            Keys.onEnterPressed: submit()
            Keys.onEscapePressed: { urlBox.visible = false; stage.forceActiveFocus() }
          }
        }

        Bevel {
          x: 190 + root.ex; y: pl.height - 17; width: 72; height: 12
          sunken: true
          fill: Skin.s.lcdBg
          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: (root.track ? root.fmt(root.posMs) : "0:00") + " / " + root.fmt(root.totalTime)
            color: Skin.s.lcdText
            font.family: Skin.s.lcdFont; font.pointSize: 4.5; font.bold: true
          }
        }
      }

      // ================= resize grip (bottom-right corner) =================
      Item {
        x: root.pw - 10
        y: root.contentH - 10
        width: 9
        height: 9
        z: 5
        Repeater {
          model: 3
          Rectangle {
            required property int index
            x: 8 - (index + 1) * 2.6
            y: 8.2
            width: (index + 1) * 2.6 * 1.414
            height: 0.8
            rotation: -45
            transformOrigin: Item.Left
            color: grip.pressed || grip.containsMouse ? Skin.s.lcdText : Skin.s.label
            opacity: 0.8
          }
        }
        MouseArea {
          id: grip
          anchors.fill: parent
          anchors.margins: -2
          hoverEnabled: true
          cursorShape: Qt.SizeFDiagCursor
          property real startU: 1
          property point start
          function scenePos(m) { return mapToItem(null, m.x, m.y) }
          onPressed: m => { startU = root.u; start = scenePos(m) }
          onPositionChanged: m => {
            if (!pressed) return
            const p = scenePos(m)
            const byW = (275 * startU + (p.x - start.x)) / 275
            const byH = (root.contentH * startU + (p.y - start.y)) / root.contentH
            root.setScale(Math.max(byW, byH))
          }
        }
      }

      // ================= skin picker (covers the whole player) =================
      Item {
        id: picker
        visible: root.skinPicker
        onVisibleChanged: if (visible) skinNote.text = Skin.s.name + ": " + (Skin.s.note || "")
        width: root.pw
        height: root.contentH
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop { position: 0; color: Skin.s.chromeTop }
            GradientStop { position: 1; color: Skin.s.plBottom }
          }
        }
        SkinPicture { panelY: 0 }
        Bevel { anchors.fill: parent; fill: "transparent"; radius: 0; light: Skin.s.bevelLight; dark: Skin.s.bevelDark }
        TitleBar {
          x: 1; y: 1; width: root.pw - 2
          title: "S K I N S"
          onDragStarted: win.startSystemMove()
          onRightClicked: root.skinPicker = false
          Btn { icon: "close"; width: 9; height: 9; onClicked: root.skinPicker = false }
        }
        // snapshot previews of the real player in each skin (skins/snap/<id>.jpg, made by skins/snap.sh);
        // main player only (playlist closed); 2 columns (more when wide), scrolls
        GridView {
          id: skinGrid
          x: 6; y: 17
          width: 263 + root.ex; height: picker.height - 17 - 13
          readonly property int cols: Math.max(2, Math.floor(width / 130))
          cellWidth: width / cols
          cellHeight: (cellWidth - 5) * 116 / 275 + 12
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: Skin.pack
          Connections {
            target: picker
            function onVisibleChanged() { if (picker.visible) skinGrid.positionViewAtIndex(Math.max(0, root.skinIndex), GridView.Contain) }
          }
          delegate: Item {
            id: cell
            required property var modelData
            readonly property var sk: Skin.merged(modelData)
            readonly property bool cur: Skin.name === modelData.id
            width: skinGrid.cellWidth - 2
            height: skinGrid.cellHeight - 2
            Bevel {
              anchors.fill: parent
              sunken: true
              fill: cell.cur || cm.containsMouse ? Skin.s.selBg : Skin.s.lcdBg
              opacity: cm.containsMouse && !cell.cur ? 0.85 : 1
            }
            Rectangle {
              id: shot
              x: 1.5; y: 1.5
              width: parent.width - 3; height: width * 116 / 275
              clip: true
              border.width: cell.cur ? 1 : 0
              border.color: Skin.s.lcdAccent
              // fallback while there is no snapshot for this skin
              gradient: Gradient {
                GradientStop { position: 0; color: cell.sk.chromeTop }
                GradientStop { position: 1; color: cell.sk.plBottom }
              }
              Image {
                anchors.fill: parent
                anchors.margins: cell.cur ? 1 : 0
                source: Qt.resolvedUrl("skins/snap/" + cell.modelData.id + ".jpg")
                sourceSize.width: 640
                fillMode: Image.PreserveAspectCrop
                verticalAlignment: Image.AlignTop
                asynchronous: true
                cache: false
                smooth: true; mipmap: true
              }
            }
            Text {
              textFormat: Text.PlainText
              x: 2; y: shot.y + shot.height + 1.2
              width: parent.width - 4
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: cell.modelData.name
              color: cell.cur ? Skin.s.lcdAccent : Skin.s.lcdText
              font.family: Skin.s.lcdFont; font.pointSize: 4; font.bold: true
            }
            MouseArea {
              id: cm
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Skin.select(cell.modelData.id)
              onDoubleClicked: root.skinPicker = false
              onContainsMouseChanged: if (containsMouse) skinNote.text = cell.modelData.name + ": " + (cell.modelData.note || "")
            }
          }
        }
        Btn {
          x: root.pw - 6 - 58; y: picker.height - 12.5
          width: 58; height: 10
          label: "\u25C0 \u25B6  PREVIEW"; labelSize: 4.2
          onClicked: root.startBrowse()
        }
        Text {
          textFormat: Text.PlainText
          id: skinNote
          x: 8; y: picker.height - 10.5
          width: root.pw - 77
          elide: Text.ElideRight
          text: Skin.s.name + ": " + (Skin.s.note || "")
          color: Skin.s.label
          font.family: Skin.s.font; font.pointSize: 3.3; font.bold: true
        }
      }

      // ================= skin browse bar (bottom of the player) =================
      Item {
        id: browseBar
        visible: root.skinBrowse
        z: 6
        x: 4
        width: 267 + root.ex
        height: 15
        y: root.showPlaylist ? root.contentH - 19 : 101
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        WheelHandler {
          acceptedModifiers: Qt.NoModifier
          onWheel: ev => Skin.cycle(ev.angleDelta.y > 0 ? -1 : 1)
        }
        Rectangle {
          anchors.fill: parent
          radius: Math.min(Skin.s.radius, 4)
          gradient: Gradient {
            GradientStop { position: 0; color: Skin.s.chromeTop }
            GradientStop { position: 1; color: Skin.s.plTop }
          }
        }
        Bevel {
          anchors.fill: parent
          fill: "transparent"
          light: Skin.s.bevelLight; dark: Skin.s.bevelDark
          radius: Math.min(Skin.s.radius, 4)
        }
        Btn { x: 2; y: 2; width: 14; height: 11; icon: "left"; onClicked: Skin.cycle(-1) }
        Btn { x: 17; y: 2; width: 14; height: 11; icon: "right"; onClicked: Skin.cycle(1) }
        Bevel {
          x: 33; y: 2; width: 70; height: 11
          sunken: true
          fill: Skin.s.lcdBg
          Text {
            textFormat: Text.PlainText
            x: 2; width: parent.width - 4
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: Skin.s.name.toUpperCase() + "  " + (root.skinIndex + 1) + "/" + Skin.pack.length
            color: Skin.s.lcdText
            font.family: Skin.s.lcdFont; font.pointSize: 3.9; font.bold: true
          }
        }
        HSlider {
          x: 106; y: 2.5; width: 106 + root.ex; height: 10
          thumbW: 8
          value: Skin.pack.length > 1 ? root.skinIndex / (Skin.pack.length - 1) : 0
          onMoved: v => root.browseTo(Math.round(v * (Skin.pack.length - 1)))
        }
        Btn { x: 215 + root.ex; y: 2; width: 30; height: 11; label: "KEEP"; labelSize: 4.4; onClicked: root.endBrowse(true) }
        Btn { x: 247 + root.ex; y: 2; width: 18; height: 11; icon: "close"; onClicked: root.endBrowse(false) }
      }
    }
  }

  property real totalTime: 0
  readonly property string tracksStatus: tracks.count + (tracks.count === 1 ? " track" : " tracks")
                                         + (shuffle ? " · shuffle" : "") + (repeatMode === 2 ? " · repeat" : repeatMode === 1 ? " · repeat song" : "")
  Connections {
    target: tracks
    function onCountChanged() { if (!viewTimer.running) viewTimer.start() }
  }
}
