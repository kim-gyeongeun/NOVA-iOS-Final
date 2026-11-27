"""Interactive, local-only API key configuration for NOVA.

Never prints, transmits, or logs a secret. Uses only Python's standard library.
"""
from __future__ import annotations

import argparse
from getpass import getpass
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
ENV = ROOT / '.env'
KEYS = [
    ('OPENAI_API_KEY', 'OpenAI / GPT'),
    ('ANTHROPIC_API_KEY', 'Anthropic / Claude'),
    ('GEMINI_API_KEY', 'Google / Gemini'),
]
MODELS = {
    'OPENAI_MODEL': 'gpt-4.1-mini',
    'ANTHROPIC_MODEL': 'claude-haiku-4-5',
    'GEMINI_MODEL': 'gemini-3.5-flash-lite',
}


def read_config(path: Path = ENV) -> dict[str, str]:
    if not path.exists():
        return {}
    data = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith('#') or '=' not in stripped:
            continue
        k, v = stripped.split('=', 1)
        k = k.strip()
        if re.fullmatch(r'[A-Z][A-Z0-9_]*', k):
            data[k] = v.strip().strip('"').strip("'")
    return data


def save_config(values: dict[str, str], path: Path = ENV) -> None:
    # Writes a fresh, minimal configuration to avoid exposing secrets in backups.
    values = dict(values)
    for value in values.values():
        if any(ch in value for ch in '\r\n\x00'):
            raise ValueError('키 또는 모델 ID에 잘못된 줄바꿈 문자가 있습니다.')
    rows = [
        '# NOVA backend secrets. NEVER SHARE THIS FILE OR COMMIT TO GIT.',
        '# API keys are consumed by the Mac backend, never by the iOS app.',
    ]
    rows += [f'{k}={values.get(k, "")}' for k, _ in KEYS]
    rows += [f'{k}={values.get(k, default)}' for k, default in MODELS.items()]
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write('\n'.join(rows) + '\n')
        os.chmod(path, 0o600)
    except BaseException:
        raise


def summarize(config: dict[str, str]) -> None:
    print('NOVA API 설정 상태 (실제 서비스 호출 여부는 별도 확인 필요):')
    for name, display in KEYS:
        print(f' - {display}: ' + ('키 등록됨' if bool(config.get(name)) else '키 미등록'))
    print('API 키 문자열은 표시하지 않습니다.')


def interactive() -> None:
    config = read_config()
    print('=== NOVA 안전한 API 키 등록 ===')
    print('키는 이 Mac의 Backend/.env에만 저장됩니다.')
    print('입력하는 키는 화면에 보이지 않습니다. Enter는 기존 값을 유지합니다.')
    print('처음에는 한 제공자만 연결해도 됩니다. API 사용 요금이 발생할 수 있습니다.')
    for name, label in KEYS:
        existing = bool(config.get(name))
        note = '등록되어 있음' if existing else '미등록'
        new = getpass(f'{label} 키 [{note}] (그대로 두려면 Enter): ').strip()
        if new:
            if ' ' in new or len(new) < 12 or any(c in new for c in '\r\n\x00'):
                print(f'{label}: 키의 형식을 다시 확인하세요. 기존 값 유지.')
            else:
                config[name] = new
    for name, default in MODELS.items():
        config.setdefault(name, default)
    save_config(config)
    print('\n저장 완료: Backend/.env (이 Mac에만 저장, 비밀 키 내용 비표시)')
    summarize(config)
    print('\n다음: Backend/start_macos.command 실행 → 앱 설정 → AI 연결 센터.')
    print('이미 서버가 실행 중이었다면 종료 후 재시작하세요.')


def main() -> None:
    parser = argparse.ArgumentParser(description='NOVA 개인 Mac API 키 설정 도구')
    parser.add_argument('--status', action='store_true', help='비밀 값을 노출하지 않고 설정 여부만 확인')
    args = parser.parse_args()
    if args.status:
        summarize(read_config())
    else:
        interactive()


if __name__ == '__main__':
    main()
