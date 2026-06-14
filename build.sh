#!/usr/bin/env bash
set -e

WORKSPACE="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${WORKSPACE}/build"
mkdir -p "${BUILD_DIR}"

exec docker run --rm -i -v "${WORKSPACE}:/workspace" zmkfirmware/zmk-build-arm:stable /bin/bash << 'SCRIPT'
set -e -x

WORKSPACE="/workspace"
BUILD_DIR="${WORKSPACE}/build"
TMP_DIR="$(mktemp -d)"
mkdir -p "${TMP_DIR}/config"
cp -R "${WORKSPACE}/config/"* "${TMP_DIR}/config/"
cd "${TMP_DIR}"

west init -l config
west update --fetch-opt=--filter=tree:0
west zephyr-export

for target in \
  "nice_nano_v2|eyelash_sofle_dongle nice_view|" \
  "nice_nano_v2|eyelash_sofle_left|-DCONFIG_ZMK_SPLIT=y -DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n" \
  "nice_nano_v2|eyelash_sofle_right|-DCONFIG_ZMK_SPLIT=y -DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n" \
  "nice_nano_v2|settings_reset|"; do
  IFS='|' read -r board shield extra <<< "$target"
  name="${shield%% *}"
  [ -z "$name" ] && name="$board"
  bdir="${TMP_DIR}/build_${name}"
  echo "=== Building ${name} ==="
  west build -s zmk/app -d "$bdir" -b "$board" -- \
    -DZMK_CONFIG="${TMP_DIR}/config" \
    -DZMK_EXTRA_MODULES="${WORKSPACE}" \
    ${shield:+"-DSHIELD=${shield}"} \
    $extra
  cp "$bdir/zephyr/zmk.uf2" "${BUILD_DIR}/${name}.uf2"
done

rm -rf "${TMP_DIR}"
echo "=== Done! Files in ${BUILD_DIR} ==="
ls -lh "${BUILD_DIR}/"
SCRIPT
