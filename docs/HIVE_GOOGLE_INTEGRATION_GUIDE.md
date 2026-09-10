# JellyMon Hive·Google 연동 작업 가이드

작성일: 2026-09-09  
대상: JellyMon Android / Godot 4.7 / Hive Native SDK 26.4.0 / Hive Adiz 3.0.0  
범위: 게스트·Google 로그인, 별 3개 모험 랭킹, 보상형 광고, 전체 게임 데이터 저장·복원

이 문서는 현재 프로젝트 소스와 공식 문서를 대조한 실무 가이드다. 콘솔 작업, 앱 개발, 랭킹 서버 개발을 구분한다. 실제 비밀키와 로그인 토큰은 포함하지 않는다. 콘솔 메뉴 명칭은 언어·권한·버전에 따라 조금 다를 수 있다.

**‘코드가 구현됨’, ‘콘솔 설정이 저장됨’, ‘실제 서비스에서 성공함’은 각각 따로 확인해야 한다.** 아래 현황의 실기기 결과는 이전 작업에서 확인한 이력이며, 문서 작성 중 서버나 콘솔을 다시 변경하거나 실서비스 테스트 기록을 등록하지 않았다.

## 목차

1. 담당 영역과 전체 구조
2. 현재 구현·검증 상태
3. 계정·프로젝트·키 준비표
4. Hive 콘솔 작업
5. Google 콘솔 작업
6. 앱 개발 작업
7. 랭킹 서버 작업
8. 빌드와 환경 전환
9. 기능별 검수 절차
10. 장애 진단
11. 출시 전 작업 목록
12. 관련 파일과 공식 자료

## 1. 담당 영역과 전체 구조

| 기능 | Hive 담당 작업 | Google 담당 작업 | 앱 개발 | 자체 서버 |
| --- | --- | --- | --- | --- |
| 게스트 로그인 | 프로젝트/App ID, Auth v4, 보안 키, 약관, 로그인 수단 | 게스트 자체에는 OAuth 설정 불필요 | SDK 초기화, 로그인 콜백, Player ID 관리 | 현재 로그인 UI에는 불필요 |
| Google 로그인 | Google 제공자 노출·필요한 인증 설정 | Cloud OAuth, 서명 인증서, 동의 화면 | Credential Manager 제공자 모듈·XML 설정 | 현재 앱의 Hive 로그인에는 별도 OAuth 서버 불필요 |
| Google Play Games 로그인 | Google 로그인과 별도 제공자 설정 | PGS 프로젝트·자격증명·테스터 | PGS 모듈 및 프로젝트 식별자 | 선택 기능에 따라 다름 |
| 모험 랭킹 | 보드 163, 정렬·기간·인증키 | Hive 랭킹만 사용하면 Google 리더보드 생성 불필요 | 3성 최초 기록 수집·전송·TOP 100 UI | Hive 토큰 검증, 점수 등록·조회, 영구 전송 대기 |
| 보상형 광고 | Adiz 광고 설정, 기본 Rewarded 매핑 | AdMob 앱·광고 단위·테스트 기기·메시지 | 초기화·로드·재생·보상·재시도 | 현재 구현에는 불필요; 서버 보상 검증은 별도 확장 |
| DataStore | 저장소 생성, 공개키 등록, 사용 활성화 | Google Drive/Firebase 생성 불필요 | 전체 저장 직렬화·동기화·복원·충돌 처리 | 현재 구현에는 불필요; 동시 접속 제어는 별도 확장 |

```text
Godot 게임 → PlatformService → Android HiveBridge
                                 ├─ AuthV4 → Hive 인증 → Guest / Google / PGS
                                 ├─ Adiz → AdMob 보상형 광고
                                 └─ DataStore → Hive 게임 저장소

RankingService → HTTPS 랭킹 서버 → Hive 로그인 토큰 검증
                              ├─ SQLite 최고 기록 / 전송 대기
                              └─ Hive Leaderboard 163 → TOP 100 반환
```

현재 구조에서는 로그인과 DataStore를 위해 별도 게임 서버를 새로 만들 필요는 없다. 랭킹은 서버 전용 인증키를 보호하고 기록을 중계하는 Node.js 서버를 사용한다. Firebase를 추가하는 작업은 이 연동의 필수 단계가 아니다.

## 2. 현재 구현·검증 상태

| 항목 | 현재 프로젝트 상태 | 추가 확인 또는 작업 |
| --- | --- | --- |
| Android 패키지 | `com.jellymon.game` | Play 배포본도 동일하게 유지 |
| Hive SDK | Native 26.4.0, Hercules 포함 | 상용 환경에서 재검수 |
| 게스트/Hive 인증 | 실제 Player ID 발급·로그인 성공 이력 있음 | 재실행 시 같은 계정 유지, 제공자별 검수 |
| Google 로그인 | Credential Manager 제공자 의존성 및 설정 경로 있음 | Google 계정으로 실제 로그인·취소·다른 기기 재로그인 검수 |
| Google 계정 영구 연동 | 현재 브리지는 주로 `showSignIn`/`signIn` 사용 | 게스트 PID를 유지하는 별도 IdP 연동 흐름은 추가 확인·구현 필요 |
| 연결 해제 | `DELETE ACCOUNT` 확인, 성공 후 기기 데이터 초기화 | 일반 계정 로그아웃과 게스트 삭제를 구분해 안내 |
| 광고 | Adiz 3.0.0, 테스트 광고 재생·보상 지급 성공 이력 있음 | 실제 AdMob App ID·광고 단위, 동의 흐름, 상용 검수 |
| 랭킹 | Node.js+TypeScript 서버, 보드 163, TOP 100 UI | 과거 누락 기록 재조정, 운영 서버·서명 배포본 검수 |
| DataStore | 전체 저장·복원·충돌 선택·쓰기 후 재조회 구현 | 실제 Hive 저장·복원 성공 확인 필요 |

현재 앱 설정은 `android.zone=sandbox`, `android.test_ads=true`다. 랭킹 주소는 `https://engrailed-sadye-curatively.ngrok-free.dev`다. 이는 출시 설정 완료를 의미하지 않는다.

이전 실기기 조사에서 DataStore는 활성화 전 `DataStoreDisabled`, 이후 2026-09-09 17:53~17:55경 `401 Auth Fail`, 17:57경 `500 Server Internal Error`가 관찰되었다. 공개키가 입력된 콘솔 화면만으로 실제 저장 성공을 판정할 수 없다. 당시 오류의 원인이 잘못된 공개키라고 확정된 것도 아니다.

랭킹은 설정 변경 후 신규 3성 기록이 Hive 조회에 나타난 이력이 있다. 일부 과거 기록은 서버에서 전송 완료로 취급되었지만 보드 조회에 없었던 이력이 있어, 모든 과거 기록 복구까지 완료된 상태로 보지 않는다.

기존 개별 문서에는 초기 실패, 예전 화면 위치, mono 템플릿 등 과거 이력이 남아 있다. 현재 구성은 이 문서와 실제 소스를 우선 확인한다.

## 3. 계정·프로젝트·키 준비표

| 값 | 발급/확인 위치 | 사용하는 위치 | 혼동 주의 |
| --- | --- | --- | --- |
| Android 패키지명 | 앱 빌드 설정 | APK, Google Android OAuth 등록 | 현재 `com.jellymon.game` |
| Hive 프로젝트 ID | Hive 앱센터 | 프로젝트 선택·관리 | 숫자 프로젝트 ID와 App ID는 다름 |
| Hive App ID | Hive 앱센터 App ID 관리 | XML, 플랫폼 JSON, 랭킹 서버 | 현재 프로젝트는 패키지명과 같게 설정 |
| Hive 인증 보안 키 | Hive 보안 키 설정 | Hive 인증 설정 | OAuth 키나 DataStore 키와 별개 |
| Google Android OAuth Client ID | Google Cloud / Google Auth Platform | Android 로그인 식별 설정 | 패키지명·서명 SHA-1에 연결 |
| Google Web OAuth Client ID | 같은 Google Cloud 프로젝트 | `serverClientId` | Android Client ID를 대신 넣지 않음 |
| OAuth Client Secret | 해당 OAuth 자격증명 | 요구되는 콘솔/서버 설정에만 입력 | APK·GDScript·공유 문서에 넣지 않음 |
| PGS 게임 프로젝트 ID | Play Games Services 설정 | `game_services_project_id` 등 | 일반 Web OAuth Client ID와 다름 |
| Hive Certification Key | 앱센터 → 프로젝트 관리 → 게임 상세 → 기본 정보 | 랭킹 서버 `HIVE_CERTIFICATION_KEY` | 서버 전용, APK에 넣지 않음 |
| Hive Leaderboard ID | 리더보드 → 랭킹 관리 | 서버 `HIVE_LEADERBOARD_ID=163` | 164번을 함께 사용하지 않음 |
| DataStore 공개키 | 게임 데이터 스토어에서 저장소 생성 | 같은 게임의 Hive 제품 설정 | 로그인 Client Secret을 붙이지 않음 |
| AdMob App ID | AdMob 앱 설정 | `admob_app_id` → Manifest | `ca-app-pub-…~…` 형식 |
| Rewarded 광고 단위 ID | AdMob 광고 단위 | Hive Adiz 광고 매핑 | `ca-app-pub-…/…` 형식 |
| Hive Player ID | 로그인 성공 콜백 | 저장·랭킹의 계정 식별 | 닉네임·Google 이메일로 대체하지 않음 |

Android/Web OAuth 생성과 `serverClientId`의 구분은 [Google 로그인 실습](https://codelabs.developers.google.com/sign-in-with-google-android)을 참고한다. Hive 서버 인증키 위치는 [Leaderboard API](https://developers.hiveplatform.ai/en/latest/api/leaderboard-api/)에 명시되어 있다.

운영 담당자는 개발/운영 환경별로 위 값의 **이름·소속 프로젝트·보관 위치·담당자**를 관리한다. 키 원문을 작업 티켓이나 게임 로그에 붙이는 방식은 피한다.

## 4. Hive 콘솔에서 해야 할 작업

### 4.1 프로젝트와 인증 공통 설정

1. 앱센터에서 JellyMon 프로젝트를 선택한다. 기존 화면 기준 `[3674] JellyADtest` 프로젝트를 사용했으므로 다른 프로젝트를 선택하지 않았는지 확인한다.
2. Android App ID와 실제 패키지명을 대조한다. 현재 App ID는 `com.jellymon.game`이다.
3. Hive 제품 설정에서 SDK4 및 Auth v4 사용 상태를 확인한다.
4. 사용하는 환경의 보안 키를 발급·저장한다. Native SDK 25.0.0 이상은 보안 키 발급이 필요하다. [Hive Native 릴리스 안내](https://developers.hiveplatform.ai/ko/latest-version/releases/native/)
5. 로그인 설정에서 게스트·Google·Google Play Games 중 서비스할 수단을 선택한다.
6. 약관 그룹, 적용 국가·언어, 배포 상태와 게임 연결을 확인한다. 초기화에서 약관·업데이트·점검 안내가 막히지 않아야 한다.
7. 저장 후 화면을 다시 열어 설정이 유지되는지 확인하고, 앱을 완전히 종료한 뒤 초기화부터 다시 시험한다.

완료 증거는 콘솔의 선택 상태와 앱의 `setup success=true`, 이어지는 로그인 성공 및 유효한 Player ID다. SDK 초기화 성공만으로 로그인 완료로 표시하지 않는다.

### 4.2 Google과 Google Play Games 구분

Android 일반 Google 로그인과 Google Play Games는 Hive에서 별도 제공자다. 공식 IdP 표에서 Android Google은 XML 설정, Google Play Games는 콘솔과 XML 설정을 사용한다. 모든 Google 키를 무조건 모든 칸에 복사하는 방식으로 설정하지 않는다. [Hive IdP별 키 입력](https://developers.hiveplatform.ai/en/latest-version/dev/authv4/hive-sdk-prep/common/idp-console-keys/)

PGS를 사용하는 경우 해당 제공자 설정에서 요구하는 Web OAuth 인증 정보를 등록한다. 리디렉션 URI가 요구되는 흐름은 Hive 공식 추가 설정/콘솔에 표시되는 URI를 그대로 Google에 등록한다. 임의의 콜백 URL을 만들지 않는다.

완료 기준은 두 제공자가 각각 의도한 계정으로 로그인되는 것이다. 게스트 로그인 성공은 Google OAuth 설정의 성공 증거가 아니다.

### 4.3 리더보드 163 설정

| 설정 | JellyMon 기준 |
| --- | --- |
| 대상 보드 | 163 |
| 용도 | 별 3개로 클리어한 최고 모험 레벨 |
| 점수 정렬 | 높은 점수 우선 / 내림차순 |
| 초기화 | 누적 / 초기화 없음 |
| 운영 시작 | 테스트 또는 출시 시각보다 이전 |
| 운영 종료 | 서비스 계획에 맞게 지정 |
| 타임존 | 한국 기준이면 UTC+09:00 / Asia/Seoul |
| 상태 | 현재 시각에 실제로 운영 중인지 확인 |
| 별도 보드 164 | 현재 앱에서는 미사용 |

리더보드 생성 시 운영 기간과 초기화 주기를 설정하고, 상세 화면에서 실제 등록 결과를 조회한다. [Hive 리더보드 콘솔](https://developers.hiveplatform.ai/en/latest/operation/leaderboard/)

기존 화면에서 `UTC-09:00`이 선택된 적이 있다. 한국시간 `UTC+09:00`과 다르므로 시작 시각까지 함께 확인한다. 상단 화면 표시 시간대와 보드 자체 시간대도 구분한다.

인증키와 보드 ID는 해당 게임에 속해야 한다. 서버가 sandbox API에 접속하는데 다른 환경을 조회하고 있지 않은지도 확인한다. 콘솔에 보드를 만드는 것만으로 앱의 기록이 자동 수집되지는 않는다.

### 4.4 Adiz 설정

현재 앱은 **Hive Adiz**를 사용한다. 다른 광고 제품인 Adkit 설정을 그대로 대입하지 않는다.

1. Hive의 Adiz 설정에서 Android 앱을 선택하고 AdMob 앱·광고 정보를 연결한다.
2. 광고 형식을 Rewarded로 지정하고 실제 Rewarded 광고 단위 ID를 매핑한다.
3. 현재 네이티브 코드는 `AdizRewarded.initialize(activity, listener)`로 기본 광고를 사용하므로 Rewarded 기본 광고가 지정되어야 한다.
4. 국가·광고 노출 조건·사용 상태를 확인하고 저장한다.
5. 다른 광고 네트워크를 추가한다면 그 네트워크의 콘솔 설정과 호환 어댑터를 별도로 준비한다.

Adiz의 기본 광고, 테스트 모드, 광고 콜백 설정은 [Adiz Android 공식 가이드](https://developers.hiveplatform.ai/ko/latest/dev/ad-monetization/hive-adiz/android/)를 참고한다. 테스트 광고 재생 성공과 상용 광고 매핑 성공은 별도다.

### 4.5 DataStore 활성화와 공개키 저장

1. **게임 데이터 스토어 → 데이터 관리**에서 JellyMon 게임을 선택한다.
2. 저장소가 없다면 **데이터 관리 시작하기**로 생성한다.
3. 생성된 DataStore 공개키를 복사한다.
4. **앱센터 → 게임 목록 → 같은 게임 → Hive 제품 설정**을 연다.
5. 데이터 스토어를 **사용함**으로 선택하고 공개키를 붙여 넣어 저장한다.
6. 화면을 다시 열어 값이 유지되는지 확인한다.

위 경로는 [Hive DataStore 콘솔 가이드](https://developers.hiveplatform.ai/ko/latest/operation/game-data-store/)에 따른다. 저장 버튼이 비활성화된 상태는 변경할 내용이 없다는 의미일 수 있다. 공개키가 보인다는 사실만으로 앱의 인증·저장 성공까지 확인되지는 않는다.

앱을 재실행하고 로그인한 뒤 `클라우드 저장 / 복원`을 실행한다. 콘솔에서 같은 Player ID의 **`jellymon_save_v1`** 키와 실제 내용을 확인한다. 키를 다시 만들거나 바꾸기 전에 게임·환경·계정이 맞는지 먼저 대조한다.

## 5. Google에서 해야 할 작업

### 5.1 Google Cloud OAuth

1. JellyMon이 사용할 Google Cloud 프로젝트를 선택한다. OAuth 클라이언트가 여러 프로젝트에 흩어지지 않도록 관리한다.
2. Google Auth Platform의 Branding/Audience/Data Access 또는 OAuth 동의 화면에서 앱 이름, 지원 연락처, 대상 사용자와 필요한 범위를 설정한다.
3. 테스트 상태인 경우 로그인에 사용할 테스트 계정을 등록한다.
4. Android 유형 OAuth 클라이언트를 만들고 패키지명 `com.jellymon.game`과 해당 빌드 서명의 SHA-1을 등록한다.
5. 같은 프로젝트에 Web application 유형 OAuth 클라이언트를 만들고 Client ID를 앱의 `serverClientId`에 사용한다.
6. 서명별 Android 클라이언트를 준비하고, 개발 APK와 Play 배포본을 각각 검수한다.

설정 원리는 [Google Android 로그인 실습](https://codelabs.developers.google.com/sign-in-with-google-android)에 따른다. 현재 Hive 래퍼를 사용하는 앱에 별도의 Google 로그인 SDK 샘플 전체를 중복 구현할 필요는 없다.

### 5.2 서명 인증서 관리

| 배포 경로 | 확인할 인증서 |
| --- | --- |
| 개발 PC에서 만든 debug APK | 실제 debug keystore의 SHA-1 |
| 직접 배포하는 release APK | APK에 서명한 release keystore의 SHA-1 |
| Google Play에서 설치한 앱 | Play App Signing 인증서의 SHA-1 |
| AAB 업로드용 키 | 업로드 키; Play 설치본 서명과 같다고 가정하지 않음 |

Google Play는 업로드 키와 앱 서명 키를 분리할 수 있다. Play Console의 앱 서명 화면에서 실제 배포 인증서를 확인한다. [Android 앱 서명](https://developer.android.com/studio/publish/app-signing)

개발자가 키를 확인할 때는 다음과 같이 실행하고 비밀번호는 프롬프트에 입력한다.

```sh
keytool -list -v -keystore /path/to/jellymon.keystore -alias YOUR_ALIAS
```

SHA-1은 로그인 설정용 인증서 지문이며 Client Secret이 아니다. APK 파일명만 보고 어떤 키로 서명됐는지 판단하지 않는다.

### 5.3 Google Play Games Services — 사용할 때만

Play Console에서 PGS 게임을 생성 또는 연결하고 Cloud 프로젝트를 지정한다. Android 자격증명에 패키지명·서명을 연결하고, 필요 시 서버 자격증명에 Web OAuth 클라이언트를 연결한다. PGS 테스터를 등록하고 변경 사항의 공개 상태도 확인한다. [PGS 설정 가이드](https://developer.android.com/games/pgs/console/setup)

현재 Hive 모험 랭킹을 위해 Google Play Games 리더보드를 추가로 만들 필요는 없다. PGS 로그인 지원과 PGS 리더보드 사용은 서로 다른 선택이다. Play 내부 테스트 참여자 등록과 PGS 테스트 권한도 각각 확인한다.

### 5.4 AdMob

1. AdMob 계정에서 Android 앱을 등록하고, 출시 후에는 해당 스토어 앱과 연결 상태를 확인한다.
2. App ID를 받아 `hive_ids.xml`의 `admob_app_id`에 반영한다.
3. Rewarded 광고 단위를 생성하고 단위 ID를 Hive Adiz 매핑에 등록한다.
4. 테스트 기기를 등록하거나 테스트 광고를 사용한다.
5. 앱 준비 상태와 광고 게재 제한·정책 센터의 문제 여부를 확인한다.

App ID는 Manifest의 `com.google.android.gms.ads.APPLICATION_ID`에 들어간다. 현재 프로젝트는 이 값을 Android 리소스로 연결한다. [AdMob Android 설정](https://developers.google.com/admob/android/quick-start)

개발 중에는 테스트 광고나 등록된 테스트 기기로 검수한다. 실제 광고를 반복 클릭하는 방식으로 테스트하지 않는다. [Google 테스트 광고 안내](https://developers.google.com/admob/android/test-ads)

### 5.5 광고 동의와 Play 제출 정보

AdMob의 Privacy & messaging에서 서비스 지역에 필요한 메시지를 준비한다. 앱은 동의 정보를 갱신하고 필요한 메시지와 개인정보 선택 진입점을 제공해야 한다. 광고 요청 가능 상태를 확인하며, 갱신·콜백이 겹쳐 광고가 중복 초기화되지 않게 한다. [Google UMP 안내](https://developers.google.com/admob/android/privacy)

현재 브리지에는 기본 광고 콜백은 있으나 별도 개인정보 선택 UI·동의 제어 호출은 확인되지 않는다. Adiz가 처리하는 범위와 앱이 추가해야 할 범위를 설치 버전 기준으로 검토한다. Adiz 내부 동의 처리와 별도 UMP 팝업을 중복 노출하지 않도록 통합한다.

Play 제출 시 계정 기능·광고 포함 여부·실제 SDK 수집 데이터를 기준으로 앱 콘텐츠와 데이터 관련 정보를 작성한다. 현재 ‘연결 해제 및 기기 초기화’는 일반 계정의 서비스 탈퇴와 다르다. 계정 생성 기능이 적용 대상이면 앱 내·외부 삭제 요청 경로를 별도로 준비해야 한다. [Google Play 계정 삭제 요구사항](https://support.google.com/googleplay/android-developer/answer/13327111)

## 6. 앱 개발에서 해야 할 작업

### 6.1 네이티브 브리지와 Android 빌드

현재 핵심 파일:

- `native/hive_android/plugin/build.gradle.kts`: Hive·Hercules·DataStore·Google·PGS·Adiz 의존성.
- `native/hive_android/plugin/src/main/java/com/jellymon/hive/HiveBridgePlugin.kt`: SDK 호출과 Godot 시그널.
- `addons/HiveBridge/export_plugin.gd`: 최종 APK에 AAR과 Maven 의존성 포함.
- `native/hive_android/plugin/src/main/AndroidManifest.xml`: 플러그인 등록·인터넷 권한·AdMob/PGS 메타데이터.

브리지 라이브러리를 빌드하는 Gradle과 Godot APK export 양쪽에 의존성이 들어가야 한다. 현재 Hive 26.4.0/Adiz 3.0.0 버전을 두 위치에서 맞추고 있다. SDK를 올릴 때 한쪽만 변경하지 않는다.

HiveActivity 생명주기와 Activity 결과·권한 결과 전달을 유지한다. 과거에는 Hercules 누락으로 초기화 후 앱이 종료되었다. 템플릿 교체 뒤에는 최종 APK에 플러그인·라이브러리가 실제 포함되는지 다시 확인한다.

### 6.2 설정 파일 연결

| 파일 | 수정하는 값 | 반영 방법 |
| --- | --- | --- |
| `native/hive_android/plugin/src/main/res/raw/hive_config.xml` | App ID, Google/PGS 제공자 속성 | AAR 재빌드 후 APK 재빌드 |
| `native/hive_android/plugin/src/main/res/values/hive_ids.xml` | AdMob App ID, PGS 프로젝트 식별자 | AAR 재빌드 후 APK 재빌드 |
| `assets/data/platform_services.json` | zone, test_ads, 기능 플래그, 랭킹 주소 | APK 재빌드 |
| `export_presets.cfg` | 패키지·Gradle export·서명·버전 | APK/AAB 재빌드 |
| `server/leaderboard/.env` | 서버 환경·보드·Certification Key | 서버 프로세스 재시작 |

Google 제공자 XML의 `serverClientId`는 Web OAuth Client ID다. 현재 XML에는 `<google>`과 `<googleplaygames>`가 함께 있다. 속성명 대소문자를 보존하고, `playAppId`, `clientId`, PGS 프로젝트 번호를 이름만 보고 같은 값으로 채우지 않는다. 설치한 SDK의 해당 제공자 항목을 기준으로 매핑한다. `reversedClientId`는 iOS용 항목이며 Android 서명 등록을 대신하지 않는다. [Hive IdP 설정](https://developers.hiveplatform.ai/en/latest-version/dev/authv4/hive-sdk-prep/common/idp-console-keys/)

런타임 환경은 `PlatformService`가 JSON의 `android.zone`을 읽고 브리지에서 `Configuration.ZoneType.SANDBOX/REAL`로 설정한다. XML만 수정하고 JSON을 놓치면 기대한 환경으로 전환되지 않는다.

### 6.3 인증 흐름

```text
브리지 확인 → AuthV4.setup → 초기화 성공
                         → 자동 로그인 가능 여부 확인
                         → AUTO 또는 showSignIn
                         → 성공 콜백의 Player ID 저장
                         → 기존 클라우드 확인 → 랭킹 동기화
```

개발 작업과 검수 기준:

- SDK 미포함, 초기화 중, 미로그인, 로그인 성공, 오류 상태를 구분한다.
- 초기화 실패·로그인 취소를 로컬 가짜 계정 성공으로 바꾸지 않는다.
- Player ID를 계정의 기준으로 사용하고 토큰은 필요한 요청 동안만 사용한다.
- 로그인 버튼 중복 입력과 앱 종료·복귀 중 늦은 콜백을 처리한다.
- 다른 계정으로 바뀌면 이전 계정의 저장·랭킹 응답을 적용하지 않는다.
- Google 로그인과 ‘현재 게스트를 Google에 연결하여 PID 유지’를 별도 시나리오로 검수한다.

현재 `계정 연결` 버튼의 로그인 성공이 게스트의 영구 Google 연동까지 증명하지는 않는다. 게스트 보존 연동을 제공하려면 Hive IdP 연동 API 흐름, 이미 다른 PID에 연결된 Google 계정 처리, 충돌 선택 UI를 추가 설계한다. 이 항목은 현재 브리지의 단순 로그인 호출과 구분해 관리한다.

### 6.4 연결 해제·기기 초기화의 실제 의미

현재 구현은 입력값이 정확히 `DELETE ACCOUNT`일 때 실행한다.

| 계정 상태 | 네이티브 처리 | 게임 로컬 데이터 |
| --- | --- | --- |
| 일반 연결 계정 | `AuthV4.signOut` | SDK 성공 후 초기화 |
| 게스트 계정 | 사용자에게 안내한 뒤 `AuthV4.playerDelete` | SDK 성공 후 초기화 |
| SDK 실패·입력 불일치·취소 | 완료로 처리하지 않음 | 유지 |

일반 계정 로그아웃은 Google 계정 삭제나 Google IdP 연결 해제 자체가 아니다. 게스트는 삭제 처리이므로 같은 계정에 다시 접근하지 못할 수 있다. 게임 코드는 Hive DataStore나 랭킹 서버의 데이터를 삭제하는 API를 호출하지 않는다. Hive 계정 삭제에 따른 서비스 측 보존·접근 정책은 별도로 확인해야 한다.

기기 초기화 이후에도 클라우드에 저장된 계정 데이터를 복구하려면 동일한 Hive Player ID로 다시 로그인해야 한다. 새 게스트 PID로 기존 게스트 데이터를 자동 이전하지 않는다.

### 6.5 랭킹 클라이언트

`SaveGame → RankingService → HTTPS API → Ranking 화면` 순서로 동작한다.

- 별 3개 최초 달성 시각을 레벨별로 기록한다.
- 유저별 최고 3성 모험 레벨 한 개만 대표 기록으로 보낸다.
- 레벨이 같으면 처음 3성으로 깬 시각이 빠른 사람이 위다. 최단 소요 시간 순위가 아니다.
- 100레벨 2성, 95레벨 3성이면 대표 기록은 95레벨이다.
- 같은 레벨 재클리어로 최초 시각을 갱신하지 않는다.
- 일일·주간 활동은 모험 랭킹 대상에서 제외한다.
- 최초 시각이 없는 과거 저장에 임의 날짜를 만들어 넣지 않는다.
- 로그인/기록 변경/조회 진입 시 동기화하고, 실패하면 재시도한다.
- 클라우드 충돌 처리 중에는 잘못된 계정 기록을 보내지 않도록 대기한다.

화면 위치는 **지도 → 하단 ‘모험 랭킹’**, ‘홈으로’ 왼쪽이다. 순위·닉네임·레벨·최초 달성 일시를 표시하고 현재 사용자를 강조한다. UTC 밀리초로 저장한 시각은 한국시간으로 표시한다.

### 6.6 보상형 광고

현재 흐름:

```text
초기화 → 기본 Rewarded 준비 → load → 준비 상태 표시
사용자 요청 → show → onRewarded 수신 → onClose에서 한 번만 지급
                                          → 다음 광고 사전 로드
```

구현된 주요 처리:

- 광고 준비 확인·재생을 Android UI 스레드에서 수행한다.
- 아직 로딩 중이면 안내만 하고, 로딩 완료 후 갑자기 자동 재생하지 않는다.
- 중복 요청·완료 콜백을 차단한다.
- 시청 취소·로드 실패를 보상 완료로 처리하지 않는다.
- 광고 보상은 기존 게임 저장 흐름으로 저장한다.

적용 위치는 클리어 보상 2배와 광고를 통한 레벨 구간 해금이다. 상품 안내의 보상 수량, 실제 지급 수량, 중복 수령 방지를 각각 확인한다.

추가 작업은 상용 광고 설정, 동의 선택 흐름, 네트워크 단절·Activity 복귀·장시간 시청 검수다. 현재 클라이언트 지급은 보상 콜백 직후 프로세스가 종료되는 경우의 서버 복구를 보장하지 않는다. 서버 기반 보상 보장이 필요하면 보상 거래 ID·검증·멱등 지급을 별도로 구현한다.

### 6.7 전체 게임 데이터 저장·복원

현재 구현은 `CloudSaveService.gd`와 브리지의 `loadGameSnapshot`/`saveGameSnapshot`을 사용한다. 기본 저장 키는 `jellymon_save_v1`이다. 이전 모험 요약 키 `jellymon_adventure_v1`과 구분한다.

| 저장 범위 | 예시 |
| --- | --- |
| 모험 기록 | 레벨별 별, 최단 클리어 시간, 기록 시각, 3성 최초 달성 시각 |
| 재화·아이템 | 별가루, 하트, 회복 기준 시각, 부스터 |
| 방과 주민 | 가구 소유·배치, 방 테마, 주민·관계·앨범 기록 |
| 진행 | 튜토리얼, 시나리오, 출석, 일일·주간·시즌 진행 및 수령 상태 |
| 사용자 설정 | 닉네임, 언어·효과음·진동 등 직렬화된 설정 |
| 제외 | 인증 토큰, 실제 사진 파일, 기기 분석 로그 |

정확한 필드 목록은 `SaveGame.to_dictionary()`와 `cloud_data()`가 기준이다. 구매 관련 플래그의 백업이 스토어 영수증 검증을 대신하지 않는다.

동기화 절차:

1. 로그인 후 원격 데이터를 먼저 읽는다.
2. 읽기 성공이며 키가 없을 때만 최초 업로드를 진행한다.
3. 마지막 동기화 기준과 원격 데이터가 같으면 변경된 로컬 내용을 보낸다.
4. 서로 다른 데이터가 있으면 클라우드 사용 / 기기 데이터 사용 / 나중에를 선택한다.
5. 저장 성공 콜백 뒤 다시 읽어 일치 여부를 확인한다.
6. 재조회까지 맞아야 `전체 게임 데이터 · Hive 저장 확인`을 표시한다.

읽기 오류를 ‘저장 없음’으로 처리하지 않는다. 재화가 감소한 저장도 반영하며 두 기기의 재화를 합산하지 않는다. 현재 앱 제한은 저장 JSON 512 KiB이며 Hive 전체 서비스 제한이라고 해석하지 않는다.

모의 테스트는 구현되어 있으나 실제 Hive 왕복 저장·다른 기기 복원 성공은 별도 검수가 남아 있다. 단순 get/set 방식의 동시 쓰기 경쟁을 완전히 방지하려면 서버 버전 잠금 또는 세션 제어를 추가해야 한다.

## 7. 랭킹 서버에서 해야 할 작업

### 7.1 실행 환경

현재 구현 경로는 `server/leaderboard`이며 Node.js + TypeScript + SQLite를 사용한다. 저장소 기준 Node.js 22.13 이상이 필요하고 Docker 기본 이미지는 Node 24다. 실제 운영 런타임 버전은 서버 README와 함께 고정한다.

```sh
cd server/leaderboard
cp .env.example .env
chmod 600 .env
# .env 값을 비공개 편집기로 입력
npm ci
npm test
npm start
```

`.env`가 이미 있으면 복사 명령으로 덮어쓰지 않는다.

```dotenv
HIVE_APP_ID=com.jellymon.game
HIVE_LEADERBOARD_ID=163
HIVE_CERTIFICATION_KEY=<서버에만 입력>
HIVE_ZONE=sandbox
RANKING_DB_PATH=./data/ranking.sqlite3
HOST=127.0.0.1
PORT=8787
```

`npm start`는 `.env`를 읽지만 기존 프로세스 환경변수가 우선할 수 있다. 설정 수정 후 프로세스를 재시작하고 실제 적용 환경을 키 원문 없이 점검한다.

### 7.2 인증·접수·Hive 등록

| API | 역할 | 성공 의미 |
| --- | --- | --- |
| `GET /healthz` | 서버 및 DB 상태 | Hive 인증 확인은 아님 |
| `GET /v1/ranking/top` | Hive 상위 100명 조회 | 현재 캐시/조회 결과; 신규 등록 증거와 별도 |
| `POST /v1/ranking/record` | 토큰 검증 후 기록 접수 | 202이면 Hive 전송 대기, 200과 조회 반영도 확인 필요 |

앱은 Player ID·DID·레벨·별·최초 달성 시각·닉네임과 Hive 토큰을 보낸다. 서버는 Hive v2 인증 응답과 요청 계정을 검증하고 유효한 3성 기록만 저장한다. 토큰 없는 임의 `curl` POST를 성공 테스트로 사용하지 않는다.

Hive 리더보드 API는 서버의 Certification Key를 Bearer 인증으로 사용한다. 현재 서버는 발급된 값을 그대로 전달하며, OAuth Client Secret으로 새 JWT를 만드는 구조가 아니다. [Hive Leaderboard API](https://developers.hiveplatform.ai/en/latest/api/leaderboard-api/)

### 7.3 정렬 규칙

현재 코드의 점수 계산은 다음과 같다.

```text
score = level × 500000000000
        + 499999999999
        - (achieved_at_ms - 1767225600000)
```

높은 레벨이 항상 앞서고, 같은 레벨에서는 이른 시각이 높은 점수가 된다. 현재 지원 범위는 레벨 1~1000, 기준 시각은 2026-01-01 UTC다. 날짜 오프셋은 500000000000ms 미만이어야 한다. 규칙을 바꾸려면 기존 점수와의 호환 및 보드 버전을 검토한다.

닉네임·실제 레벨·별·최초 시각은 `extraData`에 함께 저장한다. 이 형식이 아닌 임의 점수를 163번에 넣으면 조회 검증이 실패할 수 있다. 완전히 같은 레벨·시각은 현재 코드에서 PID 문자열 순으로 표시한다.

### 7.4 배포·보존·미전송 기록

- HTTPS 도메인과 인증서를 준비하고 앱에는 기본 URL만 설정한다.
- 현재 ngrok 도메인은 테스트 주소로 기록한다. 운영에는 지속 가용성·도메인 유지·모니터링 계획을 정한다.
- SQLite 파일을 영구 볼륨에 둔다. 재배포 때 임시 파일 시스템에 저장하지 않는다.
- Hive 실패 시 서버는 전송 대기를 남겨 30초 간격으로 재시도한다.
- 현재는 단일 서버/SQLite 구조다. 여러 인스턴스 운영 전 공용 DB·동시 갱신 처리를 설계한다.
- DB 백업과 복구 검수를 준비한다. 볼륨 삭제 명령을 일반 재시작에 사용하지 않는다.
- 전송 완료로 표시된 과거 행이 Hive에 실제 존재하는지 대조하는 운영 절차가 필요하다.

현재 전송 완료 판정은 Hive POST 성공을 사용하며 모든 기록의 재조회 대조를 자동 보장하지 않는다. 과거 누락 복구에는 PID별 최고 기록 대조와 안전한 재전송 절차를 추가한다.

클라이언트가 보고한 별·시간에 대한 범위 검증은 있지만 실제 플레이를 서버가 재연산하지는 않는다. 기기 시각 변경이나 변조 클라이언트를 막는 경쟁 랭킹이 필요하면 서버 플레이 검증을 별도 구현한다.

## 8. 빌드와 개발/운영 환경 전환

### 8.1 환경 대조표

| 항목 | 현재 테스트 | 출시 전 목표 |
| --- | --- | --- |
| JSON `android.zone` | `sandbox` | `real` |
| 네이티브 Hive Zone | SANDBOX | REAL |
| 랭킹 서버 `HIVE_ZONE` | `sandbox` | `live` |
| JSON `android.test_ads` | `true` | 상용 설정 후 `false` |
| AdMob App ID | 테스트용 설정 | 실제 앱 ID |
| 랭킹 URL | ngrok 테스트 주소 | 운영 HTTPS 주소 |
| 서명 | 개발 APK 서명 | 배포 방식에 맞는 release/Play 서명 |
| 콘솔 | 개발 프로젝트·환경 확인 | 실제 운영 대상 프로젝트·환경 확인 |

앱은 `real`, 자체 랭킹 서버는 `live`라는 문자열을 사용한다. 서버에 `real`을 넣으면 현재 서버 설정 검증에서 실패한다. 개발 PID·기록이 운영으로 자동 이전된다고 가정하지 않는다. 운영 보드 ID도 콘솔에서 확인하여 지정한다.

### 8.2 AAR 및 APK 빌드

프로젝트 루트에서 실행한다. 아래 경로는 현재 개발 PC 기준이다.

```sh
export ANDROID_HOME=/Users/kimsk/Library/Android/sdk
export JAVA_HOME=/opt/homebrew/opt/openjdk@21

# Kotlin/Android 리소스/네이티브 의존성을 바꾼 경우
android/build/gradlew -p native/hive_android plugin:copyDebugAar plugin:copyReleaseAar

# Godot 게임 및 설정을 포함한 테스트 APK
/Users/kimsk/Documents/dev/tool/Godot.app/Contents/MacOS/Godot \
  --headless --path . --export-debug Android output/JellyMon.apk
```

현재 Godot은 일반 4.7 stable 템플릿을 사용한다. `4.7.stable`과 `4.7.stable.mono`를 혼용하지 않는다. Gradle Build와 HiveBridge export 플러그인을 활성화한다. debug/release AAR 경로 모두 최신인지 확인한다.

Play 배포용 AAB는 별도의 release 서명·버전 코드·export 설정으로 만든다. 개발 APK 설치 성공만으로 Play 배포 검수를 끝내지 않는다.

### 8.3 테스트폰 업데이트 설치

```sh
/Users/kimsk/Library/Android/sdk/platform-tools/adb devices -l
/Users/kimsk/Library/Android/sdk/platform-tools/adb -s R3CM70FDW9D \
  install --no-incremental -r output/JellyMon.apk
```

`-r` 업데이트 설치는 기존 데이터를 유지한다. 서명이 다르다는 오류가 나오면 먼저 사용한 keystore를 확인한다. 로그인 재검증을 위해 곧바로 앱 삭제나 `pm clear`를 실행하지 않는다.

## 9. 기능별 검수 절차

### 9.1 로그인

| 절차 | 기대 결과 |
| --- | --- |
| 첫 실행 | 초기화 성공 후 사용 가능한 로그인 수단 표시 |
| 게스트 선택 | 실제 Hive 로그인 성공, 유효한 PID |
| 앱 종료·재실행 | 의도한 동일 계정 유지 |
| Google 로그인 | 선택 계정으로 성공, 취소 시 오류 상태 정리 |
| Play 배포 서명으로 설치 | debug 때와 별도로 Google 로그인 성공 |
| 다른 계정 선택 | 이전 계정 저장을 자동 업로드하지 않음 |
| 연결 해제 입력 오타 | 실행 불가, 데이터 유지 |
| 해제 SDK 실패 | 로그인·게임 데이터 유지 |

영구 Google 연동을 검수할 때는 연결 전후의 PID가 유지되는지 확인한다. 단순히 ‘로그인 완료’라는 문구만 비교하지 않는다.

### 9.2 랭킹

1. `/healthz`와 `/v1/ranking/top`을 각각 확인한다.
2. 실제 로그인한 테스트 계정으로 아직 최초 시각이 없는 모험 레벨을 3성 클리어한다.
3. 앱 전송 결과, 서버 접수 결과, Hive 상세 조회, 게임 TOP 100을 대조한다.
4. 같은 레벨을 늦게 달성한 다른 계정이 아래에 나오는지 확인한다.
5. 더 높은 레벨을 3성 달성하면 더 위에 나오는지 확인한다.
6. 1·2성 기록, 이벤트 기록, 같은 레벨 재도전으로 최초 시각이 바뀌지 않는지 확인한다.
7. 서버/Hive 장애 후 재접속했을 때 전송 대기가 복구되는지 확인한다.

읽기 전용 서버 확인 예시:

```sh
curl --fail -H 'ngrok-skip-browser-warning: true' \
  https://engrailed-sadye-curatively.ngrok-free.dev/healthz
curl --fail -H 'ngrok-skip-browser-warning: true' \
  https://engrailed-sadye-curatively.ngrok-free.dev/v1/ranking/top
```

`entries: []`는 빈 보드 조회 성공일 수 있다. 실제 점수 등록 성공은 특정 PID의 레벨·시각까지 일치해야 한다.

### 9.3 광고

- 테스트 광고임을 확인하고 끝까지 시청 → 닫기 → 보상 한 번 지급.
- 중도 종료 → 보상 미지급.
- 로드 실패·오프라인 → 안내 후 재시도 가능, 잘못된 지급 없음.
- 버튼 연타 → 광고 중복 시작·보상 중복 없음.
- 광고 후 앱 복귀 → 조작·타이머·음악 정상.
- 보상 지급 후 재실행 → 지급 상태 유지.
- 레벨 해금 광고와 클리어 보상 광고를 각각 시험.
- 상용 설정은 테스트 기기에서 별도 확인하고 동의 선택 흐름까지 시험.

### 9.4 DataStore

1. 현재 계정의 PID, 레벨·별·재화·방 배치를 기록한다.
2. `클라우드 저장 / 복원` 실행 후 쓰기·재조회 완료 메시지를 확인한다.
3. Hive 콘솔에서 같은 PID의 `jellymon_save_v1` 내용과 비교한다.
4. 재화 증가뿐 아니라 아이템 사용으로 감소한 값도 저장되는지 확인한다.
5. 다른 테스트 기기에서 **같은 계정/PID**로 로그인한다.
6. 충돌 팝업에서 클라우드 사용을 선택하고 진행·가구·재화를 대조한다.
7. 기기 데이터 사용·나중에 선택도 각각 검수한다.
8. 네트워크 단절 시 기존 원격 데이터가 빈 값으로 덮이지 않는지 확인한다.
9. 계정 전환 중 이전 요청의 응답이 새 계정에 적용되지 않는지 확인한다.

게스트 삭제나 기기 데이터 초기화를 먼저 실행해 복원 대상 계정에 접근하지 못하게 만드는 방식으로 검수하지 않는다. 동일 계정으로 재접근 가능한 테스트 계정을 사용한다.

### 9.5 저장소 내 자동 검사

다음은 모의 SDK/서버 기반 검사이며 실제 콘솔 연동 성공을 대신하지 않는다.

```sh
# Godot 실행 파일이 PATH에 있을 때
Godot --headless --path . tools/verify_cloud_save.tscn
Godot --headless --path . tools/verify_account_disconnect.tscn
Godot --headless --path . tools/verify_account_reset.tscn

cd server/leaderboard
npm test
```

화면 검수용 `verify_cloud_save_ui.tscn`, `verify_disconnect_ui.tscn`, `verify_ranking.tscn`은 각 스크립트의 실행 조건을 확인해 GUI 환경에서 수행한다. 위 명령은 재검수 절차이며 이번 문서 작성 중 새로 실행한 테스트 목록은 아니다.

## 10. 장애 진단

| 증상 | 먼저 볼 곳 | 확인·조치 |
| --- | --- | --- |
| `Hive 미포함` | APK export | Gradle Build, HiveBridge 활성화, AAR 포함 여부 |
| `로컬 개발 모드` | PlatformService | 실제 Android 브리지와 로그인 콜백인지 구분 |
| `unknown client` | Hive 초기화 | App ID·환경·보안 키·콘솔 로그인 설정 |
| `Hercules is not found` 후 종료 | APK 의존성 | Hercules AAR 및 네이티브 라이브러리 포함 |
| 게스트 성공, Google 실패 | Google OAuth | Web Client ID, Android 패키지/SHA-1, 테스터 |
| APK 성공, Play 설치본 실패 | Play 서명 | Play App Signing 인증서 SHA-1 등록 |
| 광고 미준비 | Adiz | 초기화/로드 콜백, 기본 Rewarded, 실제 ID·동의 상태 |
| 광고 종료 후 보상 없음 | 게임/광고 콜백 | onRewarded와 onClose 순서·요청 식별·지급 기록 |
| healthz 성공, 랭킹 502 | 서버→Hive | 인증키·보드·환경·Hive HTTP 응답 분리 |
| 랭킹 보드 준비 상태 | Hive 운영 기간 | 타임존과 시작 시각·현재 운영 상태 |
| POST 202 | 서버 전송 대기 | DB의 대기 상태·30초 재시도·Hive 오류 |
| 과거 기록만 없음 | 서버 DB와 Hive | 전송 완료 표시만 믿지 말고 PID별 대조 |
| 랭킹 형식 오류 | 보드 extraData | 전용 점수 규칙과 JSON 스키마 일치 |
| DataStoreDisabled | Hive 제품 설정 | 사용 활성화·SDK 재초기화 |
| DataStore 공개키 오류 | 같은 게임 설정 | 저장소 발급 키와 제품 설정 키 대조 |
| DataStore 401 Auth Fail | 인증/서비스 설정 | 현재 PID·환경·설정 조회, 재로그인/재실행으로 재현 |
| DataStore 500 | Hive 응답 | 재시도 후 반복되면 시각·환경·오류 코드로 문의 |
| 저장 성공인데 복원 안 됨 | 계정·키·내용 | 동일 PID, `jellymon_save_v1`, 실제 값과 충돌 선택 |
| Android version mismatch | export 템플릿 | 실행 엔진 버전과 일반/mono 템플릿 일치 |

진단 기록에는 앱 버전·서명 구분·SDK 버전·zone·요청 시각·호출 단계·오류 코드를 남긴다. 담당자에게 PID를 전달할 필요가 있다면 비공개 지원 채널을 사용한다. 전체 logcat에는 SDK 토큰 등이 섞일 수 있으므로 공유 전에 비밀값을 제거한다.

DataStore 401/500은 해당 응답만으로 공개키 오류라고 단정하지 않는다. 같은 게임의 저장소와 키가 일치하고 재초기화 후에도 재현된다면 Hive 지원에 정확한 발생 시각과 환경을 전달한다.

## 11. 출시 전 작업 목록

### Hive 콘솔 담당

- [ ] 운영 프로젝트/App ID·보안 키·Auth v4 확인.
- [ ] 로그인 제공자·약관·운영 상태 확인.
- [ ] 운영 리더보드의 ID·누적·내림차순·기간·UTC+09:00 확인.
- [ ] 운영 서버에 제공할 Certification Key 보관·권한 확인.
- [ ] Adiz 실제 Rewarded 기본 광고 매핑.
- [ ] DataStore 공개키 저장 및 실제 PID 데이터 조회.

### Google 콘솔 담당

- [ ] Android/Web OAuth 클라이언트와 소속 Cloud 프로젝트 대조.
- [ ] debug/release/Play 서명별 SHA-1 등록·검수.
- [ ] 동의 화면·테스트 사용자·공개 상태 확인.
- [ ] PGS를 서비스한다면 별도 자격증명·테스터·공개 상태 확인.
- [ ] AdMob 실제 앱·Rewarded 단위·테스트 기기 설정.
- [ ] 개인정보 메시지·Play 제출 정보·계정 삭제 요청 경로 준비.

### 앱 개발 담당

- [ ] Google 실제 로그인 검수 및 게스트 영구 연동 필요 범위 구현.
- [ ] 광고 개인정보 선택·동의 흐름 통합.
- [ ] DataStore 실제 저장·재조회·동일 계정의 다른 기기 복원 검수.
- [ ] 일반 로그아웃·게스트 삭제·기기 초기화 안내 구분.
- [ ] 운영 zone·광고 ID·test_ads·서버 주소 전환.
- [ ] 최종 release/AAB 의존성·서명·실기기 복귀·장애 처리 검수.

### 서버 개발·운영 담당

- [ ] 지속 운영할 HTTPS 주소와 프로세스 자동 재시작 준비.
- [ ] 운영 환경·보드·인증키·영구 DB 확인.
- [ ] 과거 누락 기록 대조·재전송 방법 마련.
- [ ] DB 백업·복구 및 장애 시 전송 대기 검수.
- [ ] 필요 수준에 맞는 요청 제한·감사 로그·플레이 검증 추가.

우선순위는 **DataStore 실제 성공 확인 → Google 계정 보존/복원 검수 → 상용 광고·동의 설정 → 운영 랭킹 안정화 → 최종 Play 배포본 통합 검수**로 잡는다. 현재 게스트·테스트 광고 성공 이력을 근거로 나머지 항목을 완료 처리하지 않는다.

## 12. 관련 파일과 공식 자료

### 프로젝트 내부 문서

- [Android 설정 및 과거 진단](HIVE_ANDROID_SETUP.md)
- [보상형 광고](HIVE_REWARDED_ADS.md)
- [별 3개 모험 랭킹](HIVE_THREE_STAR_RANKING.md)
- [전체 클라우드 저장](HIVE_CLOUD_SAVE.md)
- [계정 연결 해제](HIVE_ACCOUNT_DISCONNECT.md)
- [Node.js 랭킹 서버 운영](../server/leaderboard/README.md)

### 구현 진입점

| 기능 | 파일 |
| --- | --- |
| 플랫폼 설정 | `assets/data/platform_services.json` |
| Godot 네이티브 연결 | `scripts/PlatformService.gd` |
| Hive SDK 호출 | `native/hive_android/plugin/src/main/java/com/jellymon/hive/HiveBridgePlugin.kt` |
| 로그인·초기화 후 화면 전환 | `scripts/Main.gd`, `scripts/Title.gd` |
| 저장 스키마 | `scripts/SaveGame.gd` |
| 저장 동기화·선택 UI | `scripts/CloudSaveService.gd`, `scripts/CloudSaveDialog.gd` |
| 랭킹 앱 서비스 | `scripts/RankingService.gd` |
| 서버 인증·Hive API | `server/leaderboard/src/hive.ts` |
| 서버 점수·SQLite | `server/leaderboard/src/ranking.ts` |
| 서버 HTTP·재시도 | `server/leaderboard/src/server.ts` |
| Android export 의존성 | `addons/HiveBridge/export_plugin.gd` |

공식 문서 링크는 해당 설정 절차 옆에 배치했다. 최신 문서와 프로젝트에 설치된 SDK 버전이 다르면 설치 버전의 API·의존성을 우선 대조한 뒤 변경한다.
