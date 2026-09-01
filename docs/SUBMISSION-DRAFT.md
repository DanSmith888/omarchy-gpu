<!--
Marketplace submission, unsubmitted. To send: push, then
  gh issue create --repo HANCORE-linux/omarchy-plugin-marketplace \
    --title "[Plugin]: GPU" --body-file docs/SUBMISSION-DRAFT.md
(strip this comment first)
-->

### Repository URL

https://github.com/DanSmith888/omarchy-gpu

### Category

Hardware

### Tags

bar, system, quickshell

### Suggest a missing tag

_No response_

### Maintainer notes

Load, VRAM, temperature and power in the bar. The panel adds a load graph, VRAM
and power meters, every sensor the driver reports, and the processes holding
GPU memory. Multi GPU machines get a card picker. Middle click opens btop.

NVIDIA reads through nvidia-smi, AMD and Intel through /sys/class/drm and their
hwmon nodes. Anything a driver does not report is hidden, so the panel only
shows real readings. Two standard library Python scripts in bin/. The only
external commands are nvidia-smi and lspci, both read only. No daemon, no root,
no network, and nothing written outside its own folder.

I develop and test against an NVIDIA card. The AMD and Intel paths follow the
documented sysfs contract but I cannot exercise them.

One of a trio with omarchy-cpu and omarchy-bandwidth, which share a panel
layout and controls.

### Submission checklist

- [x] The repository is public and includes install and removal instructions
- [x] The license and any external dependencies are documented
- [x] I own or have permission to publish the plugin and preview assets
- [x] The plugin does not overwrite user configuration without explicit consent
- [x] I understand approval is for listing only and is not a security review
