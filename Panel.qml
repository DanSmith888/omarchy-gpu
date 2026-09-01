import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// GPU: the panel, and the owner of all state.
//
// Loaded by BarWidget.qml (the manifest entry point), which injects bar,
// anchorItem and hostWidget and forwards open/close/toggle to us. IPC is
// left to the bar widget so the target is registered once.
Panel {
  id: root
  moduleName: "dansmith888.gpu"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")

  // ---- Readings. null means "this driver doesn't report it" and hides the
  // row rather than showing a made-up zero.
  property bool devicePresent: false
  property bool stale: false
  property string vendor: ""
  property string name: ""
  property var driver: null
  property var load: null
  property var memUsedMiB: null
  property var memTotalMiB: null
  property var tempC: null
  property var powerW: null
  property var powerLimitW: null
  property var clockMhz: null
  property var maxClockMhz: null
  property var memClockMhz: null
  property var fanPct: null
  property var pstate: null
  property var processes: null
  property var gpus: []
  property var loadHistory: []

  property var themeColors: ({})
  readonly property var colorChoices: Model.themePalette(root.themeColors)

  // ---- Settings.
  readonly property int pollIntervalMs: Model.clampInt(setting("pollIntervalMs", 2000), 500, 60000, 2000)
  readonly property int gpuIndex: Model.clampInt(setting("gpuIndex", 0), 0, 15, 0)
  readonly property bool showIcon: Model.asBool(setting("showIcon", true), true)
  readonly property bool showLoad: Model.asBool(setting("showLoad", true), true)
  readonly property bool showTemp: Model.asBool(setting("showTemp", true), true)
  readonly property bool showPower: Model.asBool(setting("showPower", false), false)
  readonly property bool showVram: Model.asBool(setting("showVram", false), false)
  readonly property string temperatureUnit: Model.normalizeUnit(setting("temperatureUnit", "C"))
  readonly property int historySamples: Model.clampInt(setting("historySamples", 60), 20, 240, 60)
  // warnFrom/alertFrom were once busyFrom/hotFrom: read the old key as the
  // fallback so an existing bar entry keeps its thresholds and colours, and
  // snap to the stepper's marks (an old 16 lands on 15, not 16).
  readonly property int warnFrom: Model.clampStep(setting("warnFrom", setting("busyFrom", 50)), 5, 100, 5, 50)
  readonly property int alertFrom: Model.clampStep(setting("alertFrom", setting("hotFrom", 85)), 5, 100, 5, 85)
  readonly property string warnColor: String(setting("warnColor", setting("busyColor", "")))
  readonly property string alertColor: String(setting("alertColor", setting("hotColor", "")))
  readonly property int pillWidth: Model.clampInt(setting("pillWidth", 0), 0, 400, 0)
  readonly property int topCount: Model.clampInt(setting("topCount", 5), 1, 10, 5)

  // ---- Derived.
  readonly property string shortModel: Model.shortModel(root.name)
  readonly property string loadText: Model.pct(root.load)
  readonly property string tempText: Model.degrees(root.tempC, root.temperatureUnit)
  readonly property string vramText: Model.mib(root.memUsedMiB) + " / " + Model.mib(root.memTotalMiB)
  readonly property string powerText: root.powerLimitW !== null
    ? Model.watts(root.powerW) + " / " + Model.watts(root.powerLimitW)
    : Model.watts(root.powerW)
  readonly property var memPercent: Model.memPercent(root.memUsedMiB, root.memTotalMiB)
  readonly property var powerPercent: Model.powerPercent(root.powerW, root.powerLimitW)
  readonly property string barText: Model.barText([
    root.showLoad ? Model.pct(root.load) : "",
    root.showTemp && root.tempC !== null ? Model.degreesShort(root.tempC, root.temperatureUnit) : "",
    root.showPower && root.powerW !== null ? Model.wattsShort(root.powerW) : "",
    root.showVram && root.memUsedMiB !== null ? Model.mibShort(root.memUsedMiB) : ""
  ])
  // Same shape as barText but with every field at its widest, so the pill
  // can reserve a stable column and stop shuffling its neighbours every
  // time a reading crosses 9 -> 10 -> 100.
  readonly property string barWidest: Model.barText([
    root.showLoad ? "100%" : "",
    root.showTemp && root.tempC !== null ? "100\u00b0" : "",
    root.showPower && root.powerW !== null ? "999W" : "",
    root.showVram && root.memUsedMiB !== null ? "99.9G" : ""
  ])
  readonly property string tierColor: Model.loadColor(root.load, root.warnFrom, root.alertFrom,
                                                      root.warnColor, root.alertColor)
  readonly property string metaText: {
    var bits = []
    if (root.vendor !== "") bits.push(root.vendor)
    if (root.memTotalMiB !== null) bits.push(Model.mib(root.memTotalMiB))
    if (root.driver) bits.push("driver " + root.driver)
    return bits.join(" · ")
  }
  readonly property var refreshChips: [
    { value: "500", label: "0.5s" },
    { value: "1000", label: "1s" },
    { value: "2000", label: "2s" },
    { value: "3000", label: "3s" },
    { value: "5000", label: "5s" }
  ]
  readonly property var unitChips: [
    { value: "C", label: "°C" },
    { value: "F", label: "°F" }
  ]
  readonly property var historyChips: [
    { value: "30", label: "30" },
    { value: "60", label: "60" },
    { value: "120", label: "120" },
    { value: "240", label: "240" }
  ]
  readonly property var gpuChips: Model.gpuChips(root.gpus)

  function persistSettings(patch) {
    var next = Object.assign({}, root.settings, patch)
    root.settings = next
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = next
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, next)
  }

  function setPollIntervalMs(v) { persistSettings({ pollIntervalMs: Model.clampInt(v, 500, 60000, 2000) }) }
  function setGpuIndex(v) { persistSettings({ gpuIndex: Model.clampInt(v, 0, 15, 0) }) }
  function setShowIcon(v) { persistSettings({ showIcon: !!v }) }
  function setShowLoad(v) { persistSettings({ showLoad: !!v }) }
  function setShowTemp(v) { persistSettings({ showTemp: !!v }) }
  function setShowPower(v) { persistSettings({ showPower: !!v }) }
  function setShowVram(v) { persistSettings({ showVram: !!v }) }
  function setTemperatureUnit(v) { persistSettings({ temperatureUnit: Model.normalizeUnit(v) }) }
  function setHistorySamples(v) { persistSettings({ historySamples: Model.clampInt(v, 20, 240, 60) }) }
  function setWarnFrom(v) { persistSettings({ warnFrom: Model.clampStep(v, 5, 100, 5, 50) }) }
  function setAlertFrom(v) { persistSettings({ alertFrom: Model.clampStep(v, 5, 100, 5, 85) }) }
  function setWarnColor(hex) { persistSettings({ warnColor: String(hex) }) }
  function setAlertColor(hex) { persistSettings({ alertColor: String(hex) }) }

  function refresh() { if (!statusProc.running) statusProc.running = true }
  function refreshThemeColors() { if (!themeProc.running) themeProc.running = true }

  onGpuIndexChanged: refresh()
  // Reopening should always land at the top of the panel, not wherever the
  // last visit left the scroll.
  onOpenedChanged: {
    if (!opened) return
    refresh()
    refreshThemeColors()
    flick.contentY = 0
  }
  Component.onCompleted: refreshThemeColors()

  Process {
    id: statusProc
    command: [root.pluginDir + "bin/gpustatus", String(root.gpuIndex)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = String(this.text).trim()
        if (out === "" || out === "{}") { root.devicePresent = false; return }
        try {
          var d = JSON.parse(out)
          if (d.present !== true) { root.devicePresent = false; return }
          root.devicePresent = true
          root.stale = false
          root.vendor = d.vendor || ""
          root.name = d.name || ""
          root.driver = d.driver !== undefined ? d.driver : null
          root.load = (typeof d.load === "number") ? d.load : null
          root.memUsedMiB = (typeof d.memUsedMiB === "number") ? d.memUsedMiB : null
          root.memTotalMiB = (typeof d.memTotalMiB === "number") ? d.memTotalMiB : null
          root.tempC = (typeof d.tempC === "number") ? d.tempC : null
          root.powerW = (typeof d.powerW === "number") ? d.powerW : null
          root.powerLimitW = (typeof d.powerLimitW === "number") ? d.powerLimitW : null
          root.clockMhz = (typeof d.clockMhz === "number") ? d.clockMhz : null
          root.maxClockMhz = (typeof d.maxClockMhz === "number") ? d.maxClockMhz : null
          root.memClockMhz = (typeof d.memClockMhz === "number") ? d.memClockMhz : null
          root.fanPct = (typeof d.fanPct === "number") ? d.fanPct : null
          root.pstate = d.pstate || null
          root.processes = d.processes || null
          root.gpus = d.gpus || []
          root.loadHistory = Model.pushHistory(root.loadHistory, root.load, root.historySamples)
        } catch (e) {
          // Keep the last good reading rather than blanking the pill.
          root.stale = root.devicePresent
        }
      }
    }
  }

  Process {
    id: themeProc
    command: ["bash", "-lc", "cat ~/.local/state/omarchy/current/theme/colors.toml 2>/dev/null"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.themeColors = Model.parseThemeColors(text)
    }
  }

  // Steady state while closed; the configured cadence, floored, while open.
  Timer {
    interval: root.opened ? root.pollIntervalMs : Math.max(root.pollIntervalMs, 3000)
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: flick
        // No margins here: KeyboardPanel.padding already insets the content,
        // the way the first-party tailscale and agents panels do it.
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: column
          width: flick.width
          spacing: Style.space(12)
          opacity: root.stale ? 0.55 : 1.0

          // ---------- Hero: card mark · model · vendor/VRAM/driver ----------
          PanelHero {
            width: parent.width
            title: root.shortModel
            meta: root.metaText
            detail: root.loadText
            foreground: root.barForeground
            fontFamily: Style.font.family
            iconComponent: Component {
              Text {
                text: "󰢮"
                color: root.tierColor !== "" ? root.tierColor : root.barForeground
                font.family: Style.font.family
                font.pixelSize: Style.font.display
              }
            }
          }

          Sparkline {
            width: parent.width
            height: Style.space(46)
            values: root.loadHistory
            ceiling: 100
            lineColor: root.tierColor !== "" ? root.tierColor : Color.accent
          }

          MeterRow {
            width: parent.width
            visible: root.load !== null
            label: "Load"
            value: root.load === null ? 0 : root.load
            valueText: root.loadText
            fill: root.tierColor !== "" ? root.tierColor : Color.accent
          }

          MeterRow {
            width: parent.width
            visible: root.memPercent !== null
            label: "VRAM"
            value: root.memPercent === null ? 0 : root.memPercent
            valueText: root.vramText
            fill: Color.accent
          }

          MeterRow {
            width: parent.width
            visible: root.powerPercent !== null
            label: "Power"
            value: root.powerPercent === null ? 0 : root.powerPercent
            valueText: root.powerText
            fill: Color.accent
          }

          PanelSeparator { width: parent.width; foreground: root.barForeground }

          // ---------- Sensors ----------
          PanelSectionHeader { text: "SENSORS"; foreground: root.barForeground }

          StatRow {
            width: parent.width
            visible: root.tempC !== null
            label: "Temperature"
            value: root.tempText
          }

          StatRow {
            width: parent.width
            visible: root.fanPct !== null
            label: "Fan"
            value: Model.pct(root.fanPct)
          }

          StatRow {
            width: parent.width
            visible: root.clockMhz !== null
            label: "Core clock"
            value: root.maxClockMhz !== null
              ? Model.mhz(root.clockMhz) + "  of  " + Model.mhz(root.maxClockMhz)
              : Model.mhz(root.clockMhz)
          }

          StatRow {
            width: parent.width
            visible: root.memClockMhz !== null
            label: "Memory clock"
            value: Model.mhz(root.memClockMhz)
          }

          StatRow {
            width: parent.width
            visible: root.pstate !== null
            label: "Performance state"
            value: String(root.pstate)
          }

          PanelSeparator {
            width: parent.width
            foreground: root.barForeground
            visible: root.processes !== null
          }

          // ---------- Clients ----------
          PanelSectionHeader {
            text: "USING THE GPU"
            foreground: root.barForeground
            visible: root.processes !== null
          }

          Text {
            width: parent.width
            visible: root.processes !== null && root.processes.length === 0
            text: "Nothing is holding GPU memory right now."
            color: Qt.darker(root.barForeground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Repeater {
            model: root.processes === null ? [] : root.processes.slice(0, root.topCount)
            delegate: Row {
              id: procRow
              required property var modelData
              width: column.width
              spacing: Style.space(8)

              Text {
                width: procRow.width - procValue.width - procRow.spacing
                text: procRow.modelData.name + "  (" + procRow.modelData.pid + ")"
                color: Qt.darker(root.barForeground, 1.3)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                id: procValue
                text: Model.mib(procRow.modelData.memMiB)
                color: root.barForeground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          PanelSeparator { width: parent.width; foreground: root.barForeground }

          // ---------- Bar pill ----------
          PanelSectionHeader { text: "IN THE BAR"; foreground: root.barForeground }

          Text {
            width: parent.width
            text: "Pick what the pill shows. Everything stays visible in here either way."
            color: Qt.darker(root.barForeground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Toggle {
            width: parent.width
            label: "Card icon"
            description: "󰢮 in front of the readings."
            checked: root.showIcon
            foreground: root.barForeground
            accent: Color.accent
            fontFamily: Style.font.family
            onClicked: root.setShowIcon(!root.showIcon)
          }

          Toggle {
            width: parent.width
            visible: root.load !== null
            label: "Load"
            description: "GPU utilisation as a percentage."
            checked: root.showLoad
            foreground: root.barForeground
            accent: Color.accent
            fontFamily: Style.font.family
            onClicked: root.setShowLoad(!root.showLoad)
          }

          Toggle {
            width: parent.width
            visible: root.tempC !== null
            label: "Temperature"
            description: "Core temperature in whole degrees."
            checked: root.showTemp
            foreground: root.barForeground
            accent: Color.accent
            fontFamily: Style.font.family
            onClicked: root.setShowTemp(!root.showTemp)
          }

          Toggle {
            width: parent.width
            visible: root.powerW !== null
            label: "Power"
            description: "Board power draw in watts."
            checked: root.showPower
            foreground: root.barForeground
            accent: Color.accent
            fontFamily: Style.font.family
            onClicked: root.setShowPower(!root.showPower)
          }

          Toggle {
            width: parent.width
            visible: root.memUsedMiB !== null
            label: "VRAM"
            description: "Video memory in use."
            checked: root.showVram
            foreground: root.barForeground
            accent: Color.accent
            fontFamily: Style.font.family
            onClicked: root.setShowVram(!root.showVram)
          }

          Text {
            width: parent.width
            visible: root.gpus.length > 1
            text: "Card"
            color: Qt.darker(root.barForeground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          ButtonGroup {
            visible: root.gpus.length > 1
            value: String(root.gpuIndex)
            options: root.gpuChips
            foreground: root.barForeground
            background: Color.background
            accent: Color.accent
            fontFamily: Style.font.family
            onChanged: function(value) { root.setGpuIndex(value) }
          }

          Text {
            width: parent.width
            text: "Refresh interval"
            color: Qt.darker(root.barForeground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          ButtonGroup {
            value: String(root.pollIntervalMs)
            options: root.refreshChips
            foreground: root.barForeground
            background: Color.background
            accent: Color.accent
            fontFamily: Style.font.family
            onChanged: function(value) { root.setPollIntervalMs(value) }
          }

          Text {
            width: parent.width
            visible: root.tempC !== null
            text: "Temperature unit"
            color: Qt.darker(root.barForeground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          ButtonGroup {
            visible: root.tempC !== null
            value: root.temperatureUnit
            options: root.unitChips
            foreground: root.barForeground
            background: Color.background
            accent: Color.accent
            fontFamily: Style.font.family
            onChanged: function(value) { root.setTemperatureUnit(value) }
          }

          Text {
            width: parent.width
            text: "Graph history (samples)"
            color: Qt.darker(root.barForeground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          ButtonGroup {
            value: String(root.historySamples)
            options: root.historyChips
            foreground: root.barForeground
            background: Color.background
            accent: Color.accent
            fontFamily: Style.font.family
            onChanged: function(value) { root.setHistorySamples(value) }
          }

          PanelSeparator { width: parent.width; foreground: root.barForeground }

          PanelSectionHeader { text: "LAYOUT"; foreground: root.barForeground }

          Text {
            width: parent.width
            text: "Width of the reading in pixels. 0 fits the reading and holds that width so the bar stays still."
            color: Qt.darker(root.barForeground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          NumberField {
            label: ""
            value: root.pillWidth
            from: 0
            to: 400
            stepSize: 2
            foreground: root.barForeground
            accent: Color.accent
            field.editable: false
            onModified: function(value) { root.setPillWidth(value) }
          }

          PanelSeparator { width: parent.width; foreground: root.barForeground }

          // ---------- Load colours ----------
          PanelSectionHeader { text: "WARNING & ALERT"; foreground: root.barForeground }

          Text {
            width: parent.width
            text: "The pill and the hero mark change color once load passes the warning and alert marks. ∅ keeps the normal bar color."
            color: Qt.darker(root.barForeground, 1.4)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Warning from"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            NumberField {
              label: ""
              value: root.warnFrom
              // Steps land on multiples of 5, not 1/6/11.
              from: 5
              to: 100
              stepSize: 5
              foreground: root.barForeground
              accent: Color.accent
              field.editable: false
              onModified: function(value) { root.setWarnFrom(value) }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "%"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          SwatchRow {
            width: parent.width
            choices: root.colorChoices
            selected: root.warnColor
            foreground: root.barForeground
            onPicked: function(hex) { root.setWarnColor(hex) }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Alert from"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            NumberField {
              label: ""
              value: root.alertFrom
              from: 5
              to: 100
              stepSize: 5
              foreground: root.barForeground
              accent: Color.accent
              field.editable: false
              onModified: function(value) { root.setAlertFrom(value) }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "%"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          SwatchRow {
            width: parent.width
            choices: root.colorChoices
            selected: root.alertColor
            foreground: root.barForeground
            onPicked: function(hex) { root.setAlertColor(hex) }
          }
        }
      }
    }
  }

  // A labelled bar: name on the left, reading on the right, fill underneath.
  component MeterRow: Column {
    id: meter
    property string label: ""
    property string valueText: ""
    property real value: 0
    property color fill: Color.accent
    spacing: Style.space(4)

    Row {
      width: meter.width
      spacing: Style.space(8)

      Text {
        // Floor it: a fractional remainder rounds the value text past the
        // panel edge and clips its last character.
        width: Math.floor(meter.width - meterValue.width - parent.spacing)
        text: meter.label
        color: Qt.darker(root.barForeground, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      Text {
        id: meterValue
        text: meter.valueText
        color: root.barForeground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }

    Rectangle {
      width: meter.width
      height: Style.space(6)
      radius: height / 2
      color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.10)

      Rectangle {
        width: Math.round(parent.width * Math.max(0, Math.min(1, meter.value / 100)))
        height: parent.height
        radius: parent.radius
        color: meter.fill
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }
    }
  }

  // Label left, reading right — the sensor rows.
  component StatRow: Row {
    id: stat
    property string label: ""
    property string value: ""
    spacing: Style.space(8)

    Text {
      width: stat.width - statValue.width - stat.spacing
      text: stat.label
      color: Qt.darker(root.barForeground, 1.4)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    Text {
      id: statValue
      text: stat.value
      color: root.barForeground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }

  // One row of theme swatches; "" is the ∅ "leave it alone" choice.
  component SwatchRow: Row {
    id: swatches
    property var choices: []
    property string selected: ""
    property color foreground: Color.foreground
    signal picked(string hex)
    spacing: Style.space(6)

    Repeater {
      model: swatches.choices.length
      delegate: Rectangle {
        id: dot
        required property int index
        readonly property string swatch: swatches.choices[index]
        width: Style.space(22)
        height: Style.space(22)
        radius: width / 2
        color: dot.swatch === "" ? "transparent" : dot.swatch
        border.width: swatches.selected === dot.swatch ? 2 : 1
        border.color: swatches.selected === dot.swatch ? Color.accent : Qt.darker(swatches.foreground, 1.6)

        Text {
          visible: dot.swatch === ""
          anchors.centerIn: parent
          text: "∅"
          color: swatches.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: swatches.picked(dot.swatch)
        }
      }
    }
  }
}
