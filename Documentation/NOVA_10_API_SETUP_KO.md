# NOVA 10.0 실제 API 키 등록 안내 (Mac + Xcode)

> NOVA 10은 기존 9.0 앱의 기능을 유지하면서 키 설정 및 연결 진단 도구를 추가한 버전입니다. **실제 API 키는 포함되어 있지 않습니다.** GPT·Claude·Gemini 호출에는 각 개발자 계정과 과금/사용 한도 설정이 필요할 수 있습니다.

## 0. 먼저 확인

- `NOVA_Project/NOVA/NOVA.xcodeproj`에서 앱을 실행합니다.
- 이전 버전에서 작성한 대화/결과물은 앱을 삭제하면 없어질 수 있습니다. **기존 앱을 삭제하지 말고 업데이트**하세요.
- 새 ZIP의 `Backend/.env`는 비어 있습니다. **기존 프로젝트의 .env는 새 프로젝트에 자동 복사되지 않습니다.** 기존에 키가 있다면 Mac 안에서만 안전하게 옮겨주세요.
- ChatGPT Plus, Claude Pro, Gemini 구독과 개발자 API 사용료는 별도입니다.

## 1. API 키 발급

- OpenAI: <https://platform.openai.com/api-keys>
- Anthropic: <https://platform.claude.com/settings/keys>
- Gemini: <https://aistudio.google.com/api-keys>

가능하면 각 제공자 대시보드에서 예산/사용 제한을 설정하고, 초반에는 1개 모델만 사용하세요. **키를 ChatGPT 대화창, GitHub, 발표 슬라이드, 사진/스크린샷에 공유하지 마세요.**

## 2. NOVA 백엔드 폴더에 키 등록

1. Finder에서 압축 해제한 `NOVA_Project` > `Backend` 폴더를 엽니다.
2. `configure_keys.command`를 더블클릭합니다. macOS 보안 정책 때문에 안 열리면 터미널에서 `bash configure_keys.command`를 실행하세요.
3. 터미널에 키를 입력합니다. **입력 중 글자가 보이지 않는 것은 정상**입니다.
4. Enter만 누르면 해당 제공자를 건너뛰거나 이전 키를 유지합니다.
5. 자동으로 `Backend/.env`가 만들어집니다. 파일 퍼미션을 소유자만 읽고 쓸 수 있도록 설정합니다.
6. `python3 setup_keys.py --status`로 키 문자열을 공개하지 않고 설정 여부를 확인할 수 있습니다.

직접 편집하고 싶다면 `Backend/.env.example`를 `.env`로 복사하여 아래 필드만 채우세요.

```dotenv
OPENAI_API_KEY=내키입력
ANTHROPIC_API_KEY=내키입력
GEMINI_API_KEY=내키입력
OPENAI_MODEL=gpt-4.1-mini
ANTHROPIC_MODEL=claude-haiku-4-5
GEMINI_MODEL=gemini-3.5-flash-lite
```

**예시 키는 절대로 진짜 파일에 넣지 마세요.** 해당 모델을 사용할 수 없다면 제공자 콘솔에서 액세스 가능한 정확한 모델 ID로 변경해야 합니다.

## 3. Mac 서버 실행

1. `Backend/start_macos.command`를 더블클릭합니다. 터미널에서 `bash start_macos.command`도 가능합니다.
2. 첫 실행이면 의존성을 설치하므로 인터넷이 필요합니다. 오류가 나면 `python3 --version`과 에러 메시지를 확인합니다.
3. 터미널 창을 닫지 마세요. 보통 `Uvicorn running on http://127.0.0.1:8765`가 보입니다.
4. 브라우저에서 <http://127.0.0.1:8765/health> 를 엽니다. JSON 형식의 상태 메시지가 보이면 서버가 작동한 것입니다.
5. 선택: `Backend/check_connection.command`로 키 값 노출 없이 설정 상태를 진단합니다.

## 4. NOVA iOS 앱의 LIVE 모드

1. **설정 → AI 연결 센터**로 이동합니다.
2. 시뮬레이터 사용 시 서버 주소를 `http://127.0.0.1:8765`로 설정합니다.
3. **연결 상태 새로고침**을 누릅니다. `키 설정됨`은 키가 존재한다는 뜻일 뿐 유효성 검사는 아닙니다.
4. **실제 API 응답 확인**을 누릅니다. 성공해야 실제 API가 응답한다는 의미입니다. 요청에는 요금이 발생할 수 있습니다.
5. 연결에 성공한 후 **데모 모드 OFF**로 바꾸고 AI Hub의 개별 AI 채팅을 테스트합니다.
6. 그다음 AI Compare / Blind Arena / Team Workflow로 테스트 범위를 넓힙니다. 협업에서는 API가 여러 번 호출되므로 과금에 특히 주의하세요.

## 5. 실제 아이폰에서 실행하는 경우

동일 Wi-Fi의 Mac IP를 서버 주소로 사용해야 합니다. 예: `http://192.168.0.12:8765` (**예시 IP**). Mac에서만 일시적으로 `NOVA_HOST=0.0.0.0 bash start_macos.command`로 서버를 실행해야 아이폰이 접근할 수 있습니다. 이 서버에는 사용자 인증이 없습니다. **신뢰할 수 있는 개인 Wi-Fi에서만 사용하고, 포트 포워딩/공용 인터넷 노출은 금지**하세요. iOS의 로컬 네트워크/HTTP 연결 권한 및 Mac 방화벽 설정에 따라 추가 조치가 필요할 수 있습니다.

## 6. 흔한 오류

| 오류 | 해결 |
| --- | --- |
| 서버 연결 실패 | Mac 서버 터미널 실행 여부, 서버 주소, 포트 확인 |
| 키 없음 | `.env` 저장 여부 확인, 서버 **재시작** |
| API 401 | 복사한 키가 정확한지 / 폐기·만료되지 않았는지 확인 |
| API 403 | 제공자 모델 접근 권한과 계정 확인 |
| API 404 / 400 | `.env`의 모델 ID가 계정에서 사용 가능한지 확인 |
| API 429 / 402 | 잔액, 결제, 호출 한도, 예산 설정 확인 |
| 시뮬레이터는 되는데 아이폰은 실패 | 동일 Wi-Fi 및 Mac의 IP/방화벽/서버 바인딩 확인 |
| 테스트는 되지만 데모 답변이 표시됨 | 앱의 데모 모드를 OFF로 바꾸기 |

## 정보 보호

API 키는 서버의 `.env`에만 보관합니다. 서버는 로컬 개발/수업 데모용이며 공개 배포용 백엔드는 아닙니다. PDF나 사진을 AI 분석하면 해당 자료가 외부 제공자 API로 전송될 수 있습니다. 개인/민감정보가 포함된 파일은 사전에 제거하세요.

## 검증 범위

이 ZIP에 실제 사용자 키를 넣지 않았으며, 실제 OpenAI/Anthropic/Gemini 과금 요청도 수행하지 않았습니다. 자동 테스트는 모의 요청과 로컬 코드 검증만 수행합니다. Mac Xcode에서의 빌드/기기 접근은 개발자가 별도로 확인해야 합니다.
