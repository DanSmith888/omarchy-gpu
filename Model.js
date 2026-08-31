// Pure helpers for the GPU plugin: formatting, colours, settings parsing.
// No Qt objects in here so the logic stays testable with plain node.

// Theme palette for the swatch rows, read from the live Omarchy theme.
function parseThemeColors(raw) {
  var keys = ["accent", "muted", "foreground", "red", "yellow", "orange", "green", "cyan", "blue", "magenta"]
  var out = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (!match) continue
    if (keys.indexOf(match[1]) !== -1) out[match[1]] = match[2]
  }
  return out
}

// "" first: keeps the normal bar colour.
function themePalette(theme) {
  var t = theme || {}
  return [
    "",
    t.red || "#e06c75",
    t.orange || t.yellow || "#d19a66",
    t.yellow || "#e5c07b",
    t.green || "#98c379",
    t.cyan || "#56b6c2",
    t.blue || t.accent || "#61afef",
    t.magenta || "#c678dd",
    t.muted || "#abb2bf",
    t.foreground || "#ffffff"
  ]
}

function num(v, fallback) {
  var n = Number(v)
  return isFinite(n) ? n : fallback
}

function clampInt(v, lo, hi, fallback) {
  var n = Math.round(num(v, fallback))
  if (!isFinite(n)) n = fallback
  return Math.max(lo, Math.min(hi, n))
}

function asBool(v, fallback) {
  if (v === true || v === "true" || v === 1) return true
  if (v === false || v === "false" || v === 0) return false
  return fallback
}

function isNum(v) { return typeof v === "number" && isFinite(v) }

// ---- temperature units --------------------------------------------------

function toUnit(c, unit) {
  if (!isNum(c)) return null
  return unit === "F" ? c * 9 / 5 + 32 : c
}
function unitSuffix(unit) { return unit === "F" ? "°F" : "°C" }
function normalizeUnit(unit) { return String(unit) === "F" ? "F" : "C" }

// ---- formatting ---------------------------------------------------------

function pct(v) { return isNum(v) ? Math.round(v) + "%" : "–" }
function pct1(v) { return isNum(v) ? v.toFixed(1) + "%" : "–" }
function degrees(v, unit) {
  var t = toUnit(v, unit)
  return isNum(t) ? Math.round(t) + unitSuffix(unit) : "–"
}
function degreesShort(v, unit) {
  var t = toUnit(v, unit)
  return isNum(t) ? Math.round(t) + "°" : "–"
}
function watts(v) { return isNum(v) ? Math.round(v) + " W" : "–" }
function wattsShort(v) { return isNum(v) ? Math.round(v) + "W" : "–" }
function mhz(v) { return isNum(v) ? Math.round(v) + " MHz" : "–" }
function ghzShort(v) { return isNum(v) ? (v / 1000).toFixed(1) + "GHz" : "–" }

// VRAM is reported in MiB; show GiB once it runs past a gigabyte.
function mib(v) {
  if (!isNum(v)) return "–"
  if (v >= 1024) return (v / 1024).toFixed(1) + " GiB"
  return Math.round(v) + " MiB"
}
function mibShort(v) {
  if (!isNum(v)) return "–"
  if (v >= 1024) return (v / 1024).toFixed(1) + "G"
  return Math.round(v) + "M"
}

// "NVIDIA GeForce RTX 2080 SUPER" -> "RTX 2080 SUPER"
// "Advanced Micro Devices, Inc. [AMD/ATI] Navi 31 [Radeon RX 7900 XTX]" -> "Radeon RX 7900 XTX"
function shortModel(name) {
  var s = String(name || "")
  var bracket = s.match(/\[([^\[\]]+)\]\s*$/)
  if (bracket) s = bracket[1]
  s = s.replace(/^(NVIDIA|AMD|ATI|Intel)\s+(Corporation\s+)?/i, "")
  s = s.replace(/\bGeForce\s+/i, "")
  s = s.replace(/Advanced Micro Devices, Inc\.?/i, "")
  s = s.replace(/\[AMD\/ATI\]/i, "")
  s = s.replace(/\s{2,}/g, " ").trim()
  return s || "GPU"
}

// Bar pill text: only the parts the user switched on.
function barText(parts) {
  var out = []
  for (var i = 0; i < parts.length; i++) if (parts[i]) out.push(parts[i])
  return out.join(" ")
}

function memPercent(used, total) {
  if (!isNum(used) || !isNum(total) || total <= 0) return null
  return 100 * used / total
}

function powerPercent(draw, limit) {
  if (!isNum(draw) || !isNum(limit) || limit <= 0) return null
  return 100 * draw / limit
}

// ---- colours ------------------------------------------------------------

// Load band colour: "" (normal) under busyFrom, busyColor from busyFrom,
// hotColor from hotFrom. Either colour may be "" to keep the normal colour.
function loadColor(usage, busyFrom, hotFrom, busyColor, hotColor) {
  if (!isNum(usage)) return ""
  if (usage >= hotFrom) return hotColor
  if (usage >= busyFrom) return busyColor
  return ""
}

function gpuChips(gpus) {
  var out = []
  var list = gpus || []
  for (var i = 0; i < list.length; i++)
    out.push({ value: String(list[i].index), label: shortModel(list[i].name), tooltip: list[i].name })
  return out
}

// ---- history ------------------------------------------------------------

// Append one sample and keep the last `size`. Returns a new array so QML
// property bindings actually fire.
function pushHistory(history, value, size) {
  var out = (history || []).slice()
  out.push(isNum(value) ? value : 0)
  var cap = Math.max(2, Math.round(num(size, 60)))
  while (out.length > cap) out.shift()
  return out
}
