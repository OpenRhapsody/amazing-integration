# Amazing Integration Guide

## 📱 모바일 WebView 연동
iOS/Android 앱에서 Amazing Quest를 간편하게 통합할 수 있습니다.

- **[iOS 연동 가이드](src/ios/AmazingIntegration/AmazingIntegration/README.md)** - Swift 기반 WebView 통합
- **[Android 연동 가이드](src/android/README.md)** - Kotlin/Java 기반 WebView 통합

## 🔌 리워드 API 연동
사용자가 퀘스트를 완료하면 Amazing 서버에서 매체사 서버로 콜백 API를 호출합니다. 요청을 받은 매체 서버는 다음 작업을 수행합니다:
1. **리워드 지급** - 사용자에게 포인트/크레딧 지급
2. **이력 관리** - 퀘스트 완료 기록 저장
3. **보안 검증** - HMAC 서명으로 요청 무결성 확인

## Prerequisites

매체사에서 퀘스트 완료 API 연동을 위해 다음 사항을 준비해주세요:

### 1. API 엔드포인트 준비
퀘스트 완료 콜백을 받을 수 있는 API 엔드포인트를 준비해주세요.
- **HTTP 메서드**: POST
- **Content-Type**: application/json
- **예시 URL**: `https://your-server.com/quest/complete`

### 2. HMAC 비밀키 설정
API 요청의 무결성과 인증을 위해 HMAC 비밀키를 설정해야 합니다.

**테스트용 비밀키** (개발/테스트 환경):
```
its_amazing_secret
```

**프로덕션 비밀키**:
실제 연동 진행 과정에서 어메이징에서 안전한 비밀키를 생성하여 제공해드립니다.

**비밀키 생성 방법** (참고용):
```bash
# OpenSSL 사용 (권장)
openssl rand -base64 32

# 결과 예시: "Kv7QW+2f1ctxtw7iuQcaKXuP4tEWmA+TxQ7nCqpQQ8k="
```

## API Callback from Amazing

사용자가 퀘스트를 완료하면, **어메이징 서버에서 매체사 서버로** 다음과 같은 HTTP 요청을 보냅니다.

**요청 방향**: 어메이징 서버 → 매체사 서버  
**HTTP 메서드**: POST  
**엔드포인트**: 매체사에서 제공하는 URL

> 💡 **HMAC 서명 생성 및 검증에 대한 자세한 내용은 [Appendix: HMAC Authentication](#appendix-hmac-authentication)을 참고하세요.**

### 요청 헤더
```
Content-Type: application/json
X-Amazing-Timestamp: HMAC 생성 시간 (milliseconds)
X-Amazing-Signature: HMAC 서명
```

### 요청 본문

| Name | Type | Description |
|------|------|-------------|
| snapshot* | string | 퀘스트 완료 식별자 (최대 36자) |
| uid* | string | 사용자 식별자 (최대 36자) |
| quest* | string | 퀘스트 식별자 (최대 36자) |
| title* | string | 퀘스트 제목 (최대 255자) |
| reward* | number | 사용자에게 지급할 리워드 금액 |

*필수 필드

### 요청 본문 예시
```json
{
  "snapshot": "507f1f77bcf86cd799439011",
  "uid": "507f191e810c19729de860ea",
  "quest": "507f1f77bcf86cd799439012",
  "title": "어메이징 마스크팩 구매하기",
  "reward": 1000
}
```

## API Response to Amazing

매체사 서버에서 퀘스트 완료 요청을 받으면 다음 단계를 순서대로 처리해주세요.

### 1. HMAC 서명 검증

먼저 요청의 무결성을 확인하기 위해 HMAC 서명을 검증합니다.

> 💡 **HMAC 서명 검증에 대한 자세한 구현 방법은 [HmacUtil 사용법](#hmacutil-사용법)을 참고하세요.**

```typescript
import { HmacUtil } from './hmac.util'

const isValid = HmacUtil.verifySignature(
    'POST',
    '/quest/complete',
    '', // 쿼리 스트링
    requestBody,
    req.headers['x-amazing-signature'],
    parseInt(req.headers['x-amazing-timestamp']),
    'its_amazing_secret'
)

if (!isValid) {
    return res.status(400).json({ code: 'HMAC_AUTH_ERROR' })
}
```

### 2. 요청 데이터 처리

HMAC 검증이 통과한 경우, 다음 단계들을 수행합니다:

#### 2-1. snapshot 중복 확인
- `snapshot`은 유니크한 퀘스트 완료 식별자입니다. 중복 처리를 방지하기 위해 이전에 처리된 적이 있는지 확인해야 합니다.

#### 2-2. 사용자 존재 확인
- `uid`는 매체사의 사용자 식별자입니다. 실제로 존재하는 사용자인지 확인해야 합니다.

#### 2-3. 퀘스트 정보 활용
- `quest`: 퀘스트 식별자 (필요한 경우 저장하여 활용)
- `title`: 퀘스트 제목 (사용자 알림이나 이력 관리에 활용)

#### 2-4. 리워드 지급
- `reward`는 어메이징 기준으로 사용자에게 지급해야 하는 크레딧(원화) 보상입니다. 매체사에서 자체 포인트로 지급하고 싶은 경우, 환율이나 비율을 확인하여 알맞은 포인트를 직접 지급하면 됩니다.

### 3. 응답 반환

모든 처리가 완료된 후, **반드시 다음 형식으로 응답**해주세요.

### 성공 응답 (HTTP 200)
```json
{
  "result": true
}
```

### 에러 응답 (HTTP 400)

에러가 발생한 경우 HTTP 상태 코드 400으로 응답해주세요.

```json
{
  "code": "HMAC_AUTH_ERROR"
}
```

**에러 코드 목록**
```typescript
export type ExceptionCodeType =
    | 'HMAC_AUTH_ERROR'     // HMAC 인증 오류
    | 'INVALID_PARAMS'      // 파라미터 오류
    | 'USER_NOT_FOUND'      // 유효하지 않은 사용자 ID
    | 'DUPLICATED_SNAPSHOT' // 중복 콜백
    | 'UNCATCHED'           // 기타 오류
```

## Appendix: HMAC Authentication

### 서명 생성 과정

HMAC 서명은 다음 구성 요소들을 순서대로 조합하여 생성합니다:

1. **HTTP Method** (대문자)
2. **URI Path**
3. **HMAC Timestamp** (milliseconds)
4. **Sorted Query String** (알파벳 순 정렬, 없으면 빈 문자열)
5. **Payload SHA256 Hash**

#### 서명 생성 과정

위 구성 요소들을 순서대로 개행문자(`\n`)로 연결하여 하나의 메시지를 만든 후, HMAC SHA-256으로 서명하고 Base64로 인코딩합니다.

생성된 서명은 다음 헤더에 포함됩니다:
```
X-Amazing-Timestamp: 1704067200000
X-Amazing-Signature: <generated_signature>
```

### HmacUtil 사용법

이 패키지에서 제공하는 [`HmacUtil`](src/typescript/hmac.util.ts) 클래스를 사용하여 쉽게 HMAC 서명을 생성하고 검증할 수 있습니다.

#### 기본 사용법

```typescript
import { HmacUtil } from './hmac.util'

// 1. 서명 생성
const timestamp = Date.now()
const signature = HmacUtil.generateSignature(
    'POST',
    '/quest/complete',
    timestamp,
    '', // 쿼리 스트링 (없으면 빈 문자열)
    {
        snapshot: "507f1f77bcf86cd799439011",
        uid: "507f191e810c19729de860ea",
        quest: "507f1f77bcf86cd799439012",
        title: "어메이징 마스크팩 구매하기",
        reward: 1000
    },
    'its_amazing_secret'
)

// 2. 서명 검증
const isValid = HmacUtil.verifySignature(
    'POST',
    '/quest/complete',
    '', // 쿼리 스트링
    requestBody, // 요청 본문
    signature, // X-Amazing-Signature 헤더값
    timestamp, // X-Amazing-Timestamp 헤더값
    'its_amazing_secret'
)

if (isValid) {
    console.log('✅ HMAC 검증 성공')
    // 퀘스트 완료 처리 로직
} else {
    console.log('❌ HMAC 검증 실패')
    // 에러 응답
}
```

#### 주요 메서드

- `generateSignature()`: HMAC 서명 생성
- `verifySignature()`: HMAC 서명 검증 (타임스탬프 만료 검사 포함)
- `isExpired()`: 타임스탬프 만료 여부 확인

#### 테스트 실행

```bash
# 의존성 설치
yarn install

# 테스트 실행 (사용법 예제 포함)
yarn test

# 타입 검사
yarn typecheck
```

## Appendix: Python Implementation

Python 개발자를 위한 HMAC 유틸리티 구현입니다.

```python
import hashlib
import hmac
import json
import time
from base64 import b64encode, b64decode
from urllib.parse import parse_qs, urlencode


class HmacUtil:
    """HMAC utility for Amazing API authentication"""
    
    @staticmethod
    def generate_signature(
        method: str,
        uri_path: str,
        timestamp: int,
        query_string: str,
        payload: dict,
        secret_key: str
    ) -> str:
        """Generate HMAC signature for API request"""
        # Convert payload to JSON string and create SHA256 hash
        json_payload = json.dumps(payload, separators=(',', ':'), ensure_ascii=False)
        payload_hash = hashlib.sha256(json_payload.encode('utf-8')).hexdigest()
        
        # Sort query string alphabetically
        sorted_query = ''
        if query_string:
            # Parse query string and sort by key
            parsed = parse_qs(query_string, keep_blank_values=True)
            # Flatten lists and sort keys
            flattened = []
            for key in sorted(parsed.keys()):
                for value in parsed[key]:
                    flattened.append((key, value))
            sorted_query = urlencode(flattened)
        
        # Create message to sign (separated by newlines)
        message_to_sign = '\n'.join([
            method.upper(),
            uri_path,
            str(timestamp),
            sorted_query,
            payload_hash
        ])
        
        # Generate HMAC SHA-256 signature
        signature = hmac.new(
            secret_key.encode('utf-8'),
            message_to_sign.encode('utf-8'),
            hashlib.sha256
        ).digest()
        
        return b64encode(signature).decode('utf-8')
    
    @staticmethod
    def verify_signature(
        method: str,
        uri_path: str,
        query_string: str,
        payload: dict,
        signature: str,
        timestamp: int,
        secret_key: str
    ) -> bool:
        """Verify HMAC signature with timestamp validation"""
        try:
            # Check if timestamp is expired (2 minutes by default)
            if HmacUtil.is_expired(timestamp):
                return False
            
            # Generate expected signature using same method
            expected_signature = HmacUtil.generate_signature(
                method,
                uri_path,
                timestamp,
                query_string,
                payload,
                secret_key
            )
            
            # Safe comparison to prevent timing attacks
            return hmac.compare_digest(signature, expected_signature)
        
        except Exception:
            return False
    
    @staticmethod
    def is_expired(timestamp: int, tolerance_ms: int = 120000) -> bool:
        """Check if timestamp is expired (requests expire after 2 minutes by default)"""
        now = int(time.time() * 1000)
        diff = now - timestamp
        
        # Reject future timestamps or requests older than tolerance
        return diff < 0 or diff > tolerance_ms


# Usage Example
if __name__ == "__main__":
    # Test data
    payload = {
        "snapshot": "507f1f77bcf86cd799439011",
        "uid": "507f191e810c19729de860ea", 
        "quest": "507f1f77bcf86cd799439012",
        "title": "어메이징 마스크팩 구매하기",
        "reward": 1000
    }
    
    secret_key = "its_amazing_secret"
    timestamp = int(time.time() * 1000)
    
    # Generate signature
    signature = HmacUtil.generate_signature(
        "POST",
        "/quest/complete",
        timestamp,
        "",
        payload,
        secret_key
    )
    
    print(f"Generated signature: {signature}")
    
    # Verify signature
    is_valid = HmacUtil.verify_signature(
        "POST",
        "/quest/complete", 
        "",
        payload,
        signature,
        timestamp,
        secret_key
    )
    
    print(f"Signature valid: {is_valid}")
```
