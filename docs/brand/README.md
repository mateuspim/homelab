# Brand

- `../../icon.svg`: the mark (three server units, top one lit), with the accent in Proxmox orange `#ff8a3d`.
- `preview.svg`: source of the README hero `../../preview.png` (3840×2160). It follows the same layout as the Oma repos.

The panels on the right are drawn, not screenshots, so no LAN addresses or hostnames leak. Update the guest names, pool fill levels and container list by hand when the lab changes, then re-render:

```bash
rsvg-convert -o preview.png docs/brand/preview.svg
```

The text is set in JetBrainsMono Nerd Font. Check the PNG after rendering: without that font, fontconfig falls back to something else.
