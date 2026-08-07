#!/usr/bin/env bash
# Run the TBU envelope co-sim proof
set -e
cd "$(dirname "$0")/.."
export PYTHONPATH=python:${PYTHONPATH}
echo "=== TBU Envelope Co-sim ==="
python3 python/cosim/harness.py
echo "=== Done ==="
