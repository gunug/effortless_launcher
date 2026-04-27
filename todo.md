# Effortless Launcher — Play Store 출시 가이드 (todo.md)

> Play Console 계정: **gunajona85@gmail.com**
> 패키지명: `com.onethelab.effortless_launcher`
> 현재 버전: `1.4.1+2` (versionName 1.4.1 / versionCode 2)

---

## 0. 사전 점검 (현재 상태)

이미 완료된 항목:
- [x] 앱 서명 키스토어 생성 — `C:/Users/gunug/effortless-upload.jks`
- [x] `android/key.properties` 설정 (alias=`upload`)
- [x] `android/app/build.gradle.kts` 에 release 서명 구성 연결
- [x] applicationId / namespace = `com.onethelab.effortless_launcher`
- [x] 런처 카테고리 (`CATEGORY_HOME`) Manifest 등록
- [x] 앱 아이콘 mipmap-* 5단계 모두 등록
- [x] `app-release.aab` 1차 빌드 산출물 존재

⚠️ 주의 / 미완료 항목 → 아래 단계에서 처리.

---

## 1단계. 출시 전 코드/메타 점검

- [ ] **버전 확정**: `pubspec.yaml` 의 `version: 1.4.1+2` 가 첫 출시 버전이 맞는지 확인.
      첫 출시는 보통 `1.0.0+1` 또는 `1.0.0` 으로 가는 게 깔끔함. 변경하려면 `pubspec.yaml` 만 수정 후 재빌드.
- [ ] **앱 표시 이름 확인**: AndroidManifest 의 `android:label="Effortless Launcher"` (현재 OK).
- [ ] **민감 권한 정당화 메모 준비** (Play Console 등록 시 필요):
      - `QUERY_ALL_PACKAGES` — "런처 앱 특성상 사용자가 설치한 모든 앱을 홈 화면에 나열·실행해야 하므로 필수." (제출 시 영문으로 작성)
- [ ] **HOME 카테고리 런처 앱 정책 확인**:
      Play 정책상 `CATEGORY_HOME` 인텐트 필터를 가진 앱은 "Default Launcher" 로 동작. 정책 위반 사항 없음(스파이웨어/광고 강제 X).
- [ ] **인앱결제 미구현 상태 출시 결정**:
      `lib/donation_dialog.dart` 는 UI만 존재 (CLAUDE.md 참조). 두 가지 중 택1
      - (A) 후원 버튼 / `$` 아이콘 자체를 일시 숨김 처리하고 출시 → 안전
      - (B) "Coming soon" 그대로 출시 (Play 심사에서 비기능 UI 로 거절될 가능성 존재 → 비추천)
- [ ] `flutter analyze` 무경고
- [ ] `flutter test` 통과 (기본 위젯 테스트라도)

---

## 2단계. Release AAB 재빌드 & 검증

- [ ] 클린 빌드:
      ```bash
      flutter clean
      flutter pub get
      flutter build appbundle --release
      ```
- [ ] 산출물 확인: `build/app/outputs/bundle/release/app-release.aab`
- [ ] 서명 검증 (debug 키로 서명되지 않았는지 확인):
      ```bash
      jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
      ```
      → `CN=upload` 가 보이면 OK. `CN=Android Debug` 가 보이면 `key.properties` 경로 점검.
- [ ] 실기기 설치 테스트 (선택, bundletool 또는 internal testing 트랙으로):
      ```bash
      flutter build apk --release
      flutter install --release
      ```
      홈 키 동작 / 앱 실행 / 검색 / Hot zone / Frequently Used / 후원 다이얼로그 모두 점검.

---

## 3단계. Play Console — 앱 생성

Play Console (https://play.google.com/console) 에 **gunajona85@gmail.com** 으로 로그인.

- [ ] **개발자 등록비** $25 결제 완료 여부 확인 (최초 1회).
- [ ] **앱 만들기**
      - 앱 이름: `Effortless Launcher`
      - 기본 언어: English (US) — 글로벌 런칭 전제
      - 앱/게임: 앱
      - 무료/유료: 무료
      - 정책 동의 체크박스 모두 체크

---

## 4단계. 스토어 등록정보 (Store Listing)

- [ ] **간단한 설명 (Short description, ≤80자)**
      예: `A minimal home launcher that surfaces frequently used apps and hides the rest.`
- [ ] **자세한 설명 (Full description, ≤4000자)** — 영문으로 작성
      포함 권장 키워드: `home launcher`, `minimal`, `frequently used`, `app drawer`, `search`, `hot zone`
- [ ] **앱 아이콘**: 512x512 PNG (32-bit, 알파 채널, 1024KB 이하)
- [ ] **피처 그래픽 (Feature Graphic)**: 1024x500 PNG/JPG (필수)
- [ ] **스크린샷**: 최소 2장, 최대 8장
      - 폰: 1080x1920 권장 (최소 320px, 최대 3840px, 비율 16:9~9:16)
      - 실기기에서 홈/검색/Hot zone/후원 다이얼로그 등 핵심 화면 캡처
- [ ] (선택) **프로모션 동영상**: YouTube URL
- [ ] **카테고리**: `Personalization` (런처 앱 표준 카테고리)
- [ ] **태그**: 런처 / 개인화 관련 2~3개
- [ ] **연락처**: 이메일 (gunug850@gmail.com 또는 별도)
- [ ] **개인정보 처리방침 URL** ⚠️ 필수
      → 인터넷 권한이 없어 데이터 수집이 거의 없지만, **launcher 권한 + QUERY_ALL_PACKAGES** 때문에 정책 페이지가 반드시 필요.
      간단 페이지(GitHub Pages / Notion 공개페이지 / Google Sites) 로 올리고 URL 등록.
      포함 문구: 데이터 수집 없음 / 외부 전송 없음 / 앱 목록은 로컬에만 사용 / `shared_preferences`, `path_provider` 로 로컬 저장.

---

## 5단계. 앱 콘텐츠 (App content) — 필수 설문

- [ ] **개인정보처리방침 URL** 입력
- [ ] **앱 액세스 권한 (App access)**: 로그인 없음 → "All functionality is available without restrictions"
- [ ] **광고**: 없음 → "No, my app does not contain ads"
- [ ] **콘텐츠 등급 (Content rating)** 설문 응답
      → 예상 등급: Everyone (3+) / 전체이용가
- [ ] **타겟 사용자층 및 콘텐츠 (Target audience)**
      - 13세 이상 권장 (런처는 보통 청소년+)
      - 어린이용 아님 (Designed for Families X)
- [ ] **뉴스 앱 여부**: 아니오
- [ ] **COVID-19 추적 앱**: 아니오
- [ ] **데이터 보안 (Data Safety)** 설문
      - 데이터 수집: **No data collected**
      - 데이터 공유: **No data shared with third parties**
      - 데이터 암호화: 해당 없음
      - 사용자 데이터 삭제 요청 방법: 앱 삭제 시 모든 로컬 데이터 자동 제거
- [ ] **정부 앱**: 아니오
- [ ] **금융 상품**: 아니오 (후원 IAP 미구현이므로)
- [ ] **건강 앱**: 아니오
- [ ] **민감한 권한 사용 정당화**
      - `QUERY_ALL_PACKAGES`: "Required core functionality for a home launcher to display and launch any installed app on the user's device." 영문으로 작성.

---

## 6단계. 가격 및 배포

- [ ] **국가/지역**: 모든 국가 또는 원하는 국가만 선택 (글로벌 런칭이면 전체)
- [ ] **무료** (가격 0)
- [ ] **기기 카테고리**: 휴대전화 / 태블릿 (런처는 폼팩터 영향 적음)

---

## 7단계. 첫 릴리스 — Internal Testing 으로 시작 (강력 권장)

production 직행보다 internal → closed → production 순으로 가는 게 안전.

- [ ] **내부 테스트 트랙 (Internal testing)** 생성
- [ ] 테스터 이메일 리스트 추가 (본인 + Gmail 1~2개)
- [ ] **AAB 업로드**: `build/app/outputs/bundle/release/app-release.aab`
- [ ] 릴리스 노트 작성 (영문):
      ```
      Initial release.
      - Minimal home launcher with frequently used apps surface
      - Search, Hot zone with decay-weighted ranking
      - Local-only, no network access
      ```
- [ ] **Play 앱 서명 (Play App Signing)** 사용 동의 — 필수
      Google 이 최종 서명 키 관리. 업로드 키(`upload.jks`)는 우리가 보관.
- [ ] **검토 후 출시 (Roll out)** 클릭
- [ ] 옵트인 URL 을 테스터에게 공유 → 실기기 설치 → 동작 확인

---

## 8단계. Closed Testing (선택, 신뢰도 ↑)

- [ ] 테스터 20명 이상 / 14일 이상 운영 시 production 승인 신뢰도 향상
      (개인 개발자 신규 계정의 경우 Google 정책상 필수일 수 있음 — 2024년 이후 강화)
- [ ] 피드백 수집 후 버그픽스 → versionCode 증가 → 재빌드 → 재업로드

---

## 9단계. Production 출시

- [ ] **프로덕션 트랙** 으로 release 생성
- [ ] AAB 동일 파일 업로드 (또는 새 빌드)
- [ ] 단계적 출시 (Staged rollout) 권장: 처음 10~20% 부터
- [ ] **Google 검토 대기** (보통 1~7일, 신규 계정은 더 길 수 있음)
- [ ] 승인되면 자동 게시 또는 수동 게시

---

## 10단계. 출시 후

- [ ] **크래시/ANR 모니터링**: Play Console > 품질 > Android Vitals
- [ ] **사용자 리뷰 응답**
- [ ] **다음 버전 준비 시 체크리스트**:
      - `pubspec.yaml` 의 version 증가 (예: `1.4.2+3`) — versionCode 는 반드시 증가
      - `flutter build appbundle --release`
      - 동일 키스토어로 서명되어야 업로드 가능 (`upload.jks` 분실 주의 → **별도 백업**)
- [ ] (향후) **IAP 구현** → CLAUDE.md 의 후원 다이얼로그 교체 지점 참고

---

## 🔐 보안 / 백업 체크리스트 (반드시!)

- [ ] `C:/Users/gunug/effortless-upload.jks` **별도 위치(클라우드 + 외장) 백업**
      → 분실 시 같은 패키지명으로 업데이트 영구 불가
- [ ] `android/key.properties` 의 비밀번호 `maz2l6Je7ZDXLMIigvbBrvzGIoVb` **암호 관리자에 저장**
- [ ] `key.properties` 와 `*.jks` 가 `.gitignore` 에 포함되어 있는지 확인 (커밋 금지)

---

## 참고 링크

- Play Console: https://play.google.com/console
- Flutter Android 배포 문서: https://docs.flutter.dev/deployment/android
- Play Console 정책: https://play.google.com/about/developer-content-policy/
- Data Safety 양식 가이드: https://support.google.com/googleplay/android-developer/answer/10787469
