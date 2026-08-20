# HIVE Android 로그인·보상형 광고 설정

프로젝트에는 Godot 4.7용 Android v2 플러그인 `HiveBridge`가 포함되어 있다.
게임 코드는 `PlatformService.gd`만 호출하며 네이티브 구현은 다음 순서로 동작한다.

1. `AuthV4.setup`
2. 기존 세션이 있으면 `ProviderType.AUTO`, 없으면 HIVE `showSignIn` UI
3. HIVE 초기화 성공 후 `Adiz.initialize`
4. 보상형 광고 `initialize → load → show → onRewarded`
5. `onClose`에서 보상 여부를 Godot으로 전달하고 다음 광고를 다시 로드

## 적용 버전

- Godot 4.7 stable mono
- HIVE SDK Native Android 26.4.0
- Hive Adiz Android 3.0.0
- Android minSdk 24 / targetSdk 36

## HIVE Console에서 필요한 작업

1. App Center에서 Android AppID를 만든다.
2. 현재 기본 package/AppID인 `com.jellymon.game`과 콘솔 AppID를 일치시킨다.
3. **Sandbox와 상용 환경 각각** App Center > Security Key Settings에서 보안 키를 발급한다. SDK 25.0.0 이상은 보안 키가 없으면 로그인되지 않는다.
4. 약관 그룹을 연결하고 인증 메뉴에서 Guest, Google, Google Play Games 중 노출할 IdP와 순서를 설정한다.
5. Google Cloud/Play Games에서 OAuth 클라이언트를 만들고 debug·release 서명 인증서의 SHA-1을 등록한다.
6. Adiz/AdMob 메뉴에 Android 앱과 Rewarded 광고 단위를 등록하고 Rewarded 기본 광고(`is_default=true`)를 지정한다.

## 프로젝트에 실제 키 입력

- `native/hive_android/plugin/src/main/res/raw/hive_config.xml`
  - `appId`
  - Google `playAppId`, `clientId`, `serverClientId`, `reversedClientId`
  - 개발은 `zone=sandbox`, 출시는 `zone=real`
- `native/hive_android/plugin/src/main/res/values/hive_ids.xml`
  - `admob_app_id`: 현재 값은 Google 공식 테스트 App ID
  - `game_services_project_id`: Google Play Games 프로젝트 번호
- `assets/data/platform_services.json`
  - 개발 중 `test_ads=true`
  - 출시 전에 반드시 `test_ads=false`

키를 수정한 뒤 브리지 AAR을 다시 만든다.

```sh
android/build/gradlew -p native/hive_android plugin:copyDebugAar plugin:copyReleaseAar
```

`native/hive_android/local.properties`는 개발 PC 전용 Android SDK 경로라 Git에 저장하지 않는다.

## Android 내보내기

Android preset에는 Gradle Build, INTERNET, ACCESS_NETWORK_STATE가 켜져 있다. Godot에서 Android를 export하면 `addons/HiveBridge`의 AAR과 Maven 의존성이 자동으로 포함된다.

개발 중에는 실제 광고 대신 Adiz 테스트 광고만 사용한다. 실제 광고를 테스트 기기 등록 없이 반복 클릭하면 AdMob의 무효 트래픽으로 판단될 수 있다.

## 확인 항목

- 앱 첫 실행 시 HIVE 약관/초기화 화면이 정상 표시되는가
- 메뉴 > 계정 연결에서 HIVE 로그인 UI가 열리는가
- 로그인 성공 후 `HIVE 연결됨`과 PlayerID가 유지되는가
- 클리어 보상 2배 광고가 로드되고 끝까지 본 경우에만 보상이 지급되는가
- 광고를 닫거나 로드에 실패하면 보상이 지급되지 않는가
- 한 광고가 끝난 뒤 다음 광고가 미리 로드되는가

로그인은 실제 Android 기기와 올바른 서명 인증서에서 최종 검증해야 한다. 에뮬레이터 또는 서명 SHA-1이 다른 APK에서는 Google 계정 인증이 실패할 수 있다.

## 실기기 진단 결과 (2026-08-19)

Godot 플러그인 등록과 HIVE Activity 생명주기 전달은 완료했다. 현재 샌드박스의
`com.jellymon.game`은 HIVE 서버에서 아래 오류를 반환한다.

```text
AuthV4InvalidParam(-1200060)
Client authentication failed: unknown client.
```

이 상태에서는 `AuthV4.setup()` 다음 단계인 약관, 로그인 제공자 목록, Adiz 초기화가
진행되지 않는다. 위의 HIVE Console 작업 중 Security Key 발급, AppID별 Sign-in Settings 저장,
Google OAuth 키 등록과 약관 배포/프로젝트 연결을 완료해야 실기기 최종 검증이 가능하다.

약관 기준은 `agreementDetermineBase=device`다. 콘솔 설정을 완료한 뒤 새 설치에서 약관 화면이
한 번 표시된다. 재검증 시에는 앱 데이터를 지우거나 HIVE `resetAgreement()`를 사용한다.

보상형 광고는 `onRewarded`를 받은 뒤 `onClose`가 호출된 경우에만 보상을 지급한다.
중간 종료는 `rewarded=false`로 처리하여 보상을 지급하지 않는다.
개발 빌드의 테스트 광고는 콘솔 인증 오류와 별도로 광고 콜백을 검증할 수 있지만,
상용 빌드는 약관/인증 초기화 성공 뒤에만 광고를 초기화한다.
