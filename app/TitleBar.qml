import QtQuick

// Title bar; its decoration comes from the skin's `stripes` style
// (pin | solid | dots | grille | none). Drag moves the window.
Item {
  id: t
  property string title: ""
  property bool lit: true
  property bool showLogo: false
  property bool xMark: false
  property string markImage: "assets/logo.svg"   // the gold letter drawn in place of the first title letter
  property real markAspect: 1
  property string wordmark: ""   // an image used as the whole title (sWAMP logo)
  property real wordmarkAspect: 200 / 72
  property bool prefixLikeAmp: false   // true: prefix uses AMP's exact size and baseline
  property string xPrefix: ""   // letters before the X (e.g. "he"), styled like AMP but X-sized
  signal dragStarted()
  signal doubleClicked()
  signal rightClicked()
  height: 14
  default property alias buttons: btnRow.data

  readonly property color ca: t.lit ? Skin.s.stripeA : Skin.s.stripeDim
  readonly property color cb: t.lit ? Skin.s.stripeB : Skin.s.stripeDim
  readonly property string style: Skin.s.stripes
  // the two decorated spans, left and right of the label
  readonly property var spans: [
    { x: t.showLogo ? 18 : 6, w: Math.max(0, label.x - (t.showLogo ? 22 : 10)) },
    { x: label.x + label.width + 4, w: Math.max(0, btnRow.x - (label.x + label.width + 4) - 5) }
  ]

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: Skin.s.titleTop }
      GradientStop { position: 1; color: Skin.s.titleBottom }
    }
  }
  Rectangle { width: parent.width; height: 1; color: Skin.s.bevelLight; opacity: Skin.s.bevel ? 1 : 0.5 }
  Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: Skin.s.bevelDark }

  Repeater {
    model: t.spans
    Item {
      required property var modelData
      x: modelData.x
      width: modelData.w
      height: t.height
      clip: true

      // pin: four thin alternating lines
      Repeater {
        model: t.style === "pin" ? 4 : 0
        Rectangle { required property int index; y: 3.5 + index * 2; width: parent.width; height: 0.8; color: index % 2 ? t.cb : t.ca }
      }
      // solid: one bar with an underline
      Rectangle { visible: t.style === "solid"; y: 4.5; width: parent.width; height: 3.2; radius: Skin.s.radius > 0 ? 1.6 : 0; color: t.ca }
      Rectangle { visible: t.style === "solid"; y: 8.6; width: parent.width; height: 0.7; color: t.cb }
      // dots: two rows of speaker-grille dots
      Repeater {
        model: t.style === "dots" ? Math.floor(parent.width / 2.4) * 2 : 0
        Rectangle {
          required property int index
          x: Math.floor(index / 2) * 2.4 + (index % 2) * 1.2
          y: 4.6 + (index % 2) * 2.4
          width: 1.2; height: 1.2; radius: 0.6
          color: index % 2 ? t.cb : t.ca
        }
      }
      // grille: short vertical vent ticks
      Repeater {
        model: t.style === "grille" ? Math.floor(parent.width / 2) : 0
        Rectangle {
          required property int index
          x: index * 2
          y: 3.5
          width: 0.9; height: 7
          color: index % 4 === 0 ? t.ca : t.cb
        }
      }
    }
  }

  Image {
    visible: t.showLogo
    x: 4
    y: 1.2
    width: 11.6
    height: 11.6
    source: "assets/logo.svg"
    sourceSize: Qt.size(96, 96)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
  }

  // title; with `xMark` the first letter is drawn as the gold X logo
  Row {
    id: label
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: -8
    spacing: t.xMark ? 0.6 : 0
    height: amp.height
    // exact glyph box of the capitals, so the X matches their top and baseline
    // glyph box of the capitals, measured at 20x size (small sizes round to whole units)
    TextMetrics {
      id: caps
      font.family: amp.font.family; font.bold: true; font.pointSize: amp.font.pointSize * 20
      text: "AMP"
    }
    readonly property real capH: caps.tightBoundingRect.height / 20
    readonly property real capTop: amp.baselineOffset + caps.tightBoundingRect.y / 20
    // prefix ("s", "he"): its letters are as tall as the gold mark, tops line up
    TextMetrics {
      id: preRef
      font.family: amp.font.family; font.bold: true; font.pointSize: amp.font.pointSize * 20
      text: t.xPrefix || "h"
    }
    TextMetrics {
      id: preOwn
      font.family: amp.font.family; font.bold: true; font.pointSize: pre.font.pointSize * 20
      text: t.xPrefix || "h"
    }
    Text {
      id: pre
      visible: t.xMark && t.xPrefix !== ""
      text: t.xPrefix
      // the X's drawn height minus the outline the text adds on top and bottom
      readonly property real glyphH: Math.max(1, xImg.height * 0.94 - 1.5)
      y: t.prefixLikeAmp ? amp.y : label.capTop - (baselineOffset + preOwn.tightBoundingRect.y / 20) - 0.5
      // letterSpacing also pads after the last letter; trim it so the gap to the X matches X-to-AMP
      width: implicitWidth - font.letterSpacing - (t.prefixLikeAmp ? 0 : 0.9)   // the glyph's own right-side bearing too
      color: "#0d0d0d"
      style: Text.Outline
      styleColor: "#d9e0ad12"
      font.family: amp.font.family
      font.pointSize: t.prefixLikeAmp ? amp.font.pointSize : preRef.tightBoundingRect.height > 0 ? amp.font.pointSize * glyphH / (preRef.tightBoundingRect.height / 20) : amp.font.pointSize
      font.bold: true
      font.letterSpacing: 1.2
    }
    Image {
      visible: t.wordmark !== ""
      height: visible ? 11.5 : 0
      width: visible ? height * t.wordmarkAspect : 0
      y: (amp.height - height) / 2
      source: t.wordmark
      sourceSize: Qt.size(800, 288)
      smooth: true; mipmap: true
    }
    Image {
      id: xImg
      visible: t.xMark
      // 10% smaller than the X that matched AMP's capitals before AMP grew 10%;
      // top lines up with the top of the outlined capitals
      // previous X = old capital height + outline (~7.9 units as drawn); now 90% of that
      height: 0.9 * (label.capH / 1.1 + 1.9)
      width: height * t.markAspect
      // the gold outline reaches ~0.75 above the glyphs; the X art has ~3% top padding
      y: label.capTop - 0.75 - 0.03 * height
      source: t.markImage
      sourceSize: Qt.size(96 * t.markAspect, 96)
      smooth: true; mipmap: true
    }
    Text {
      id: amp
      text: t.xMark ? t.title.replace(/^\S\s*/, "").replace(/ /g, "") : t.title
      // picture skins: full-strength title with a dark outline so it reads over any scene
      readonly property bool onPicture: Skin.s.bgImage !== ""
      color: t.xMark ? "#0d0d0d" : (t.lit || onPicture ? Skin.s.titleText : Skin.s.titleTextDim)
      // black letters with a gold outline
      style: t.xMark || onPicture ? Text.Outline : Text.Normal
      styleColor: t.xMark ? "#d9e0ad12" : "#c0000000"
      font.family: Skin.s.font
      font.pointSize: t.xMark ? 6.82 : 4.875
      font.bold: true
      font.letterSpacing: t.xMark ? 1.2 : Skin.s.titleSpacing
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: m => { if (m.button === Qt.LeftButton) t.dragStarted(); else t.rightClicked() }
    onDoubleClicked: m => { if (m.button === Qt.LeftButton) t.doubleClicked() }
  }

  Row {
    id: btnRow
    anchors.right: parent.right
    anchors.rightMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1.5
  }
}
