#!/usr/bin/env bash
# Pack test.lua, utils.lua, ltask.so, and directories test/ lualib/ luaclib/ service/ ext_lualib/
# Usage: ./pack.sh [output.tar.gz]

set -e
cd "$(dirname "$0")"

OUT="${1:-ltask-pack.tar.gz}"

# Resolve ltask binary (ltask.so or ltask.dll on Windows)
LTASK_SO=""
for f in ltask.so ltask.dll; do
    if [[ -f "$f" ]]; then
        LTASK_SO="$f"
        break
    fi
done

ITEMS=(
    test.lua
    utils.lua
    $LTASK_SO
    test
    lualib
    luaclib
    service
    ext_lualib
)

LIST=()
for x in "${ITEMS[@]}"; do
    if [[ -n "$x" ]] && [[ -e "$x" ]]; then
        LIST+=( "$x" )
    fi
done

if [[ ${#LIST[@]} -eq 0 ]]; then
    echo "Nothing to pack (missing files/dirs?)." >&2
    exit 1
fi

echo "Packing: ${LIST[*]} -> $OUT"
tar czvf "$OUT" "${LIST[@]}"
echo "Done: $OUT"
