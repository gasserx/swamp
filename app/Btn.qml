import QtQuick
import QtQuick.Shapes

// Skinned push button with a vector glyph or a small text label.
// Checkable buttons get a little LED.
Item {
  id: b
  property string icon: ""
  property string label: ""
  property bool checkable: false
  property bool checked: false
  property bool led: checkable          // show the LED (for buttons that handle clicks themselves)
  property string ledText: ""         // a lit character in place of the LED dot (e.g. repeat "1")
  property real labelSize: 5.2
  signal clicked()
  width: 23
  height: 18

  readonly property bool down: ma.pressed && ma.containsMouse
  readonly property real r: Math.min(Skin.s.radius, height / 2)
  readonly property bool lines: r <= 0 && Skin.s.bevel
  readonly property var paths: ({
    "play":  "M 2 0 L 9 4 L 2 8 Z",
    "pause": "M 2 0 L 4 0 L 4 8 L 2 8 Z M 6 0 L 8 0 L 8 8 L 6 8 Z",
    "stop":  "M 1.5 0.5 L 8.5 0.5 L 8.5 7.5 L 1.5 7.5 Z",
    "prev":  "M 0.5 0 L 2 0 L 2 8 L 0.5 8 Z M 6 0 L 2 4 L 6 8 Z M 10 0 L 6 4 L 10 8 Z",
    "next":  "M 8 0 L 9.5 0 L 9.5 8 L 8 8 Z M 0 0 L 4 4 L 0 8 Z M 4 0 L 8 4 L 4 8 Z",
    "eject": "M 5 0 L 10 5 L 0 5 Z M 0 6.2 L 10 6.2 L 10 8 L 0 8 Z",
    "min":   "M 1 6 L 9 6 L 9 8 L 1 8 Z",
    "close": "M 1 0 L 5 3 L 9 0 L 10 1 L 6 4 L 10 7 L 9 8 L 5 5 L 1 8 L 0 7 L 4 4 L 0 1 Z",
    "max":   "M 1 0 L 9 0 L 9 8 L 1 8 Z M 2.4 2.2 L 7.6 2.2 L 7.6 6.6 L 2.4 6.6 Z",
    "unmax": "M 3 0 L 10 0 L 10 5.6 L 8.6 5.6 L 8.6 1.4 L 3 1.4 Z M 0 2.4 L 7.2 2.4 L 7.2 8 L 0 8 Z M 1.4 4.2 L 5.8 4.2 L 5.8 6.6 L 1.4 6.6 Z",
    "left":  "M 7.5 0 L 2 4 L 7.5 8 Z",
    "right": "M 2.5 0 L 8 4 L 2.5 8 Z"
  })

  Rectangle {
    anchors.fill: parent
    radius: b.r
    border.width: b.lines ? 0 : 1
    border.color: Skin.s.btnEdge
    gradient: Gradient {
      GradientStop { position: 0; color: b.down ? Skin.s.btnDownTop : (ma.containsMouse ? Skin.s.btnHover : Skin.s.btnTop) }
      GradientStop { position: 1; color: b.down ? Skin.s.btnDownBottom : Skin.s.btnBottom }
    }
  }
  Item {
    visible: b.lines
    anchors.fill: parent
    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Skin.s.btnEdge }
    Rectangle { x: 1; y: 1; width: b.width - 2; height: 1; color: b.down ? Skin.s.btnDark : Skin.s.btnLight }
    Rectangle { x: 1; y: 1; width: 1; height: b.height - 2; color: b.down ? Skin.s.btnDark : Skin.s.btnLight }
    Rectangle { x: 1; y: b.height - 2; width: b.width - 2; height: 1; color: b.down ? Skin.s.btnLight : Skin.s.btnDark }
    Rectangle { x: b.width - 2; y: 1; width: 1; height: b.height - 2; color: b.down ? Skin.s.btnLight : Skin.s.btnDark }
  }
  Rectangle {
    visible: !b.lines && Skin.s.bevel
    x: b.r + 0.5; y: 1.2; width: Math.max(0, b.width - 2 * b.r - 1); height: 0.7
    color: b.down ? Skin.s.btnDark : Skin.s.btnLight
    opacity: 0.7
  }

  Shape {
    visible: b.icon !== ""
    width: 10
    height: 8
    x: (b.width - width) / 2 + (b.down ? 0.5 : 0)
    y: (b.height - height) / 2 + (b.down ? 0.5 : 0)
    scale: Math.min(1, (b.height - 6) / 8)
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: -1
      fillColor: Skin.s.btnGlyph
      PathSvg { path: b.paths[b.icon] || "" }
    }
  }

  Text {
    textFormat: Text.PlainText
    visible: b.label !== ""
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: (b.led ? 2.5 : 0) + (b.down ? 0.5 : 0)
    anchors.verticalCenterOffset: b.down ? 0.5 : 0
    text: b.label
    color: Skin.s.btnText
    font.family: Skin.s.font
    font.pointSize: b.labelSize * 0.75
    font.bold: true
    font.letterSpacing: 0.3
  }

  Text {
    textFormat: Text.PlainText
    visible: b.led && b.ledText !== ""
    x: 4.5 - width / 2
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: b.down ? 0.5 : 0
    text: b.ledText
    color: Skin.s.ledOn
    font.family: Skin.s.font
    font.pointSize: 4.6 * 0.75
    font.bold: true
  }
  Rectangle {
    visible: b.led && b.ledText === ""
    x: 3
    width: 3
    height: 3
    y: (b.height - height) / 2
    radius: Skin.s.radius > 0 ? 1.5 : 0.5
    color: b.checked ? Skin.s.ledOn : Skin.s.ledOff
    border.width: 0.4
    border.color: Skin.s.btnEdge
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    onClicked: {
      if (b.checkable) b.checked = !b.checked
      b.clicked()
    }
  }
}
