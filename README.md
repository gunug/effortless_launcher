# effortless_launcher

Android 런처 앱 — 검색 기반 앱 실행, 사용 빈도 기반 Hot zone, 알림 배지, 미사용 앱 관리.

## 다른 PC로 옮길 때 빼먹으면 안 되는 파일

`git clone` 만으로는 release 빌드/배포 불가. 아래 파일들은 `.gitignore`로 제외되어 있어 **수동 복사 필수**입니다.

### `security/` 폴더 (3개 파일)

| 파일 | 없으면 발생하는 일 |
|---|---|
| `security/effortless-upload.jks` | release 빌드 자체 불가. **분실 시 같은 패키지명으로 영영 업데이트 불가** (Play Store에 새 앱으로 다시 등록해야 함) |
| `security/key.properties` | jks 비밀번호/alias 정보. 없으면 debug 서명으로 fallback돼서 Play Store 업로드 거부됨 |
| `security/effortless-launcher-e202f6c046c1.json` | `./gradlew publishReleaseBundle` 자동 업로드 불가 (수동 업로드는 가능) |

### 백업 권장 방법

1. **암호화된 USB** — 가장 안전, 오프라인 보관
2. **암호화된 클라우드** — 1Password / Bitwarden secure note 첨부, 또는 GPG 암호화 후 Google Drive
3. **종이 백업** — `key.properties` 비밀번호는 종이로도 백업 (jks가 살아있어도 비밀번호 잃으면 무용지물)

### 다른 PC 셋업 체크리스트

1. `git clone https://github.com/gunug/effortless_launcher.git`
2. 백업해둔 `security/` 폴더 통째로 프로젝트 루트에 복사
3. `flutter pub get`
4. `flutter build appbundle --release` — 빌드 성공하면 셋업 완료

`security/key.properties` 의 `storeFile=../../security/effortless-upload.jks` 가 상대경로라서 어떤 PC에서든 폴더 위치 수정 없이 바로 작동합니다.

## 빌드 / 배포

상세는 [CLAUDE.md](CLAUDE.md) 참고.

```bash
# release AAB 빌드
flutter build appbundle --release

# Play Console 자동 업로드 (DRAFT 상태)
cd android && ./gradlew publishReleaseBundle
```

배포 전 `pubspec.yaml` 의 `version: x.y.z+N` 의 **N (versionCode)** 을 매번 1 증가시켜야 합니다.
