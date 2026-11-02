import QtQuick

// Panel with an edge: a 3D bevel (light top-left / dark bottom-right) when
// the skin has bevel=true and square corners, otherwise a flat border.
Item {
  id: bv
  property bool sunken: false
  property color fill: "#000000"
  property real radius: Skin.s.radius
  property color light: Skin.s.bevelLight
  property color dark: Skin.s.bevelDark
  readonly property bool lines: bv.radius <= 0 && Skin.s.bevel

  Rectangle {
    anchors.fill: parent
    radius: bv.radius
    color: bv.fill
    border.width: bv.lines ? 0 : 1
    border.color: bv.sunken ? bv.dark : bv.light
  }
  // inner highlight so rounded bevelled panels still read as 3D
  Rectangle {
    visible: !bv.lines && Skin.s.bevel && bv.radius > 0 && !bv.sunken
    x: bv.radius; y: 1
    width: Math.max(0, bv.width - 2 * bv.radius); height: 0.8
    color: bv.sunken ? bv.light : Qt.lighter(bv.light, 1.2)
    opacity: 0.6
  }
  Item {
    visible: bv.lines
    anchors.fill: parent
    Rectangle { width: parent.width; height: 1; color: bv.sunken ? bv.dark : bv.light }
    Rectangle { width: 1; height: parent.height; color: bv.sunken ? bv.dark : bv.light }
    Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: bv.sunken ? bv.light : bv.dark }
    Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: bv.sunken ? bv.light : bv.dark }
  }
}
