# GPU: development notes

GPU load, VRAM, temperature and power in the Omarchy bar

Human development notes for this repo. Deliberately not named CLAUDE.md: an
installed plugin tree can be read by coding agents, and an agent-instruction
filename in a distributed package is a prompt-injection surface.

## Identity

- id / IPC target / `moduleName`: `dansmith888.gpu`
- repo: `https://github.com/DanSmith888/omarchy-gpu.git`
- installed copy: `~/.config/omarchy/plugins/dansmith888.gpu`
- kind: `bar-widget`, entry point `BarWidget.qml`

## Map

- `manifest.json` — the contract; bump `version` on release.
- `BarWidget.qml` — entry point. Owns the pill and the single IpcHandler; forwards open/close/opened to Panel.qml, which owns all state.
- `Model.js` — pure formatting/colour helpers; testable with plain node.
- `Sparkline.qml` — Canvas line graph used for the load history.
- `Panel.qml` — all state and the whole popup.
- `bin/gpustatus` — one JSON line for the QML; `{}` = nothing to show.
- `bin/gpuctl` — CLI: `get [--json]`, `doctor`, action verbs. Holds
  `PLUGIN_ID` / `REPO_URL` (keep in sync with the manifest).
- `docs/SUBMISSION-DRAFT.md` — marketplace issue body (unsubmitted).

## Dev loop

```bash
omarchy plugin validate . && ~/.claude/skills/omarchy-plugin-dev/scripts/lint.sh
rsync -a --delete --exclude .git ./ ~/.config/omarchy/plugins/dansmith888.gpu/
omarchy-shell shell toggle dansmith888.gpu '{}'
qs log -p "$OMARCHY_PATH/shell" --tail 100
bin/gpuctl doctor
```

## Rules

- Keep in sync on release: `manifest.version`, git tag `vX.Y.Z`,
  `moduleName` in every QML, `PLUGIN_ID`/`REPO_URL` in `bin/gpuctl`,
  README commands.
- stdlib Python only in `bin/`; no root, no network; locks in
  `$XDG_RUNTIME_DIR`.
- Never edit `/usr/share/omarchy/**`.
- No `git push`, tag push, or marketplace submission unless Daniel says so.

## Gotchas

- `gpustatus` imports `gpuctl` in-process (SourceFileLoader) so a poll is
  one Python start-up, not two. It takes the card index as argv[1].
- nvidia-smi's `--query-compute-apps` omits *graphics* clients, so the
  process list also parses `nvidia-smi -q -d PIDS`. Both are needed to see
  Hyprland/browser VRAM.
- `to_num()` turns "[N/A]" and "[Not Supported]" into None; every reading
  is nullable and the QML hides the row rather than printing a zero.
- AMD fan % is derived from `pwm1` (0-255); `fan1_input` is RPM and is not
  a percentage, so it is left null.
- qmllint reports "unqualified access" for `root.`/`column.` references
  inside inline `component`s and `Component {}` blocks. Those are expected;
  only `Error:` lines matter.
- Panel content must NOT add `anchors.margins` — `KeyboardPanel.padding`
  already insets it, the way tailscale and agents do it.
