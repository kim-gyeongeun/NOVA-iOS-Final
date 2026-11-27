#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 diagnose_connection.py
printf '\n'
read -r -p 'Enter를 눌러 창을 닫으세요. ' _
