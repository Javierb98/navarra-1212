#!/usr/bin/env bash
# Export the game for the Raspberry Pi, and optionally push it to the cabinet.
#
#   ./tools/export_pi.sh                # build only
#   ./tools/export_pi.sh pi@navarra     # build, then scp it across
#
# Requires the Linux export templates to be installed in the editor once:
#   Editor → Manage Export Templates → Download and Install
set -euo pipefail

PRESET="${PRESET:-Raspberry Pi}"
OUT_DIR="build/pi"
OUT_BIN="$OUT_DIR/navarra-1212"
REMOTE_DIR="${REMOTE_DIR:-navarra}"

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$GODOT" ]; then
	GODOT="$(command -v godot || true)"
fi
if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
	echo "No encuentro Godot. Exporta la ruta en GODOT=… y repite." >&2
	exit 1
fi

cd "$(dirname "$0")/.."
mkdir -p "$OUT_DIR"

# Import first: a cold checkout has no .godot/, and exporting without it
# produces a build missing every imported asset.
echo "▸ Importando recursos…"
"$GODOT" --headless --path . --import

echo "▸ Exportando preset '$PRESET' → $OUT_BIN"
"$GODOT" --headless --path . --export-release "$PRESET" "$OUT_BIN"

if [ ! -f "$OUT_BIN" ]; then
	echo "La exportación no produjo $OUT_BIN." >&2
	echo "Comprueba que las plantillas de exportación Linux estén instaladas" >&2
	echo "y que exista el preset '$PRESET' en export_presets.cfg." >&2
	exit 1
fi

chmod +x "$OUT_BIN"
echo "▸ Listo: $(du -h "$OUT_BIN" | cut -f1)  $OUT_BIN"

if [ $# -ge 1 ]; then
	TARGET="$1"
	echo "▸ Copiando a $TARGET:$REMOTE_DIR/"
	ssh "$TARGET" "mkdir -p $REMOTE_DIR"
	scp "$OUT_BIN" "$TARGET:$REMOTE_DIR/"
	echo "▸ Reiniciando el servicio (se ignora si no está instalado)"
	ssh "$TARGET" "sudo systemctl restart navarra-1212 2>/dev/null || true"
	echo "▸ Hecho."
fi
