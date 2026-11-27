#!/bin/bash
# NOVA local-only API bridge. Use on a trusted Mac; do not expose port 8765 on the internet.
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f .env ]; then
  cp .env.example .env
  echo
  echo '처음 실행: Backend/.env 파일에 API 키를 입력한 후 이 파일을 다시 실행하세요.'
  echo '키가 준비되지 않았다면 데모 모드를 유지하세요.'
  echo
  read -r -p 'Enter를 눌러 종료... ' _
  exit 0
fi
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
source .venv/bin/activate
python3 -m pip install -r requirements.txt
# For a physical iPhone on the same Wi-Fi set NOVA_HOST=0.0.0.0 only temporarily.
exec python3 -m uvicorn app:app --host "${NOVA_HOST:-127.0.0.1}" --port 8765
