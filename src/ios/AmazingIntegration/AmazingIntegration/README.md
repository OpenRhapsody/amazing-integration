# Amazing iOS Integration Guide

## 개요

iOS 앱에서 Amazing Quest를 WebView로 손쉽게 통합할 수 있는 솔루션입니다.

### 통합 방법
1. **소스 파일 복사**: `AmazingWebViewController.swift` 파일을 프로젝트에 추가
2. **즉시 사용 가능**: 복사한 클래스를 바로 사용하여 연동 완료

## Prerequisites

### 1. Amazing Quest URL
다음 URL을 사용하여 Amazing Quest 서비스에 접속합니다:
- **Production**: `https://quest.adrop.io/{channel}_{puid}`

### 2. 프로젝트 설정
- **iOS 최소 버전**: iOS 13.0+
- **Swift**: 5.0+
- **필수 프레임워크**: WebKit, AudioToolbox

## AmazingWebViewController 사용법

### 기본 사용 예제

```swift
import UIKit

// Amazing Quest URL로 WebViewController 생성
guard let url = URL(string: "https://quest.adrop.io/example-channel_p12345") else {
    return
}
let webViewController = AmazingWebViewController(url: url)
present(webViewController, animated: true)
```

### 주요 기능

#### 1. WebView 브릿지 기능
`AmazingWebViewController`는 웹과 네이티브 앱 간의 통신을 위한 브릿지 기능을 제공합니다.

| 브릿지 | 설명 | 동작 |
|--------|------|------|
| `close` | X 버튼 클릭 시 호출 | ViewController 닫기 |
| `haptic` | 사용자 인터랙션 피드백 | 햅틱 피드백 제공 |
| `getAppVersion` | 앱 버전 정보 요청 | 앱 및 SDK 버전 반환 |

#### 2. 햅틱 피드백 타입
어메이징 메인 뷰에서 스와이프 시, 햅틱 피드백을 지원합니다:

| Type | 설명 | iOS API |
|------|------|---------|
| `light` | 가벼운 터치 | UIImpactFeedbackGenerator(.light) |
| `medium` | 중간 터치 | UIImpactFeedbackGenerator(.medium) |
| `heavy` | 강한 터치 | UIImpactFeedbackGenerator(.heavy) |
| `selection` | 선택 변경 | UISelectionFeedbackGenerator() |
| `vibrate` | 진동 | AudioServicesPlaySystemSound() |
| `soft` | 부드러운 터치 (iOS 13+) | UIImpactFeedbackGenerator(.soft) |
| `rigid` | 단단한 터치 (iOS 13+) | UIImpactFeedbackGenerator(.rigid) |

#### 3. 링크 처리 로직
링크 클릭 시 자동으로 다음과 같이 처리됩니다:

- **Amazing 내부 링크**: WebView 내에서 이동
  - 도메인: `*.a2zing.io`, `*.adrop.io`
- **외부 링크**: 외부 브라우저(Safari)로 이동
- **앱 스킴**: 해당 앱으로 이동 (예: 결제 앱)

#### 4. 네트워크 에러 처리
- 5초 이내 페이지 로드 실패 시 알림 표시
- 네트워크 연결 확인 메시지 표시
- 확인 버튼 클릭 시 ViewController 자동 닫기

## 구현 세부사항

### Auto Layout 설정
WebView는 Safe Area를 고려하여 화면 전체를 채우도록 설정됩니다:

```swift
NSLayoutConstraint.activate([
    webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
    webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
])
```

## 문제 해결

### WebView가 로드되지 않는 경우
1. 네트워크 연결 상태 확인
2. Amazing URL이 올바른지 확인

### 햅틱 피드백이 동작하지 않는 경우
1. 디바이스가 햅틱을 지원하는지 확인 (iPhone 7 이상)
2. 디바이스 설정에서 햅틱 피드백이 활성화되어 있는지 확인
3. iOS 버전이 14.0 이상인지 확인 (비동기 브릿지 사용 시)

## 지원

추가 문의사항이나 이슈가 있으시면 Amazing 기술 지원팀에 문의해주세요.
