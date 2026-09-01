# GPU

GPU load, VRAM, temperature and power in the [Omarchy](https://omarchy.org/)
bar.

![Bar](docs/bar.png)

![Panel](docs/panel.png)

I built this for my own machine, alongside
[omarchy-cpu](https://github.com/DanSmith888/omarchy-cpu) and
[omarchy-bandwidth](https://github.com/DanSmith888/omarchy-bandwidth). The three
share a panel layout and controls.

## Install

```bash
omarchy plugin add https://github.com/DanSmith888/omarchy-gpu.git --enable
```

Update with `omarchy plugin update dansmith888.gpu && omarchy restart shell`.
Remove with `omarchy plugin remove dansmith888.gpu`.

## Using it

Left click opens the panel. Middle click opens `btop`. Hover for a summary.

Bind a hotkey with `omarchy-shell shell toggle dansmith888.gpu`.

## The panel

| Section | Shows |
|---|---|
| Hero | Card name, vendor, VRAM size, driver version |
| Graph | Recent load, 30 to 240 samples |
| Meters | Load, VRAM, power against its limit |
| Sensors | Temperature, fan, core and memory clocks, performance state |
| Using the GPU | Processes holding GPU memory, biggest first |
| In the bar | Which readings the pill shows, card picker, refresh rate, °C or °F |
| Layout | A fixed pill width, or auto |
| Warning & alert | Two load thresholds, each with a colour from the active theme |

Settings live on the widget's `~/.config/omarchy/shell.json` entry and apply
immediately.

## What each driver gives you

| | NVIDIA | AMD | Intel |
|---|---|---|---|
| Load | yes | yes | no |
| VRAM | yes | yes | no |
| Temperature | yes | yes | yes |
| Power | yes, with limit | yes | no |
| Clocks | core and memory | core | core |
| Fan | yes | from PWM | no |
| Processes | yes | no | no |

Anything a driver does not report is hidden, so the panel only shows real
readings.

## Requirements

Omarchy (Quattro or later). `nvidia-utils` for NVIDIA. AMD and Intel need
nothing beyond the kernel. `pciutils` for the card name on AMD and Intel.
`btop` only for the middle click shortcut.

## Notes

I develop and test this against an NVIDIA card. The AMD and Intel paths follow
the documented sysfs contract but I cannot exercise them.

The process list merges compute clients with the graphics clients from
`nvidia-smi -q -d PIDS`, so your compositor and browser show up, not just CUDA
jobs.

Multi GPU machines get a card picker in the panel, and the pill follows it.

An idle card parks its clock and fan, so low numbers there are the card working
correctly.

## Command line

```
gpuctl get [--json] [-i N]   readings for one card
gpuctl list [--json]         every GPU found
gpuctl doctor                check every link from the driver to the bar
```

## What runs, and as whom

Omarchy plugins run inside the shell process, unsandboxed, as your user. This
one runs two Python scripts from its own `bin/`: standard library only, no
extra packages, no network, nothing needing root. It shells out to `nvidia-smi`
and `lspci`, both read only, and writes nothing at all.

## Credits

The panel borrows its shape from Omarchy's tailscale and network panels, and
the history graph from
[stappmus.activity-monitor](https://github.com/stappmus/omarchy-activity-monitor).

## Licence

MIT, see [LICENSE](LICENSE).
