# CLAUDE.md — effortless_launcher

## 인앱결제(IAP) 미구현 — 향후 작업 필요

### 현황
- 후원 다이얼로그 `lib/donation_dialog.dart` 는 **UI만 존재**하고 실제 결제 기능 없음
- 진입: 검색 페이지 "Recently Used" 헤더와 Hot zone "Frequently Used" 헤더 우측 `$` 아이콘 버튼
- `Donate` 버튼 탭 시 단순히 "Coming soon" 스낵바 표시
- 라디오 버튼 라벨은 tier 이름만 (`Small` / `Medium` / `Large`), 실제 금액은 표시하지 않음 (글로벌 런칭 대비)

### IAP 구현 시 교체해야 할 내용

#### 1. 의존성 추가
`pubspec.yaml`:
```yaml
dependencies:
  in_app_purchase: ^3.x
```

#### 2. Play Console 준비
- Product ID 3개 등록
  - `donate_small`, `donate_medium`, `donate_large`
  - Type: **Consumable** (반복 구매 가능)
- 각 Product에 기본 가격 설정 (USD 권장)
  - Google이 170여 개 국가 통화로 자동 변환 + 현지 반올림
  - 특정 국가 수동 오버라이드 가능

#### 3. `lib/donation_dialog.dart` 교체 지점
**현재**:
- `_DonationTier` enum + 하드코딩 라벨만 존재
- `Donate` 버튼 onPressed에서 `messenger.showSnackBar('Coming soon')` 만 호출

**교체 필요**:
- 앱 시작 시 `InAppPurchase.instance.queryProductDetails({...})` 로 Product 정보 조회
- 라디오 라벨에 `ProductDetails.price` 추가 (예: `"Small  ₩1,200"`; 이미 현지화된 문자열)
- `Donate` 탭 시:
  - `InAppPurchase.instance.buyConsumable(purchaseParam)` 호출
  - `InAppPurchase.instance.purchaseStream` 리스닝
  - 성공/실패/취소 핸들링 + 성공 시 `InAppPurchase.instance.completePurchase(...)` 필수
- 스낵바 메시지:
  - 성공: `"Thank you for your support!"`
  - 실패/취소: `"Payment failed"` / `"Payment canceled"`

#### 4. AndroidManifest.xml
```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

#### 5. Consumable 영수증 검증
- 보안 권장: 서버 사이드 검증 (Google Play Developer API 사용)
- 개인 취미 앱이면 클라이언트 검증으로도 충분할 수 있음

### 참고 문서
- https://pub.dev/packages/in_app_purchase
- https://developer.android.com/google/play/billing/integrate
- https://developer.android.com/google/play/billing/subscriptions (구독 필요 시)
