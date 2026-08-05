# PolyGlot AI

PolyGlot AI는 Flutter로 만든 다국어 번역 애플리케이션 프로토타입입니다. 텍스트 번역을 중심으로 음성 입력·읽기, 번역 기록, 이미지 선택 기반 OCR 데모, 2인 대화 모드, 로컬 계정과 PRO 요금제 흐름을 하나의 앱에서 보여줍니다.

현재 코드는 기능 검증과 UI/UX 시연을 위한 데모 단계입니다. 실제 서비스에 적용하기 전에는 아래의 [현재 구현 범위와 제한 사항](#현재-구현-범위와-제한-사항)을 먼저 확인해 주세요.

## 주요 기능

- 한국어, 영어, 일본어, 중국어 등 12개 언어 선택 및 상호 번역
- 원문·번역 언어 교환과 입력·결과 동시 전환
- 선택적으로 입력한 Gemini API 키를 이용한 번역
- 웹 Speech API와 `speech_to_text`를 이용한 음성 입력(STT)
- 웹 Speech Synthesis와 `flutter_tts`를 이용한 번역문 읽기(TTS)
- `SharedPreferences`에 번역 기록 저장, 검색, 즐겨찾기, 삭제
- 카메라·갤러리 이미지 선택과 OCR 처리 흐름 데모
- 방 생성·참여 UI, 자동 번역, 음성 입출력을 포함한 대화 모드 데모
- 로컬 회원가입·로그인·세션 유지와 관리자 회원 조회
- PRO 페이월, 기기 인증, 모의 결제 및 광고 노출 흐름
- Material 3 기반 라이트·다크 테마 자동 전환

## 번역 처리 방식

번역 요청은 `GeminiTranslationService` 한 곳에서 처리합니다.

1. 사용자가 설정 화면에 Gemini API 키를 입력하고 키가 `AIzaSy`로 시작하면 Gemini `generateContent` API를 호출합니다.
2. API 키가 없거나 Gemini 호출이 실패하면 `translate.googleapis.com`의 무료 번역 엔드포인트를 사용합니다.
3. 번역 결과는 Riverpod 상태에 반영되고 로컬 번역 기록에 자동 저장됩니다.

API 키는 소스 코드에 포함되어 있지 않으며 앱 실행 중 메모리에만 보관됩니다. 클라이언트 앱에 입력한 키는 완전히 숨길 수 없으므로, 운영 환경에서는 서버 프록시와 별도의 비밀정보 관리가 필요합니다.

## 애플리케이션 흐름

```text
main.dart
  ├─ 모바일 광고 SDK 초기화
  ├─ 로컬 로그인 세션 복원
  └─ ProviderContainer 생성
       ↓
TranslationScreen
  ├─ 언어·입력·결과 상태 관리
  ├─ GeminiTranslationService 호출
  ├─ HistoryNotifier에 결과 저장
  └─ 음성 / OCR / 대화 / 계정 / PRO 모달 연결
```

## 프로젝트 구조

```text
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   └── translation_constants.dart
│   ├── services/
│   │   └── gemini_translation_service.dart
│   └── theme/
│       └── app_theme.dart
└── features/
    ├── translation/
    ├── speech/
    ├── conversation/
    ├── camera_ocr/
    ├── history/
    ├── auth/
    ├── admin/
    └── premium/
```

Flutter가 생성한 플랫폼별 실행 코드는 `android/`, `ios/`, `web/`, `macos/`, `windows/`, `linux/`에 있습니다. 앱 아이콘 원본은 `assets/icon.png`, 의존성과 아이콘·스플래시 설정은 `pubspec.yaml`에서 관리합니다.

## 핵심 파일과 역할

| 파일 | 역할 |
| --- | --- |
| `lib/main.dart` | Flutter 바인딩과 모바일 광고 SDK를 초기화하고, 저장된 로그인 세션과 PRO 상태를 복원한 뒤 앱을 실행합니다. |
| `lib/core/constants/translation_constants.dart` | 지원하는 12개 언어의 코드, 한글·영문 이름, 국기 정보를 정의합니다. |
| `lib/core/services/gemini_translation_service.dart` | Gemini 또는 기본 번역 엔드포인트 호출, 응답 파싱, 실패 시 폴백을 담당합니다. |
| `lib/core/theme/app_theme.dart` | Material 3 색상, Noto Sans KR 글꼴, 라이트·다크 테마를 정의합니다. |
| `lib/features/translation/translation_screen.dart` | 메인 번역 화면입니다. Riverpod 상태, 번역 실행, 언어 교환, TTS, 각 기능 모달 진입을 조정합니다. |
| `lib/features/history/history_modal.dart` | 번역 기록 모델과 `HistoryNotifier`를 포함하며 로컬 저장, 검색, 즐겨찾기, 삭제를 처리합니다. |
| `lib/features/speech/speech_modal.dart` | 웹에서는 Web Speech API, 네이티브에서는 `speech_to_text`로 음성을 텍스트로 변환합니다. |
| `lib/features/conversation/conversation_modal.dart` | 방 생성·참여, 메시지 번역, 음성 입출력과 상대방 응답 시뮬레이션을 제공합니다. |
| `lib/features/camera_ocr/camera_ocr_modal.dart` | 카메라·갤러리 이미지 선택 UI와 OCR 처리 데모 및 샘플 문서를 제공합니다. |
| `lib/features/auth/auth_service.dart` | 로컬 사용자 목록, 로그인 세션, PRO 여부를 `SharedPreferences`에 저장하고 조회합니다. |
| `lib/features/auth/auth_modal.dart` | 회원가입, 로그인, 프로필, 로그아웃, 구독 취소 UI와 사용자 상태를 관리합니다. |
| `lib/features/admin/admin_dashboard_modal.dart` | 로컬에 저장된 회원 목록 조회와 회원 삭제 기능을 제공합니다. |
| `lib/features/premium/premium_state.dart` | 현재 사용자의 PRO 여부를 공유하는 Riverpod 상태를 정의합니다. |
| `lib/features/premium/paywall_bottom_sheet.dart` | PRO 혜택과 가격을 보여주고 로그인 또는 모의 결제 화면으로 연결합니다. |
| `lib/features/premium/mock_iap_dialog.dart` | 기기 인증 후 결제 성공 과정을 시뮬레이션하고 로컬 PRO 상태를 갱신합니다. |
| `lib/features/premium/ad_banner_widget.dart` | Android·iOS 무료 사용자에게 AdMob 테스트 배너를 표시합니다. 웹에서는 광고를 표시하지 않습니다. |
| `pubspec.yaml` | Flutter/Dart 버전, 패키지, 앱 아이콘과 네이티브 스플래시 설정을 관리합니다. |

## 상태와 로컬 데이터

앱 화면 상태는 Riverpod으로 관리합니다.

- `sourceLangProvider`, `targetLangProvider`: 원문과 번역 언어
- `inputTextProvider`, `translatedTextProvider`: 입력문과 번역 결과
- `isLoadingProvider`: 번역 요청 진행 상태
- `apiKeyProvider`: 실행 중 입력한 Gemini API 키
- `historyProvider`: 저장된 번역 기록
- `userProvider`, `isProUserProvider`: 로그인 사용자와 PRO 상태

영구 데이터는 서버가 아니라 기기의 `SharedPreferences`에 저장됩니다.

- `polyglot_translation_history`: 번역 기록과 즐겨찾기
- `mock_users_db`: 데모 사용자 목록
- `current_user_session`: 현재 로그인 사용자 ID

## 기술 스택

| 영역 | 사용 기술 |
| --- | --- |
| UI | Flutter, Material 3, Google Fonts |
| 상태 관리 | Riverpod |
| HTTP 통신 | `http` |
| 로컬 저장 | `shared_preferences` |
| 음성 | Web Speech API, `speech_to_text`, `flutter_tts` |
| 이미지 선택 | `image_picker` |
| 기기 인증 | `local_auth` |
| 광고 | Google Mobile Ads |
| 날짜 표시 | `intl` |

## 실행 방법

### 1. 준비 사항

- Flutter SDK
- Dart SDK `^3.11.5`
- Chrome 또는 지원되는 Flutter 실행 기기

설치 상태를 먼저 확인합니다.

```bash
flutter doctor
```

### 2. 패키지 설치

```bash
flutter pub get
```

### 3. 앱 실행

현재 소스는 `dart:js_interop`과 `package:web`을 직접 사용하므로 Chrome을 주 실행 대상으로 권장합니다.

```bash
flutter run -d chrome
```

Android·iOS·데스크톱 프로젝트 파일도 포함되어 있지만, 네이티브 빌드 전에 웹 전용 코드를 조건부 import로 분리하고 카메라·마이크·로컬 인증 권한을 플랫폼별로 설정해야 합니다.

### 4. 선택 사항: Gemini API 키 사용

앱 상단의 열쇠 아이콘을 누르고 Gemini API 키를 입력합니다. 키를 입력하지 않으면 기본 번역 엔드포인트로 동작합니다.

### 5. 아이콘과 스플래시 다시 생성

`assets/icon.png`을 변경했을 때만 실행합니다.

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## 현재 구현 범위와 제한 사항

이 저장소는 프로덕션 서비스가 아닌 기능 프로토타입입니다.

- OCR은 실제 문자 인식 엔진을 연결하지 않았습니다. 이미지 선택 후 샘플 결과를 반환합니다.
- 대화방 코드는 실제 서버나 다른 사용자와 연결되지 않습니다. 상대 메시지는 앱 내부에서 생성하는 시뮬레이션입니다.
- 인앱 결제는 실제 App Store·Google Play 결제가 아닌 모의 결제입니다.
- 회원 정보와 비밀번호는 로컬 저장소에 평문 형태로 저장됩니다. 운영 환경에서는 사용하면 안 됩니다.
- 관리자 계정 판별 로직도 데모용으로 클라이언트 코드에 포함되어 있습니다.
- 화면에 표시되는 무료 번역 25회 제한은 아직 실제 사용량으로 집계하거나 차단하지 않습니다.
- AdMob은 공식 테스트 ID를 사용합니다. 출시 전 실제 앱·광고 단위 ID와 개인정보 동의 흐름을 구성해야 합니다.
- 기본 번역 폴백은 비공식 무료 엔드포인트에 의존하므로 서비스 안정성이나 사용 한도가 보장되지 않습니다.
- 기본 `test/widget_test.dart`는 초기 카운터 템플릿이 남아 있어 현재 앱 구조에 맞게 교체해야 합니다.

## 다음 개발 단계

- Google ML Kit 또는 별도 OCR API 연동
- Firebase/Supabase 등 실제 인증·데이터베이스 적용
- WebSocket 또는 WebRTC 기반 실시간 대화방 구현
- 공식 인앱 결제와 구독 영수증 검증 추가
- API 키를 보호하는 백엔드 프록시 구축
- 웹·모바일 코드를 조건부 import로 분리하고 플랫폼별 테스트 추가
- 번역 사용량 집계와 무료·PRO 정책 실제 적용
- 하드코딩된 관리자 인증 제거 및 권한 검증 서버 이전

## 코드 품질 확인

정적 분석은 다음 명령으로 실행할 수 있습니다.

```bash
flutter analyze
```

현재 앱 구조에 맞는 위젯 테스트를 추가한 뒤에는 다음 명령을 사용할 수 있습니다.

```bash
flutter test --platform chrome
```
