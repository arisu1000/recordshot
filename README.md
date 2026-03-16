# RecordShot

macOS 메뉴바에서 바로 실행하는 스크린샷 · 화면 녹화 · 이미지 편집 유틸리티입니다.

## 주요 기능

| 기능 | 설명 |
|------|------|
| 전체 화면 스크린샷 | 현재 디스플레이 전체를 캡처 |
| 영역 선택 스크린샷 | 드래그로 원하는 영역만 캡처 |
| 화면 녹화 | SCStream 기반 MP4 녹화, 자동 중지 옵션 |
| 이미지 편집 | 캡처 직후 주석 편집 창 자동 오픈 |
| 글로벌 단축키 | 다른 앱 사용 중에도 단축키로 즉시 실행 |
| 클립보드 복사 | 편집 후 원하는 시점에 직접 복사 |

### 이미지 편집 도구

- **사각형** — 드래그로 강조 사각형 그리기
- **원형** — 드래그로 강조 타원 그리기
- **화살표** — 드래그로 방향 화살표 삽입
- **텍스트** — 클릭 위치에 텍스트 입력
- **블러** — 드래그 영역에 모자이크(가우시안 블러) 처리

색상, 선 두께, 폰트 크기 실시간 조절 / 되돌리기 지원

## 요구사항

- macOS 12.3 이상
- Xcode 15 이상 (빌드 시)
- 화면 기록 권한 (시스템 설정 → 개인정보 보호 및 보안 → 화면 기록)
- 손쉬운 사용 권한 (글로벌 단축키 사용 시)

## 빌드 방법

```bash
# Xcode에서 열기
open RecordShot/RecordShot.xcodeproj
```

1. **Signing & Capabilities** 탭에서 Team 설정 (Apple ID 필요)
2. `Cmd+R` 로 빌드 및 실행

또는 커맨드라인:

```bash
cd RecordShot
xcodebuild -project RecordShot.xcodeproj -scheme RecordShot -configuration Debug build
```

## 사용법

1. 앱 실행 → 메뉴바 우측에 **카메라 아이콘** 등장 (Dock 아이콘 없음)
2. 아이콘 클릭 → 팝오버 메뉴

| 동작 | 방법 |
|------|------|
| 전체 스크린샷 | 팝오버 → Screenshot 버튼 또는 `⌘⇧3` |
| 영역 스크린샷 | 팝오버 → Region 버튼 또는 `⌘⇧4` |
| 화면 녹화 시작/중지 | 팝오버 → Record 버튼 또는 `⌘⇧5` |
| 설정 | 팝오버 → Settings |

### 캡처 후 편집 흐름

```
캡처 → 편집 창 자동 오픈
       ├── 주석 추가 (사각형/원/화살표/텍스트/블러)
       ├── 완료 → ~/Desktop에 PNG 저장
       ├── 클립보드에 복사 → 저장 + 클립보드 복사
       └── 취소 → 원본 파일 유지
```

### 권한 설정

처음 실행 시 **화면 기록 권한** 팝업이 뜨면 허용을 클릭하거나,
시스템 설정 → 개인정보 보호 및 보안 → 화면 기록 → RecordShot 토글 ON

## 프로젝트 구조

```
RecordShot/
├── RecordShot.xcodeproj/
└── RecordShot/
    ├── App/
    │   ├── RecordShotApp.swift        # @main 진입점
    │   └── AppDelegate.swift          # 앱 초기화, 권한 요청
    ├── MenuBar/
    │   ├── MenuBarController.swift    # NSStatusItem + NSPopover
    │   └── MenuBarView.swift          # 팝오버 SwiftUI 뷰
    ├── Capture/
    │   ├── ScreenCaptureManager.swift # 스크린샷/녹화 핵심 로직
    │   ├── RecordingSession.swift     # AVAssetWriter MP4 녹화
    │   ├── RegionSelector.swift       # 영역 선택 오버레이 창
    │   └── CapturePreviewPanel.swift  # 캡처 후 미리보기 패널
    ├── Editor/
    │   ├── AnnotationModel.swift      # 주석 데이터 모델
    │   ├── AnnotationCanvasView.swift # NSView 드로잉 캔버스
    │   ├── ImageEditorView.swift      # 편집기 SwiftUI 뷰
    │   └── ImageEditorWindow.swift    # 편집기 NSWindow 래퍼
    ├── HotKeys/
    │   └── HotKeyManager.swift        # CGEventTap 글로벌 단축키
    ├── Settings/
    │   ├── AppSettings.swift          # UserDefaults 설정 모델
    │   └── SettingsView.swift         # 설정 SwiftUI 뷰
    └── Utilities/
        └── ClipboardManager.swift     # NSPasteboard 헬퍼
```

## 기술 스택

- **언어**: Swift 5.9
- **UI**: SwiftUI + AppKit (NSStatusItem, NSWindow, NSView)
- **캡처**: ScreenCaptureKit (macOS 12.3+)
- **녹화**: AVFoundation (AVAssetWriter, H.264)
- **이미지 처리**: CoreImage (CIGaussianBlur), CoreGraphics
- **단축키**: CGEventTap
- **Deployment Target**: macOS 12.3

## 저장 위치 및 파일 형식

| 종류 | 형식 | 기본 저장 위치 |
|------|------|--------------|
| 스크린샷 | PNG | ~/Desktop |
| 녹화 | MP4 (H.264) | ~/Desktop |

설정에서 저장 위치 변경 가능

## 라이선스

MIT License
