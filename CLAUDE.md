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

## Play Console 자동 배포 (Gradle Play Publisher)

### 셋업 완료 항목
- 플러그인: `com.github.triplet.play` 3.12.1 ([android/settings.gradle.kts](android/settings.gradle.kts), [android/app/build.gradle.kts](android/app/build.gradle.kts))
- Service account 이메일: `play-publisher@effortless-launcher.iam.gserviceaccount.com`
- Service account 키 파일: `security/effortless-launcher-e202f6c046c1.json` (gitignore됨)
- 업로드 keystore: `security/effortless-upload.jks` (gitignore됨)
- 키스토어 비밀번호: `security/key.properties` — `storeFile=../../security/effortless-upload.jks` 상대경로 사용 (gitignore됨)
- 위 3개 파일은 다른 PC에서 작업 시 직접 옮겨야 하며, `security/` 폴더가 통째로 누락되면 release 빌드/배포 모두 불가
- GCP 프로젝트: `effortless-launcher` (gunajona85@gmail.com 계정 소속)
- Play Console 권한: 위 이메일을 "출시 관리자"로 초대 완료

### 배포 명령
```bash
# 1. pubspec.yaml의 versionCode (+숫자 부분) 매번 1 증가
# 2. 빌드 + 업로드 한 번에
flutter build appbundle --release && cd android && ./gradlew publishReleaseBundle
```

### 현재 제약: 앱이 "draft" 상태
- Play Console에서 앱이 production 정식 게시 전이라 모든 API 업로드는 **DRAFT 상태로만** 허용됨
- `releaseStatus.set(ReleaseStatus.DRAFT)` 로 명시 ([android/app/build.gradle.kts](android/app/build.gradle.kts) play 블록)
- 업로드 후 **Play Console UI에서 수동으로 "출시 시작" 클릭** 필요
  - Play Console → 테스트 → 내부 테스트 → 초안 카드의 "출시 검토" → "내부 테스트로 출시 시작"

### Production 정식 게시 후 변경 사항
- [android/app/build.gradle.kts](android/app/build.gradle.kts) 의 `releaseStatus` 를 `ReleaseStatus.COMPLETED` 로 변경
- 이후 `./gradlew publishReleaseBundle` 한 번에 자동 배포 완료 (UI 클릭 불필요)

### 자주 만나는 에러
| 메시지 | 원인 | 해결 |
|---|---|---|
| `Only releases with status draft may be created on draft app` | 앱이 draft 상태인데 COMPLETED로 시도 | `releaseStatus.set(DRAFT)` 유지 |
| `versionCode N has already been used` | pubspec.yaml의 `+숫자` 안 올림 | `+숫자` 1 증가 후 재빌드 |
| `403 PERMISSION_DENIED` 첫 시도 | Play Console 권한 전파 지연 (~24시간) | 다음 날 재시도 |
| `Package not found` | 첫 릴리스를 수동 업로드 안 함 | Play Console 웹에서 1회 수동 업로드 후 재시도 |

### 첫 릴리스 (수동 업로드 필요)
- API 업로드는 Play Console이 앱을 인지한 이후에만 동작
- 앱 최초 등록 시점의 첫 AAB는 반드시 Play Console 웹에서 직접 업로드해야 함
