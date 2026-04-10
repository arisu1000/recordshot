# RecordShot

> macOS 메뉴바 스크린샷 & 화면 녹화 & 이미지 편집 유틸리티

Dock 아이콘 없이 메뉴바에서만 동작하는 가볍고 빠른 스크린샷/녹화 도구입니다.
캡처 후 바로 주석 편집 창이 열리며, 저장 또는 클립보드 복사를 선택할 수 있습니다.

---

## 주요 기능

| 기능 | 단축키 | 설명 |
|------|--------|------|
| 전체 화면 스크린샷 | `⌘⇧3` | 현재 디스플레이 전체 캡처 |
| 영역 선택 스크린샷 | `⌘⇧4` | 드래그로 원하는 영역만 캡처 |
| 전체 화면 녹화 | `⌘⇧5` | 화면 녹화 시작/중지 |
| 영역 녹화 | `⌘⇧6` | 선택 영역만 녹화 |
| 이미지 편집 | — | 캡처 직후 주석 편집 창 자동 오픈 |
| 녹화 포맷 선택 | — | MP4 / MOV / GIF 지원 |
| 실행 시 동작 | — | 앱 시작 시 자동 실행할 동작 설정 |
| 글로벌 단축키 | — | 다른 앱 사용 중에도 즉시 실행 |
| 클립보드 복사 | — | 편집 완료 후 바로 붙여넣기 가능 |
| 한국어 / 영어 지원 | — | 시스템 언어 자동 적용 |

### 이미지 편집 도구

캡처 후 자동으로 편집 창이 열립니다.

- **사각형** — 드래그로 강조 박스 그리기
- **원형** — 드래그로 타원 그리기
- **화살표** — 방향 화살표 삽입
- **텍스트** — 원하는 위치에 텍스트 입력
- **블러** — 민감한 영역에 모자이크 처리

색상·선 두께·폰트 크기 실시간 조절, 되돌리기(Undo) 지원

## 요구사항

- **macOS 13.0 (Ventura)** 이상
- **화면 기록 권한** — 시스템 설정 → 개인정보 보호 및 보안 → 화면 기록
- **손쉬운 사용 권한** — 글로벌 단축키(`⌘⇧3` / `⌘⇧4`) 사용 시 필요

## 설치 방법

### 바이너리 (권장)

1. [Releases](https://github.com/arisu1000/recordshot/releases) 페이지에서 최신 `RecordShot.zip` 다운로드
2. 압축 해제 후 `RecordShot.app`을 `Applications` 폴더로 이동
3. 처음 실행 시 우클릭 → **열기** (Gatekeeper 우회)
4. 온보딩 안내에 따라 **화면 기록** 및 **손쉬운 사용** 권한 허용

### 소스에서 빌드

Xcode 없이 Swift CLI Tools만으로 빌드 가능합니다 (SPM 기반).

```bash
git clone https://github.com/arisu1000/recordshot.git
cd recordshot
./build_app.sh          # release 빌드
open RecordShot.app
```

## 사용법

1. 앱 실행 → 첫 실행 시 권한 설정 안내 창 표시
2. 메뉴바 우측에 **카메라 아이콘** 등장
3. 아이콘 클릭 → 팝오버 메뉴에서 원하는 동작 선택

```
캡처 → 편집 창 자동 오픈
       ├── 주석 추가 (사각형 / 원 / 화살표 / 텍스트 / 블러)
       ├── [완료]           → PNG 파일 저장
       ├── [클립보드에 복사] → 저장 + 클립보드 복사
       └── [취소]           → 편집 취소, 원본 파일 유지
```

### 저장 위치

| 종류 | 형식 | 기본 위치 |
|------|------|---------|
| 스크린샷 | PNG | `~/Desktop` |
| 녹화 | MP4 / MOV / GIF | `~/Desktop` |

설정(Settings)에서 저장 위치 변경 가능

## 프로젝트 구조

```
RecordShot/
├── Package.swift               # SPM 프로젝트 정의
├── build_app.sh                # .app 번들 빌드 스크립트
└── RecordShot/
    ├── App/
    │   ├── RecordShotApp.swift         # @main 진입점
    │   ├── AppDelegate.swift           # 앱 초기화, 권한 요청
    │   └── OnboardingWindow.swift      # 첫 실행 권한 안내 온보딩
    ├── MenuBar/
    │   ├── MenuBarController.swift     # NSStatusItem + NSPopover
    │   └── MenuBarView.swift           # 팝오버 SwiftUI 뷰
    ├── Capture/
    │   ├── ScreenCaptureManager.swift  # 스크린샷 핵심 로직
    │   ├── RecordingSession.swift      # 녹화 세션 (MP4/MOV/GIF)
    │   ├── RegionSelector.swift        # 영역 선택 오버레이
    │   └── RecordingRegionIndicator.swift # 녹화 영역 표시기
    ├── Editor/
    │   ├── AnnotationModel.swift       # 주석 데이터 모델
    │   ├── AnnotationCanvasView.swift  # NSView 드로잉 캔버스
    │   ├── ImageEditorView.swift       # 편집기 SwiftUI 뷰
    │   └── ImageEditorWindow.swift     # 편집기 NSWindow
    ├── HotKeys/
    │   └── HotKeyManager.swift         # CGEventTap 글로벌 단축키
    ├── Settings/
    │   ├── AppSettings.swift           # UserDefaults 설정 모델
    │   └── SettingsView.swift          # 설정 SwiftUI 뷰
    ├── Utilities/
    │   ├── ClipboardManager.swift      # NSPasteboard 헬퍼
    │   └── LaunchAgentHelper.swift     # 로그인 시 자동 실행 관리
    └── Assets.xcassets/                # 앱 아이콘 및 리소스
```

## 기술 스택

- **언어**: Swift 5.9
- **UI**: SwiftUI + AppKit
- **캡처**: ScreenCaptureKit
- **이미지 처리**: CoreImage, CoreGraphics
- **단축키**: CGEventTap (Carbon)
- **빌드 시스템**: Swift Package Manager (Xcode 불필요)
- **Deployment Target**: macOS 13.0+
- **외부 의존성**: 없음 (All Apple first-party frameworks)

## 라이선스

MIT License — 자세한 내용은 [LICENSE](LICENSE) 파일 참고
