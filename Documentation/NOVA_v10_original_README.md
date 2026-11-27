# NOVA 11 — White Edition / Product UX Refresh

이 버전은 **NOVA 10 MacBook White Edition**을 기반으로 한 실제 SwiftUI 소스코드 업데이트입니다.
기존 기능, API 서버, 저장 파일 이름(`nova-v1.json`) 및 Bundle ID(`com.novaproject.multiagent`)는 유지했습니다.

## 실행
1. `NOVA/NOVA.xcodeproj`를 Xcode에서 엽니다. 개인 MacBook에서는 **Xcode 15.2**를 기준으로 준비했습니다. (iOS 16 이상 시뮬레이터)
2. Xcode에서 Product → Clean Build Folder 후 Build (`⌘B`) 또는 Run (`⌘R`).
3. 기존에 실행하던 시뮬레이터와 동일 Bundle ID로 설치하면 앱 데이터가 남아 있을 수 있습니다. **기존 앱을 삭제하지 마세요.** 중요한 데이터는 별도 보관을 권합니다.
4. Mac/시뮬레이터/서명 팀이 달라지면 기록이 자동으로 옮겨지지는 않습니다.

## NOVA 11 UI 변경
- 홈: 집중된 CTA, 두 개의 대표 기능(비교·협업)과 실사용 도구 바로가기, 가장 최근 대화, 전체 도구 진입점
- 탭: 기존 5개 → **홈 / 채팅 / AI 협업 / 보관함** 4개 (기존 AI 도구 삭제 없음: 홈에서 '모든 도구 보기')
- 홈 모델 버튼: 실제로 누른 모델의 새 대화 화면 열기 (기존에는 AI 허브만 열림)
- 채팅: 복사·공유, Markdown 표현(지원 범위 내), 사진/PDF/음성 첨부 위치 개선, 충분한 터치 영역
- 채팅 목록: 빈 상태, 최근 대화, 대화 삭제 확인, API 서버 상태 표시 (등록 키와 실제 응답 검증은 구별)
- 협업·보관함·기타 도구: 한글 메뉴 용어와 화면 제목 통일
- 결과물: 복사/공유 버튼 및 기본 Markdown 서식 표시
- 스타일: 화이트 배경 유지, 연회색 서피스, 절제된 블루 포인트. 외부 폰트/이미지 다운로드 없음

## API 사용
- **실제 AI 연결은 아직 완료되지 않았습니다.** API 키는 배포 파일에 없습니다.
- 키 발급 후 `Backend/configure_keys.command` 실행 → `Backend/start_macos.command` 실행 → 앱 설정의 연결 센터에서 실제 응답 테스트.
- 키를 앱 소스/압축파일/채팅에 붙여넣지 마세요. 유료 사용량에 유의하세요.
- 데모 모드에서는 예시 응답만 나오며, 실제 모델의 능력이나 연결 성공을 뜻하지 않습니다.

## 검증 상태
- 전체 Swift 파일 구문 파싱 검사 완료 (Linux swiftc frontend).
- Python 서버 pytest 24개 통과.
- 프로젝트 기본 설정 / 리소스 파일 존재 여부 / 개인 API 키 미포함 정적 검사.
- **이 환경에서는 macOS Xcode 빌드와 시뮬레이터 구동을 할 수 없으므로 검증 전입니다.** UI 픽셀 완성도는 실행 후 기기별 점검이 필요합니다.

`Documentation/NOVA_11_UI_QA_CHECKLIST.md`의 점검 항목을 실행해 보세요.
