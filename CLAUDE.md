# CLAUDE.md — effortless_launcher

## 인앱결제(IAP) — 구현 완료

후원(Donation) Consumable IAP. 글로벌 런칭 대비 가격은 Play Console이 현지화한 `ProductDetails.price` 그대로 라디오 라벨에 표시한다.

### 구성 요소
- [lib/donation_iap.dart](lib/donation_iap.dart) — 앱 전역 `InAppPurchase.purchaseStream` 리스너. 백그라운드 복구(restore)·중복 이벤트도 여기서 `completePurchase` 처리. `main()` 에서 한 번만 `start()` 호출.
- [lib/donation_dialog.dart](lib/donation_dialog.dart) — 다이얼로그 자체에도 별도 리스너를 둬서 사용자 가시적인 결과(스낵바/닫기)만 처리. 90초 타임아웃 + 결제 시트 비활성 후 복귀 그레이스 타이머.
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) — `<uses-permission android:name="com.android.vending.BILLING" />`

### Product ID (Play Console에 동일하게 활성화돼 있어야 함)
- `donate_small` / `donate_medium` / `donate_large` — 모두 **Consumable** (반복 구매)
- 미등록·비활성 시 다이얼로그가 "Unable to load donation options" 표시

### 영수증 검증
- 현재 **클라이언트 측 처리만**. 개인 후원 IAP 특성상 위변조 시 사용자가 손해 보는 구조라서 서버 검증 없이 운영.
- 추후 매출이 의미 있어지면 Google Play Developer API 로 서버 사이드 검증 추가 검토.

### 참고 문서
- https://pub.dev/packages/in_app_purchase
- https://developer.android.com/google/play/billing/integrate

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

### JAVA_HOME 필요 (gradle 직접 호출 시)
- `flutter build` 는 자체 JDK 탐색으로 동작하지만 `./gradlew publishReleaseBundle` 은 `JAVA_HOME` 미설정 시 `ERROR: JAVA_HOME is not set` 으로 실패
- 시스템 환경변수에 영구 설정하거나, 배포 셸에서 한 번 export:
```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
export PATH="$JAVA_HOME/bin:$PATH"
```
- `flutter doctor -v` 가 보고하는 "Java binary at" 경로의 상위 디렉터리(`jbr/`)를 그대로 사용

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
| `JAVA_HOME is not set and no 'java' command could be found` | gradle 호출 시 JDK 경로 미설정 | 위 "JAVA_HOME 필요" 섹션 참고 |

### 첫 릴리스 (수동 업로드 필요)
- API 업로드는 Play Console이 앱을 인지한 이후에만 동작
- 앱 최초 등록 시점의 첫 AAB는 반드시 Play Console 웹에서 직접 업로드해야 함
