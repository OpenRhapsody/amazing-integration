# Amazing Quest Android Integration

## 개요
Amazing Quest(quest.adrop.io) 플랫폼을 Android 앱에 통합하기 위한 WebView 기반 예제 애플리케이션입니다. SDK 없이 순수 WebView를 사용하여 구현되었습니다.

### 통합 방법
**소스 파일 복사**: `AmazingWebViewActivity.kt` 파일을 프로젝트에 추가
**즉시 사용 가능**: 복사한 클래스를 바로 사용하여 연동 완료

## 주요 기능

### 1. WebView 통합
- **URL**: `https://quest.adrop.io/{channel}_{puid}` 로드
- JavaScript 활성화
- DOM 스토리지 지원
- 미디어 자동 재생 지원

### 2. URL 라우팅
- **내부 처리**: `adrop.io` 도메인 (서브도메인 포함)
- **외부 브라우저**: 기타 모든 URL
- **딥링크 지원**: `intent://` URL 처리
- **앱 설치 연동**: 미설치 앱의 경우 Play Store 연결

### 3. JavaScript 브리지
```javascript
// 웹에서 앱 버전 정보 가져오기
const version = await window.bridge.callHandler('getAppVersion', 'getAppVersion');
// 반환값: "android/1.3.20/1.0.0"

// 웹에서 앱 닫기
window.Android.close();
```

### 4. 파일 업로드
- 웹 폼의 파일 선택 기능 지원
- ActivityResultContracts를 사용한 현대적인 파일 선택 구현

### 5. 프로그레스 인디케이터
- 페이지 로딩 중 로딩 스피너 표시
- 로딩 완료 시 자동 숨김

### 6. 뒤로 가기 처리
- WebView 히스토리가 있으면 웹 페이지 뒤로 가기
- 히스토리가 없을 때만 앱 종료

### 7. 네트워크 에러 처리
- 5초 이내 페이지 로드 실패 시 알림 표시
- 네트워크 연결 확인 메시지 표시
- AmazingWebViewActivity 자동 닫기


## 기술 사양

### 빌드 설정
- **Compile SDK**: 35
- **Min SDK**: 24 (Android 7.0)
- **Target SDK**: 35
- **Kotlin JVM Target**: 11

### WebView 설정
```kotlin
webSettings.apply {
    javaScriptEnabled = true
    domStorageEnabled = true
    mediaPlaybackRequiresUserGesture = false
    allowFileAccess = true
    allowContentAccess = true
    textZoom = 100
}
```

### 권한
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### 의존성
```kotlin
dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.activity)
    implementation(libs.androidx.constraintlayout)
}
```

## 구현 상세

### 도메인 검증
```kotlin
// adrop.io 및 모든 서브도메인 검증
val isAdropHost = Regex("""^([a-zA-Z0-9-]+\.)*adrop\.io$""").matches(host)
```

### JavaScript 인터페이스
1. **Android Interface**: 앱 제어 기능
   ```kotlin
   @JavascriptInterface
   fun close() {
       finish()
   }
   
   @JavascriptInterface
   fun callHandler(requestId: String, sig: String) {
       when (sig) {
           "getAppVersion" -> {
               val version = "android/${sdkVersion}/${appVersion}"
               // JavaScript로 결과 반환
           }
       }
   }
   ```

2. **JavaScript Bridge**: Promise 기반 양방향 통신
   ```javascript
   window.bridge = {
       callHandler: function(name, sig, payload) {
           return new Promise((resolver, reject) => {
               // Android 네이티브 메서드 호출
               window.Android.callHandler(requestId, sig)
           })
       }
   }
   ```

### Edge-to-Edge 디스플레이
- 시스템 바 아래까지 확장되는 전체 화면 UI
- WindowInsetsCompat을 사용한 적절한 패딩 처리

## 사용 방법

1. Android Studio에서 프로젝트 열기
2. Gradle 동기화 실행
3. 앱 빌드 및 실행
   ```bash
   gradle assembleDebug
   ```

## 주의사항

- WebView 기반이므로 인터넷 연결 필수
- JavaScript가 활성화되어 있어야 정상 작동
- Android 7.0 (API 24) 이상 지원
- `forceDark` 설정은 Android Q(API 29) 이상에서 deprecated

## 버전 정보
- SDK 버전: 1.3.20
- 앱 버전: 1.0.0
- 반환 형식: "android/SDK_VERSION/APP_VERSION"
