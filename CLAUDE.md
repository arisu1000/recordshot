# RecordShot — Claude 작업 가이드

## 프로젝트 개요

macOS 메뉴바 스크린샷/녹화/편집 앱. Dock 아이콘 없이 메뉴바에서만 동작.

## 빌드 및 실행

```bash
cd RecordShot

# 빌드 (코드서명 없이 로컬 테스트)
xcodebuild -project RecordShot.xcodeproj -scheme RecordShot -configuration Debug build

# 실행
open $(find ~/Library/Developer/Xcode/DerivedData/RecordShot-*/Build/Products/Debug -name "RecordShot.app" -type d | head -1)

# 재시작
pkill -x RecordShot; sleep 1; open $(find ~/Library/Developer/Xcode/DerivedData/RecordShot-*/Build/Products/Debug -name "RecordShot.app" -type d | head -1)

# TCC 권한 리셋 (서명이 바뀌어 권한이 끊겼을 때)
tccutil reset ScreenCapture com.recordshot.app
```

## 핵심 설계 결정

### 권한 & 서명
- `RecordShot.entitlements`에서 `app-sandbox = false` — 미서명 빌드 시 샌드박스가 TCC를 막기 때문
- 서명 있는 빌드(Xcode Automatic)를 사용하면 샌드박스 재활성화 가능
- 매 ad-hoc 빌드마다 TCC 서명이 바뀌어 화면 기록 권한이 초기화됨 → Xcode 자동 서명 권장

### 좌표계 주의사항
- `RegionSelector` (NSView, `isFlipped = true`) → **top-left origin** 좌표 반환
- `ScreenCaptureManager.takeRegionScreenshot` → `config.sourceRect`에 그대로 사용 (이미 top-left)
- **이중 Y-flip 금지**: RegionSelector에서 이미 한 번 뒤집으므로 ScreenCaptureManager에서 다시 뒤집지 말 것
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

글로벌 단축키는 손쉬운 사용(Accessibility) 권한 필요.

## 알려진 제약

- 글로벌 단축키(`⌘⇧3`, `⌘⇧4`)는 macOS 기본 스크린샷과 충돌 가능 — 시스템 설정에서 비활성화 필요
- 녹화 기능은 오디오 미포함 (macOS 13+ 에서 `capturesAudio` 지원이나 현재 비활성)
- 멀티 디스플레이 환경에서 `content.displays.first`만 사용 — 향후 디스플레이 선택 UI 추가 필요

## 의존성

외부 라이브러리 없음. 모두 Apple 퍼스트파티 프레임워크 사용:
- ScreenCaptureKit, AVFoundation, CoreImage, CoreGraphics
- SwiftUI, AppKit, UserNotifications
