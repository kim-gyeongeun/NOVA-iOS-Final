"""Check local NOVA backend without showing API keys or making paid requests."""
from __future__ import annotations

import argparse
import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def fetch(url: str, method='GET') -> dict:
    with urlopen(Request(url, method=method), timeout=12) as r:
        return json.load(r)


def run(base: str = 'http://127.0.0.1:8765', provider: str | None = None) -> int:
    base = base.rstrip('/')
    if not (base.startswith('http://127.0.0.1:') or base.startswith('http://localhost:')):
        print('안전상 기본 진단은 이 컴퓨터의 로컬 서버 주소만 지원합니다.')
        return 2
    try:
        health = fetch(base + '/health')
        rows = fetch(base + '/v1/providers')['providers']
        print('로컬 NOVA 서버 접속 성공:', health.get('name', 'NOVA'))
        for row in rows:
            print(f" - {row['id']}: {'키 설정됨' if row['configured'] else '키 미등록'} / 모델: {row['model']}")
        print('※ 위 상태는 키 존재 여부입니다. 실제 AI 응답 성공은 아닙니다.')
        if provider:
            print('실제 API 응답 확인 중 (유료 요청 발생 가능)...')
            answer = fetch(base + '/v1/probe/' + provider, method='POST')
            print('모델 응답 성공:', answer['model'], f"({answer['elapsed_ms']} ms)")
            print('미리보기:', answer['preview'][:120])
        else:
            print('실제 AI 테스트는 NOVA 앱 → 설정 → AI 연결 센터에서 진행하세요.')
        return 0
    except HTTPError as exc:
        detail = f'HTTP {exc.code}'
        try:
            payload = json.load(exc)
            detail += ': ' + str(payload.get('detail', ''))[:200]
        except Exception:
            pass
        print('서버 또는 API 오류:', detail)
    except (URLError, TimeoutError, OSError, KeyError, ValueError) as exc:
        print('서버 연결 실패. Backend/start_macos.command 창이 실행 중인지 확인하세요.')
        print('오류 유형:', type(exc).__name__)
    return 1


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--url', default='http://127.0.0.1:8765')
    p.add_argument('--probe', choices=['openai', 'anthropic', 'gemini'], help='실제 API 호출, 비용 발생 가능')
    a = p.parse_args()
    raise SystemExit(run(a.url, a.probe))
