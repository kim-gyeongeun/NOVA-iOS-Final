# NOVA — Multi-AI iOS Workspace

**NOVA**는 OpenAI GPT, Anthropic Claude, Google Gemini를 하나의 iOS 앱에서 활용하고, 여러 AI가 서로 다른 역할로 작업을 수행하도록 구성한 **멀티 AI 통합·협업 애플리케이션**입니다.

## 1. 프로젝트 소개

- **프로젝트명:** NOVA
- **플랫폼:** iOS (SwiftUI)
- **개발 목적:** 여러 AI 서비스를 오가며 사용해야 하는 불편함을 줄이고, 답변 비교와 역할 기반 협업을 통해 복잡한 작업을 단계별로 수행할 수 있는 환경 제공
- **프로젝트 형태:** 대학교 iOS 앱 개발 최종 프로젝트

## 2. 주요 기능

| 기능 | 설명 |
| --- | --- |
| 멀티 AI 채팅 | GPT, Claude, Gemini 모델별 개별 대화 |
| AI 답변 비교 | 동일한 질문을 여러 AI에 보내 응답 비교 |
| AI 토론 | 역할을 나눠 찬반 논의·반박 진행 |
| 블라인드 아레나 | 모델 이름을 숨긴 상태로 답변 비교·평가 |
| 멀티 에이전트 협업 | 목표 분석 → 작업 계획 → 역할별 실행 → 검토 → 최종 결과 통합 |
| AI 팀 관리 | 역할·지시문·모델을 지정하고 팀을 저장·편집 |
| 문서 인식 및 분석 | 이미지 OCR, PDF 텍스트 추출과 AI 기반 분석 |
| 결과 작업실 | AI 생성 결과를 편집·저장·공유 |
| 기록 보관함 | 대화와 협업 결과를 앱 내부에 로컬 저장 |

> 협업 엔진의 에이전트는 주로 **순차적 워크플로우**로 작동하며, 이전 단계의 결과를 다음 단계의 입력에 활용합니다. 인터넷 검색, 외부 소프트웨어의 자동 조작, 완전한 자동 코드 실행은 기본 기능에 포함되지 않습니다.

## 3. 개발 기술

- **iOS:** Swift, SwiftUI, Xcode
- **iOS 기능:** Vision, PDFKit, AVFoundation, Speech 등
- **AI API:** OpenAI, Anthropic, Google Gemini (각 제공사의 키와 계정 사용 권한 필요)
- **서버:** Python, FastAPI
- **데이터 보관:** 기기 내 로컬 파일 기반 저장
- **UI:** 오프화이트 기반의 생산성 앱 스타일

## 4. 프로젝트 폴더

```text
NOVA-MultiAI-iOS/
├── NOVA/                 # Xcode 프로젝트 및 iOS SwiftUI 소스
├── Backend/              # FastAPI 서버, 의존성, 테스트, API 설정 샘플
├── Documentation/        # 기능 설명 및 테스트 문서
├── Tests/                # 일부 Swift 테스트 코드
├── Presentation/         # 최종 발표 자료를 이곳에 추가
├── README.md
└── .gitignore
```

## 5. 실행 방법

### iOS 앱 실행

1. macOS에서 `NOVA/NOVA.xcodeproj`를 Xcode로 엽니다.
2. iOS 시뮬레이터를 선택하고 `Command + R`로 실행합니다.
3. 데모 모드를 이용해 UI 및 기능 흐름을 확인할 수 있습니다.

### 실제 AI 연결

1. 각 AI 제공사의 공식 사이트에서 API 키를 발급받습니다.
2. `Backend/.env.example`을 참고해 **본인 Mac의** `Backend/.env`를 설정합니다. 또는 `Backend/configure_keys.command`로 키를 입력할 수 있습니다.
3. `Backend/start_macos.command`를 실행해 FastAPI 서버를 시작합니다.
4. iOS 시뮬레이터에서 기본 서버 주소 `http://127.0.0.1:8765`를 확인합니다.
5. 앱의 **설정 → AI 연결 센터**에서 모델별 실제 응답을 검사한 후 데모 모드를 해제합니다.

**주의:** API 서비스 이용에는 과금이나 별도의 한도가 적용될 수 있습니다. 모델 ID는 API 제공사의 지원 현황과 계정 권한에 따라 변경해야 할 수 있습니다. 실기기 실행 시에는 Mac의 네트워크 주소와 서버 설정이 추가로 필요합니다.

## 6. 보안 및 유의사항

- `Backend/.env` 및 실제 API 키는 **GitHub에 업로드하지 않습니다.**
- 이 저장소에는 예시 설정 파일인 `.env.example`만 포함합니다.
- 제공되는 코드는 학습·과제용 프로젝트이며, 본인 환경에서 실행·기능 테스트가 필요합니다.
- 데모 모드의 예시 응답과 실제 모델이 생성하는 응답을 구분합니다.

## 7. 발표 자료

최종 발표 자료는 [`Presentation/`](Presentation/) 폴더에서 확인할 수 있도록 정리합니다.
