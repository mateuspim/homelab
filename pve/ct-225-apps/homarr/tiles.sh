#!/usr/bin/env bash
# tiles.sh — superseded by board.sh, which declares the whole board (apps, containers, layout, theme) idempotently.
# Kept so old notes/commands still work: bash /opt/stacks/homarr/tiles.sh [board-name]
exec bash "$(dirname "$0")/board.sh" "$@"
