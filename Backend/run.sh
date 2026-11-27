#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -f .env ]; then
  cp .env.example .env
  echo 'Backend/.env를 편집해 사용할 AI 제공자의 API 키를 입력하세요.'
fi
python3 -m uvicorn app:app --host "${NOVA_HOST:-127.0.0.1}" --port 8765
