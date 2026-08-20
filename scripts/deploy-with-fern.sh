#!/usr/bin/env bash
# Requires a Fern release binary that includes the cosys-airsim-vnc profile.
set -Eeuo pipefail

FERN_BIN="${FERN_BIN:-fern}"
"${FERN_BIN}" deploy --profile cosys-airsim-vnc --yes
