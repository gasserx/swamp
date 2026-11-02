import QtQuick

// Horizontal slider. Groove style for seeking, level-meter fill for volume.
Item {
  id: s
  property real value: 0
  property bool active: true
  property bool fillStyle: false
  property int thumbW: 14
  readonly property bool dragging: ma.pressed
  property real dragValue: 0
  readonly property real shown: dragging ? dragValue : value
  readonly property real r: Math.min(Skin.s.radius, 3)
  signal moved(real v)
  signal released(real v)
  height: 10

  Bevel {
    x: 0
    y: s.fillStyle ? 1 : s.height / 2 - 2.5
    width: s.width
    height: s.fillStyle ? s.height - 2 : 5
    radius: s.r
    sunken: true
    fill: Skin.s.lcdBg
  }
  Item {
    visible: s.fillStyle
    x: 1
    y: 2
    height: s.height - 4
    width: Math.max(0, (s.width - 2) * s.shown)
    clip: true
    Rectangle {
      width: s.width - 2
      height: parent.height
      radius: Math.max(0, s.r - 1)
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Skin.s.volA }
        GradientStop { position: 0.6; color: Skin.s.volB }
        GradientStop { position: 1.0; color: Skin.s.volC }
      }
    }
  }

  Rectangle {
    visible: s.active
    x: s.shown * (s.width - s.thumbW)
    width: s.thumbW
    height: s.height
    radius: s.r
    border.width: 1
    border.color: Skin.s.btnEdge
    gradient: Gradient {
      GradientStop { position: 0; color: ma.pressed ? Skin.s.thumbActiveTop : Skin.s.thumbTop }
      GradientStop { position: 1; color: ma.pressed ? Skin.s.thumbActiveBottom : Skin.s.thumbBottom }
    }
    Rectangle { x: parent.width / 2 - 0.5; y: 2.5; width: 1; height: parent.height - 5; color: Skin.s.btnEdge; opacity: 0.7 }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    enabled: s.active
    function v(mx) { return Math.max(0, Math.min(1, (mx - s.thumbW / 2) / (s.width - s.thumbW))) }
    onPressed: m => { s.dragValue = v(m.x); s.moved(s.dragValue) }
    onPositionChanged: m => { if (pressed) { s.dragValue = v(m.x); s.moved(s.dragValue) } }
    onReleased: s.released(s.dragValue)
    onWheel: w => {
      const nv = Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.04 : -0.04)))
      s.moved(nv)
      s.released(nv)
    }
  }
}
