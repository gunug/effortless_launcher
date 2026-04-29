# Effortless Launcher — 이미지 생성 가이드

앱 스토어 등록·홍보용 그래픽을 생성할 때 사용하는 화면 묘사 가이드.
이 문서를 ChatGPT/Midjourney/Stable Diffusion 등에 그대로 붙여 넣어 실제 앱 화면과 일치하는 목업을 만들 수 있도록 작성됨.

---

## 0. 공통 사양 (모든 이미지 공통 적용)

### 디바이스 프레임
- **기종: Samsung Galaxy S24 Ultra** (또는 S25 Ultra)
- 각진 모서리(직각에 가까운 둥글기), 티타늄 블랙 베젤
- 펀치홀 전면 카메라 — 상단 중앙
- 화면 비율: 19.3:9 (해상도 3120×1440 비율로 캔버스 구성)
- 베젤은 매우 얇음, 측면 베젤 1.5mm 수준

### 상태바 (Status Bar) — 항상 동일하게 그릴 것
- 시간: **10:04** (좌측)
- 우측: WiFi 풀, LTE/5G, 배터리 87%
- 색: 흰색 아이콘 (다크 테마 위)

### 하단 제스처 바
- 가는 흰색 바 1개 (3-버튼 네비게이션 아님, 제스처 모드)

### 앱 테마 (필수 준수)
- **Material 3 다크 테마**
- 시드 컬러: **인디고 (indigo)** — 강조색은 `#7C82E8` 계열 인디고 보라
- 배경: 거의 검정에 가까운 진한 차콜 (`#101014` ~ `#1A1A24`)
- 카드/입력창: 약간 밝은 차콜 (`#22222E`)
- 본문 텍스트: 거의 흰색 (`#E6E6F0`)
- 보조 텍스트: 회색 (`#9A9AA8`)
- 강조/액션: 인디고 (`#A8AEFF`)
- 둥근 모서리: 입력창 28px, 카드 12px

### 폰트
- Roboto / Pretendard 계열 산세리프
- 영문 UI (앱 자체가 영문)

---

## 1. 화면 #1 — Hot Zone (Frequently Used)

런처 첫 진입 시 보이는 메인 화면 중 하나. **4×7 그리드**로 자주 쓰는 앱 28개를 표시.

### 레이아웃 (위에서 아래 순서)
1. **상태바** (공통)
2. **헤더 행** — 좌측 패딩 16px
   - 🔥 작은 모닥불 아이콘 (Material Icon `local_fire_department`, 20px)
   - 공백 6px
   - 텍스트 **"Frequently Used"** (titleMedium, 약 16~18sp, 흰색)
   - 우측 끝에 아이콘 버튼 3개 일렬 배치:
     - 🔄 새로고침 (refresh) 20px
     - ❓ 도움말 (help_outline) 20px
     - 💲 후원 (attach_money) 20px
   - 아이콘은 모두 회색~흰색 톤
3. **앱 그리드** — 패딩 16px
   - 4열 × 7행 = 28칸
   - 각 칸 구조:
     - 상단: **48×48 앱 아이콘** (실제 안드로이드 앱 아이콘처럼 보이게 — Gmail, Chrome, YouTube, Instagram, KakaoTalk, Naver, Spotify, Telegram, Maps, Photos, Camera, Calculator, Clock, Calendar, Settings, Play Store, Bank app, WhatsApp, Slack, Notion, Discord, Twitter/X, Threads, Reddit, Toss, Coupang, Baemin, Uber 등 다양하게)
     - 6px 공백
     - **앱 이름 텍스트** (11sp, 중앙 정렬, 최대 2줄, 말줄임)
   - 칸 사이 가로 간격 8px, 세로 간격 16px

### 특수 배지 (4~6개 칸에 무작위로 적용)
- **NEW 배지** (앱 아이콘 우상단, 살짝 바깥으로 -4px 튀어나옴)
  - 빨간색 (`#E53935`) 작은 직사각형 라벨
  - 흰색 테두리 0.8px
  - 흰색 텍스트 **"NEW"** (8sp, bold, 대문자)
  - 모서리 둥글기 4px
- **자물쇠 🔒 배지** (앱 아이콘 좌상단, -2px)
  - 검정 반투명 원형 (`rgba(0,0,0,0.65)`), 흰 테두리 0.8px
  - 흰 자물쇠 아이콘 10px
- **알림 카운트 배지** (앱 아이콘 우하단, -4px)
  - 빨간 동그라미 또는 알약형 (한자리: 원형 16×16, 두자리: 알약형)
  - 흰 테두리 1px
  - 흰 숫자 (9sp, bold) — 예: "3", "12", "99+"

### 묘사 예시 프롬프트
> A Samsung Galaxy S24 Ultra screenshot showing a dark-themed Android launcher home screen. Top status bar shows time 10:04, WiFi, 5G, battery 87% in white. Below, a header row reads "Frequently Used" in white with a small flame icon on the left and three small icon buttons on the right (refresh, help, dollar sign). Below the header, a 4-column grid of 28 app icons fills the screen. Each icon is 48x48 pixels with the app name in 11sp white text below it, max 2 lines centered. Among the 28 apps include realistic icons like Gmail, Chrome, YouTube, Instagram, KakaoTalk, Spotify, Naver, Toss, Maps, Camera, Settings, Play Store, WhatsApp, Discord, Notion, Twitter/X. Three icons have a small red "NEW" label badge in the top-right corner. Two icons have a small black lock badge in the top-left corner. Four icons have a red circular notification count badge in the bottom-right showing numbers like "3", "12", "99+". Background is near-black charcoal #101014, accent color is indigo #A8AEFF. Material 3 dark theme. Realistic phone bezel, punch-hole front camera at top center, very thin titanium black bezels.

---

## 2. 화면 #2 — Search (검색 + Recently Used)

좌우로 스와이프해서 진입하는 검색 화면. 빈 상태일 때는 **Recently Used** 그리드가 표시됨.

### 레이아웃 (빈 검색 상태)
1. **상태바** (공통)
2. **검색창** — 패딩 16/16/16/8
   - 둥근 모서리 28px (알약형)
   - 채움색: `#22222E`
   - 좌측 prefixIcon: 🔍 검색 돋보기 (회색)
   - 힌트 텍스트: **"Search apps"** (회색 `#9A9AA8`)
   - 텍스트 입력 시 우측에 ✕ (clear) 버튼 표시
3. **헤더 행**
   - 🕐 history 아이콘 (시계 되감기 모양) 20px
   - 텍스트 **"Recently Used"** (titleMedium)
   - 우측에 ❓ 도움말, 💲 후원 아이콘 버튼
4. **앱 그리드** — 4열, 최대 24개
   - 1번 화면과 동일한 그리드/배지 시스템

### 레이아웃 (검색 결과 상태 — 예: "ka" 입력)
1. 검색창에 "ka" 입력됨, 우측 ✕ 버튼 표시
2. 정확 매칭 결과 그리드 (KakaoTalk, KakaoBank, KakaoMap, KakaoT 등 4~8개)
3. **"Similar"** 섹션 구분선
   - ✨ auto_awesome 아이콘 16px + "Similar" 라벨 + 가로 디바이더
4. 유사 매칭 결과 그리드 — **opacity 0.8** (살짝 흐리게)

### 묘사 예시 프롬프트
> Same Galaxy S24 Ultra dark launcher. At the top under the status bar, a pill-shaped search bar with rounded corners 28px, dark gray fill #22222E, a search magnifier icon on the left, hint text "Search apps" in light gray. Below the search bar, a header reads "Recently Used" with a small history (clock-rewind) icon on the left and two icon buttons (help, dollar) on the right. Below: a 4-column grid of 16 app icons sorted by recency — most recently used first. Same icon styling as the Frequently Used screen, with NEW badges on 2 icons and notification count badges on 3 icons. Indigo accent, Material 3 dark theme.

---

## 3. 화면 #3 — App Manager (Unused Apps)

스와이프 한 번 더 가면 나오는 미사용 앱 정리 화면. **세로 리스트 + 체크박스 멀티 셀렉트**.

### 레이아웃
1. **상태바** (공통)
2. **헤더 행** — 패딩 16/16/16/8
   - 좌측: **"App Manager  142"** (총 앱 수, titleMedium)
   - 우측: **"Selected: 7"** (라벨, 작은 회색)
   - 8px 공백
   - **"Delete selected"** 채움 버튼 (FilledButton, 인디고 배경, 좌측에 🗑️ delete_sweep 아이콘)
3. **얇은 디바이더 1px**
4. **세로 리스트** — 각 행 ListTile:
   - 좌측 leading:
     - **체크박스** (선택된 행은 인디고로 채워진 ✓, 일부 행은 비어있는 □)
     - 6px 공백
     - **40×40 앱 아이콘**
   - 가운데:
     - 상단: **앱 이름** (1줄, 말줄임)
     - 하단: **"Last used: 2025-09-14 (227 days ago)"** 또는 **"Never used"** (작은 회색 보조 텍스트)
   - 우측 trailing — 아이콘 버튼 2개:
     - 🔓 자물쇠 열림 (보호 안 됨) 또는 🔒 자물쇠 잠김 (보호됨, 인디고 색)
     - 🗑️ delete_outline (보호된 행은 비활성/회색)
   - 행 사이 자연스러운 ListTile 간격
5. 리스트 아래쪽 어딘가에 **"🔒 Protected  3"** 섹션 헤더 (인디고 라벨) + 가로 디바이더
6. 그 아래 보호된 앱 3개 (체크박스 비활성, 회색)

### 리스트에 들어갈 앱 예시 (실제 안드로이드 앱 아이콘으로)
- Banking app — Last used: 2024-03-10 (415 days ago)
- Shopping app — Never used
- Game (Genshin/PUBG) — Last used: 2025-01-22 (97 days ago)
- News app — Never used
- 기타 일반인들이 안 쓰는 통신사 앱, 제조사 기본 앱 등

### 묘사 예시 프롬프트
> Same Galaxy S24 Ultra dark theme. Top header row reads "App Manager  142" on the left and "Selected: 3" with a filled indigo "Delete selected" button (with delete-sweep icon) on the right. Thin divider line. Below: a vertical scrolling list of app rows. Each row has a checkbox on the left (3 rows checked with indigo fill), then a 40x40 app icon, then the app name on the first line and "Last used: 2024-09-14 (227 days ago)" or "Never used" in smaller gray text on the second line. On the right: a lock icon (open or closed) and a trash icon. Show about 8 visible rows including a banking app, a shopping app, a game, a news app, manufacturer pre-installed apps. Near the bottom, a section divider reads "🔒 Protected  3" in indigo and shows 3 protected apps below with disabled checkboxes and the closed-lock icon highlighted in indigo.

---

## 4. 화면 #4 — Deleted Apps (선택적, 거의 안 보여줘도 됨)

세 번째 스와이프로 진입. 삭제된 앱 기록 화면 (마케팅 이미지에서는 잘 안 씀).

---

## 5. 다이얼로그 — Set up Hot Zone instantly (첫 실행)

앱 첫 실행 직후 표시되는 모달. 화면을 흐릿하게 어둡게 하고 그 위에 다이얼로그 카드.

### 묘사
- **타이틀**: "Set up Hot Zone instantly"
- **본문**:
  > Effortless can use your recent app activity (last 30 days) to pre-fill Hot Zone right away, instead of waiting a week or two for it to learn.
  >
  > You will be sent to Android Settings to grant Usage Access. You can skip this and Hot Zone will warm up over time.
- **버튼**: 좌측 텍스트 버튼 "Skip" / 우측 채움 버튼 "Set up" (인디고)
- 카드 모서리 둥근 28px, 배경 차콜

---

## 6. 컨텍스트 메뉴 — 앱 길게 누르기

앱 아이콘 길게 누르면 나오는 팝업 메뉴. 위치는 손가락 위치 근처.

### 메뉴 항목
- 🗑️ Delete
- 👁️‍🗨️ Hide (Remove from recent)
- 🔒 Protect (또는 Unprotect)

각 항목은 아이콘 + 텍스트, 다크 메뉴 배경 (`#2A2A38`).

---

## 7. 후원 다이얼로그 (Support)

💲 버튼 탭 시 표시. 내용은 **UI만** 있음 (실제 결제 미구현).

### 묘사
- **타이틀**: "Support Effortless"
- 라디오 버튼 3개 (세로):
  - ◉ Small
  - ○ Medium
  - ○ Large
- 하단 버튼: "Cancel" (텍스트) / "Donate" (채움, 인디고)
- 가격 표시 없음 (글로벌 런칭 대비 의도적 생략)

---

## 8. 앱 스토어 메인 그래픽 권장 구도

### 옵션 A — 단일 폰 정면샷 (가장 간단)
- 폰 1대 정면, 약간 비스듬히 5도 기울임
- 화면은 **#1 Hot Zone** (앱 그리드가 가장 인상적)
- 배경: 인디고→차콜 그라디언트 또는 단색 차콜

### 옵션 B — 듀얼 폰 (검색 강조)
- 폰 2대를 살짝 겹쳐 배치
- 좌측 폰: Hot Zone
- 우측 폰: Search 화면 (검색창에 "ka" 입력 + 결과)
- 사이에 작은 화살표/스와이프 모션

### 옵션 C — 트리플 폰 (전체 기능 어필)
- 폰 3대 부채꼴 배치
- 좌→우: Hot Zone, Search, App Manager
- 각 화면 하단에 1줄 카피:
  - "Frequently used, instantly" (Hot Zone)
  - "Type or swipe to launch" (Search)
  - "Clean up unused apps" (App Manager)

---

## 9. 절대 하지 말 것 (Don't)

- ❌ iOS 디자인 요소 (홈 인디케이터, iOS 폰트, 라이트 테마 사용)
- ❌ Pixel/iPhone 폰 사용 — **반드시 Galaxy Ultra**
- ❌ 라이트(밝은) 테마 — 이 앱은 다크 전용
- ❌ 시드 컬러를 인디고 외 다른 색으로 (퍼플/블루/그린 X)
- ❌ 둥근 사각형 앱 아이콘 강제로 통일하지 말 것 — 안드로이드는 원형/스퀘어/티어드롭 모두 혼재가 자연스러움
- ❌ 가짜 앱 이름 (FakeApp, AppOne, MyApp 등) — 실제 인지도 있는 앱 이름 사용
- ❌ 앱 이름 텍스트를 너무 크게 (11sp 정도, 아이콘보다 훨씬 작게)
- ❌ 알림 배지를 파란색·초록색으로 (반드시 빨강 `#E53935`)
- ❌ NEW 배지를 노랑/주황으로 (반드시 빨강)

---

## 10. 빠른 체크리스트 (이미지 생성 후 검수)

- [ ] Galaxy Ultra 폰 프레임이 맞는가 (직각 모서리, 펀치홀)
- [ ] 다크 테마인가 (배경이 검정~차콜)
- [ ] 강조색이 인디고인가 (보라가 아닌 푸른 보라)
- [ ] 상태바 시간이 10:04인가
- [ ] 앱 그리드가 4열인가
- [ ] 앱 이름이 11sp 정도로 작게 들어가 있는가
- [ ] 배지 (NEW/lock/notification)가 위치 정확한가 (NEW 우상단, lock 좌상단, count 우하단)
- [ ] 헤더의 아이콘 버튼 3개가 맞는가 (refresh/help/dollar)
- [ ] 앱 아이콘이 실제 인지도 있는 앱들인가
- [ ] iOS 요소가 섞이지 않았는가
