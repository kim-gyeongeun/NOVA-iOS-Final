#!/bin/bash
# Interactive secret input runs in the local Mac terminal, not in ChatGPT.
set -euo pipefail
cd "$(dirname "$0")"
python3 setup_keys.py
printf '\n'
read -r -p '완료되었습니다. Enter를 눌러 창을 닫으세요. ' _
