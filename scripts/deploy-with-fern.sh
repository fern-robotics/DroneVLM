#!/usr/bin/env bash
# Requires Fern with the cosys-airsim-vnc profile from patches/fern-cosys-airsim-vnc.patch.
set -Eeuo pipefail

FERN_BIN="${FERN_BIN:-fern}"
"${FERN_BIN}" deploy --profile cosys-airsim-vnc --yes
