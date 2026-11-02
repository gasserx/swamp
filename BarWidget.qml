import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar button for the sWamp player: gold "sWAMP" wordmark, now-playing tooltip.
// Click = open / bring here / minimize (see bin/swamp).
BarWidget {
  id: root

  readonly property string launcher: decodeURIComponent(Qt.resolvedUrl("bin/swamp").toString().replace("file://", ""))
  property string playState: "off"
  property string nowPlaying: ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    tooltipText: root.playState === "playing" ? "▶ " + root.nowPlaying
               : root.playState === "paused" ? "⏸ " + root.nowPlaying
               : root.playState === "off" ? "sWamp: click to open" : "sWamp (stopped)"

    // the wordmark is wide (204:74), so this button gets a wider slot than a plain icon
    readonly property real markAspect: 204 / 74
    slotSize: Style.bar.iconCanvas * markAspect + (Style.bar.iconSlot - Style.bar.iconCanvas)

    iconComponent: Component {
      Item {
        Image {
          anchors.centerIn: parent
          height: parent.height
          width: height * button.markAspect
          source: Qt.resolvedUrl("app/assets/bar-icon.png")
          sourceSize: Qt.size(width * 3, height * 3)
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
          opacity: root.playState === "off" ? 0.8 : 1
        }
      }
    }

    onPressed: function(b) { Quickshell.execDetached([root.launcher]) }
  }

  Process {
    id: poll
    command: ["bash", "-c", "timeout 2 \"$0\" ipc status 2>/dev/null || echo off", root.launcher]
    stdout: SplitParser {
      onRead: line => {
        const parts = line.split("\t")
        root.playState = parts[0] || "off"
        root.nowPlaying = parts[1] || ""
      }
    }
  }
  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!poll.running) poll.running = true
  }
}
