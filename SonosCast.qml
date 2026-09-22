import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "user.sonos-cast"
  ipcTarget: "user.sonos-cast"

  readonly property string cli: Quickshell.env("HOME") + "/.config/omarchy/plugins/user.sonos-cast/sonos-cast"

  property bool casting: false
  property bool connected: false
  property bool buffered: false
  property string room: "Sonos"
  property string transportState: ""
  property int volume: 0
  property bool muted: false
  property bool reachable: true
  property string statusText: ""
  property bool busy: false

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function run(args, label) {
    if (cmdProc.running) return
    busy = true
    statusText = label || ""
    cmdProc.command = [cli].concat(args)
    cmdProc.running = true
  }

  function setVolume(v) {
    var n = Math.max(0, Math.min(100, Math.round(v)))
    root.volume = n
    run(["volume", String(n)])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  Process {
    id: statusProc
    command: [root.cli, "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.casting = !!d.casting
          root.connected = !!d.connected
          root.buffered = !!d.buffered
          root.room = d.room || root.room
          root.transportState = d.state || ""
          root.reachable = d.state !== "UNREACHABLE"
          if (d.volume !== null && d.volume !== undefined) root.volume = Number(d.volume)
          if (d.muted !== null && d.muted !== undefined) root.muted = !!d.muted
        } catch (e) {
          root.reachable = false
        }
      }
    }
  }

  Process {
    id: cmdProc
    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") root.statusText = text.trim().split("\n")[0]
    }
    onExited: function(code) {
      root.busy = false
      if (code === 0 && root.statusText.indexOf("Sonos cannot") < 0) root.statusText = ""
      root.refresh()
    }
  }

  // Poll while the panel is open, and slowly in the background so the icon
  // reflects casting started from the keyboard or the CLI.
  Timer {
    interval: root.opened ? 2000 : 15000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "S"
    dimmed: !root.casting
    tooltipText: root.casting
      ? ("Casting to " + root.room + (root.connected ? "" : " (connecting…)") + "\nVolume " + root.volume + "%\nLeft click: panel · Middle click: stop")
      : ("Sonos: " + root.room + "\nLeft click: panel · Middle click: start casting")
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.toggle()
      else if (mouseButton === Qt.MiddleButton) root.run(["toggle"], root.casting ? "Stopping…" : "Starting…")
    }
    onWheelMoved: function(delta) {
      if (!root.casting) return
      root.setVolume(root.volume + (delta > 0 ? 2 : -2))
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: true
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.fittedContentHeight(content.implicitHeight + Style.space(24), Style.space(400))

    Column {
      id: content
      width: parent.width
      spacing: Style.space(12)

      Text {
        text: "Sonos Cast"
        color: root.barForeground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Toggle {
        width: parent.width
        label: "Cast to " + root.room
        description: root.casting
          ? (root.connected ? "Speaker connected · " + root.transportState : "Waiting for speaker to connect…")
          : (root.reachable ? "Send all audio from this machine to the speaker" : "Speaker unreachable")
        checked: root.casting
        foreground: root.barForeground
        onClicked: root.run(["toggle"], root.casting ? "Stopping…" : "Starting…")
      }

      PanelSeparator { width: parent.width }

      Toggle {
        width: parent.width
        label: "Buffer audio"
        description: "Smooths skipping; adds about 1 s of delay. Switching briefly reconnects casting."
        checked: root.buffered
        enabled: !root.busy
        foreground: root.barForeground
        onClicked: root.run(["buffer-toggle"], "Switching buffer…")
      }

      Column {
        width: parent.width
        spacing: Style.space(4)
        opacity: root.reachable ? 1 : 0.4

        Item {
          width: parent.width
          implicitHeight: Math.max(volTitle.implicitHeight, volValue.implicitHeight)
          Text {
            id: volTitle
            text: "Speaker volume"
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            id: volValue
            text: (root.muted ? "Muted · " : "") + Math.round(volSlider.dragging ? volSlider.liveValue : root.volume) + "%"
            color: Qt.darker(root.barForeground, 1.35)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        CursorSurface {
          width: parent.width
          height: volSlider.implicitHeight + Style.spacing.controlGap
          foreground: root.barForeground
          hasCursor: volHover.hovered

          PanelSlider {
            id: volSlider
            bar: root.bar
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            minimum: 0
            maximum: 100
            step: 1
            integer: true
            tickCount: 5
            value: root.volume
            onReleased: function(value) { root.setVolume(value) }
            onRightClicked: root.run(["mute-toggle"])
          }
          HoverHandler { id: volHover }
        }
      }

      Toggle {
        width: parent.width
        label: "Mute speaker"
        checked: root.muted
        foreground: root.barForeground
        onClicked: root.run(["mute-toggle"])
      }

      Text {
        visible: root.statusText !== ""
        width: parent.width
        text: root.statusText
        color: Qt.darker(root.barForeground, 1.25)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Text {
        width: parent.width
        text: "Volume keys move the speaker while casting. Expect roughly 1–2 s of delay: the Play:1 buffers HTTP audio."
        color: Qt.darker(root.barForeground, 1.5)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
