import QtQuick

// One 7-segment LCD digit (9 x 13 units). Unlit segments glow faintly.
Item {
  id: d
  property string ch: " "
  property color on: Skin.s.lcdText
  property color off: Skin.s.lcdDim
  width: 9
  height: 13
  readonly property real rr: Skin.s.radius > 2 ? 0.7 : 0
  readonly property var map: ({
    "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
    "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
    "-": "g", " ": ""
  })
  function seg(n) { return (map[ch] || "").indexOf(n) >= 0 ? on : off }
  Rectangle { radius: d.rr; x: 1.6; y: 0;    width: 5.8; height: 1.4; color: d.seg("a") }
  Rectangle { radius: d.rr; x: 7.6; y: 1.5;  width: 1.4; height: 4.6; color: d.seg("b") }
  Rectangle { radius: d.rr; x: 7.6; y: 6.9;  width: 1.4; height: 4.6; color: d.seg("c") }
  Rectangle { radius: d.rr; x: 1.6; y: 11.6; width: 5.8; height: 1.4; color: d.seg("d") }
  Rectangle { radius: d.rr; x: 0;   y: 6.9;  width: 1.4; height: 4.6; color: d.seg("e") }
  Rectangle { radius: d.rr; x: 0;   y: 1.5;  width: 1.4; height: 4.6; color: d.seg("f") }
  Rectangle { radius: d.rr; x: 1.6; y: 5.8;  width: 5.8; height: 1.4; color: d.seg("g") }
}
