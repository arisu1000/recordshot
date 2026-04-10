# RecordShot — Claude 작업 가이드

## 프로젝트 개요

macOS 메뉴바 스크린샷/녹화/편집 앱. Dock 아이콘 없이 메뉴바에서만 동작.

## 빌드 및 실행

Xcode 없이 Swift CLI Tools만으로 빌드 가능 (SPM 기반).

```bash
# 빌드 + .app 번들 생성 (release)
./build_app.sh

# 빌드 + .app 번들 생성 (debug)
./build_app.sh debug

# 실행
open RecordShot.app

# 재시작
pkill -x RecordShot; sleep 1; open RecordShot.app

# 테스트
swift test

# TCC 권한 리셋 (서명이 바뀌어 권한이 끊겼을 때)
tccutil reset ScreenCapture com.recordshot.app
```

## 핵심 설계 결정

### 권한 & 서명
- `RecordShot.entitlements`에서 `app-sandbox = false` — 미서명 빌드 시 샌드박스가 TCC를 막기 때문
- 서명 있는 빌드(Xcode Automatic)를 사용하면 샌드박스 재활성화 가능
- 매 ad-hoc 빌드마다 TCC 서명이 바뀌어 화면 기록 권한이 초기화됨 → Xcode 자동 서명 권장

### 좌표계 주의사항
- `RegionOverlayView` (NSView 기본값, `isFlipped = false`) → 마우스 이벤트는 bottom-left origin
- `mouseUp`에서 Y-flip 수행 → `onRegionSelected`에 **top-left origin** 좌표 전달
- `ScreenCaptureManager.takeRegionScreenshot` → `CGWindowListCreateImage(region, ...)` 사용. top-left origin 포인트 좌표를 직접 전달하므로 좌표 변환 불필요
- `NSImage` 생성 시 반드시 논리 포인트 크기 사용 (`image.width / backingScaleFactor`) — pixel 크기로 만들면 Retina에서 2배 크게 보임

### 비동기 패턴
- `ScreenCaptureManager` → `@MainActor` class
- `RegionSelector.selectRegion()` → `static var current`로 강한 참조 유지 필수 (없으면 ARC가 즉시 해제해 콜백 미실행)
- `ImageEditorWindow.onComplete` 콜백 후 창 닫기는 반드시 `DispatchQueue.main.async` 로 지연 — 버튼 액션 실행 중 창 해제 방지

### NSImage 크기
```swift
// ✅ 올바른 방법 — 논리 포인트
let scale = NSScreen.main?.backingScaleFactor ?? 1.0
NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width / scale, height: cgImage.height / scale))

// ❌ 잘못된 방법 — 픽셀 크기 그대로 사용
NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
```

## 주요 파일 역할

| 파일 | 역할 |
|------|------|
| `ScreenCaptureManager.swift` | 스크린샷/녹화 진입점. 캡처 후 `ImageEditorWindow.open()` 호출 |
| `RegionSelector.swift` | 전체화면 투명 오버레이. `selectRegion()` async 함수로 CGRect 반환 |
| `AnnotationCanvasNSView` | 드로잉 캔버스 (isFlipped=true). 주석 저장 및 `renderToFinalImage()` 담당 |
| `ImageEditorWindow.swift` | NSWindow 생명주기 관리. onComplete 콜백 체인 처리 |
| `CapturePreviewPanel.swift` | 현재 미사용(편집창 직행). 향후 필요시 재활성화 가능 |
| `AppSettings.swift` | UserDefaults 설정 모델. `LaunchAction` enum으로 앱 시작 시 동작 설정 |
| `AppDelegate.swift` | 앱 초기화, 권한 요청, `executeLaunchAction()`으로 시작 시 동작 실행 |

## 편집기 좌표계

```
AnnotationCanvasNSView (isFlipped = true)
  └── 마우스 좌표: top-left origin (Y 아래로 증가)
  └── 주석 저장: top-left origin

renderToFinalImage() 내부:
  1. blur 처리: CIImage (bottom-left) → Y flip 적용
  2. 나머지 주석: NSAffineTransform으로 top-left → bottom-left 변환 후 NSImage에 그리기
```

## 단축키 (기본값)

| 단축키 | 동작 |
|--------|------|
| `⌘⇧3` | 전체 스크린샷 |
| `⌘⇧4` | 영역 스크린샷 |
| `⌘⇧5` | 녹화 시작/중지 |
| `⌘⇧6` | 영역 녹화 |

글로벌 단축키는 손쉬운 사용(Accessibility) 권한 필요.

### 녹화 안정성
- `RecordingSession.stream(_:didOutputSampleBuffer:of:)` 에서 반드시 `SCFrameStatus.complete`만 처리 — idle/blank 버퍼를 `AVAssetWriter`에 append하면 writer가 에러 상태에 빠짐

### 실행 시 동작 (Launch Action)
- `AppSettings.launchAction`으로 앱 시작 시 자동 실행할 동작 설정 (없음/전체 스크린샷/영역 스크린샷/전체 녹화/영역 녹화)
- `AppDelegate.executeLaunchAction()`에서 300ms 지연 후 실행 — UI 초기화 완료 대기

## 알려진 제약

- 글로벌 단축키(`⌘⇧3`, `⌘⇧4`)는 macOS 기본 스크린샷과 충돌 가능 — 시스템 설정에서 비활성화 필요
- 녹화 기능은 오디오 미포함 (macOS 13+ 에서 `capturesAudio` 지원이나 현재 비활성)
- 멀티 디스플레이 환경에서 `content.displays.first`만 사용 — 향후 디스플레이 선택 UI 추가 필요
- 매 ad-hoc 빌드마다 서명이 바뀌어 화면 기록 + 손쉬운 사용 권한 재설정 필요

## 의존성

외부 라이브러리 없음. 모두 Apple 퍼스트파티 프레임워크 사용:
- ScreenCaptureKit, AVFoundation, CoreImage, CoreGraphics
- SwiftUI, AppKit, UserNotifications
