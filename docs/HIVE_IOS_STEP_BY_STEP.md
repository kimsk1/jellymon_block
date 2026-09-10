# JellyMon Hive iOS 연동: 단계별 설정·개발 가이드

작성일: 2026-09-10  
대상: 현재 JellyMon Godot 4.7 프로젝트의 iOS 확장  
목적: 앞서 안내한 1~5번을 순서대로 진행하고, 각 단계의 완료 여부를 확인한다.

> 2026-09-10 기준으로 iOS Hive 브리지와 Hive Auth v4, DataStore, Adiz 의존성 연결을 구현했다. `com.jellymontest.game`으로 서명한 iPhone용 앱 빌드와 테스트폰 설치까지 성공했다. 실제 기기의 Hive 초기화·로그인·저장·광고 왕복 검수는 테스트폰 잠금을 푼 뒤 앱을 실행해 완료한다. Google 로그인은 iOS OAuth Client ID와 reversed Client ID를 추가로 반영해야 한다.

## 시작 전: 진행 순서와 준비물

| 순서 | 작업 | 주 담당 | 완료 증거 |
| --- | --- | --- | --- |
| 1 | Apple·Hive 앱 등록 및 서명 | 운영자 + 개발자 | iOS 식별자·서명 정보 확보 |
| 2 | Google 로그인 설정 | 운영자 + 개발자 | iOS OAuth 정보와 URL Scheme 확보 |
| 3 | Godot iOS Hive 브리지 | 개발자 | iPhone에서 실제 Hive 게스트 PID 발급 |
| 4 | 공통 서비스 코드 수정 | 개발자 | iOS 분기와 오류 상태 정상 처리 |
| 5 | 랭킹·저장·광고 통합 | 운영자 + 개발자 | 실서비스 왕복 검수 성공 |

실제로는 3번 브리지와 4번 공통 코드 수정을 함께 진행해야 로그인 검수가 가능하다. 로그인 확인 후 5번의 DataStore → 랭킹 → 광고 순서로 확장한다.

준비물:

- [ ] Apple Developer Program에 가입된 팀과 해당 팀 접근 권한.
- [ ] Xcode가 설치된 Mac.
- [ ] USB 또는 개발 연결이 가능한 테스트 iPhone.
- [ ] Hive JellyMon 프로젝트의 앱센터·인증·DataStore·리더보드·Adiz 접근 권한.
- [ ] Google Cloud 및 AdMob 접근 권한.
- [ ] 기존 Android와 같은 게임 데이터를 공유할지 결정.

이번 프로젝트에서는 **같은 JellyMon 게임 프로젝트 안에 iOS 앱을 추가하는 구성**을 기준으로 한다. 별도 Hive 프로젝트를 만들면 계정·데이터·리더보드 공유 조건이 달라질 수 있다.

### 작업 기록표

공개 식별자는 아래에 기록해도 되지만, 비밀키는 비공개 보관소에 저장한다.

| 항목 | 기록할 값 |
| --- | --- |
| Apple 팀 이름 | 직접 기입 |
| Apple Team ID | 직접 기입: 보통 10자리 영문·숫자 식별자 |
| iOS Bundle ID | 직접 기입 |
| Hive 프로젝트 이름·번호 | 기존 JellyMon 프로젝트 확인 |
| Hive iOS App ID | 콘솔에 등록된 정확한 값 |
| 테스트 환경 | sandbox |
| Google iOS OAuth Client ID | 직접 기입 |
| Google Web OAuth Client ID | 직접 기입 |
| Google reversed client ID / URL Scheme | 직접 기입 |
| AdMob iOS App ID | 직접 기입 |
| AdMob iOS Rewarded 단위 ID | 직접 기입 |
| 리더보드 | 기존 163 사용 가능 여부 확인 |
| 실제 테스트 PID | 비공개 검수 기록에 기입 |
| 비밀키 보관 위치 | 위치만 기입, 원문 금지 |

Team ID, Bundle ID, Hive App ID, Google Client ID는 서로 다른 값이다. 이름이 비슷하다는 이유로 같은 값을 넣지 않는다.

## 1. Apple·Hive 콘솔 준비

### 1-1. Apple 팀 확인

**담당: 운영자**

1. [Apple Developer Account](https://developer.apple.com/account/)에 로그인한다.
2. 계정의 Membership details에서 팀 이름과 Team ID를 확인한다.
3. 여러 팀이 있다면 JellyMon을 출시할 팀을 선택한다.
4. 개발자가 Xcode에서 같은 팀을 선택할 수 있도록 필요한 권한을 부여한다.
5. 위 작업 기록표에 Team ID를 적는다.

현재 `export_presets.cfg`의 Team ID는 `XZNDHJ52PQ`, Bundle ID는 `com.jellymontest.game`으로 설정되어 있다. 다른 Apple 팀으로 배포할 때 두 값을 해당 팀의 등록 정보와 함께 변경한다.

**완료 확인:** 운영자가 보는 팀과 개발자 Xcode에 표시되는 팀이 같다.

### 1-2. Bundle ID와 Apple App ID 등록

**담당: 운영자**

1. Apple Developer → **Certificates, Identifiers & Profiles → Identifiers**로 이동한다.
2. `+`를 누르고 App IDs → App을 선택한다.
3. Description에 `JellyMon`처럼 식별 가능한 이름을 입력한다.
4. Explicit Bundle ID를 선택하고 사용할 고유 Bundle ID를 입력한다.
5. 필요한 Capability를 선택하고 등록한다.

현재 개발 빌드는 `com.jellymontest.game`을 사용한다. 출시용 식별자를 바꾸면 Apple, Hive, Google OAuth, AdMob과 Godot export preset을 같은 값 기준으로 다시 맞춘다.

[Apple App ID 등록 안내](https://developer.apple.com/help/account/identifiers/register-an-app-id)

**완료 확인:** Identifiers 목록에 해당 앱이 있고 Bundle ID가 기록표와 일치한다.

### 1-3. Sign in with Apple 활성화

**담당: 운영자 + 개발자**

1. 등록한 App ID 상세 화면을 연다.
2. Sign in with Apple Capability를 활성화한다.
3. 새 독립 앱이면 기본 App ID 설정을 사용하고, 기존 앱 계정과 그룹화할 경우에는 그 관계를 먼저 확인한다.
4. 저장한다.
5. Xcode 프로젝트 생성 후 앱 Target → Signing & Capabilities에도 Sign in with Apple을 추가한다.
6. Capability 변경 후 서명 프로파일이 새 권한을 포함하도록 갱신한다.

[Apple 로그인 Capability 안내](https://developer.apple.com/help/account/capabilities/about-sign-in-with-apple/)

**구분:** iOS 네이티브 Apple 로그인과 Android/웹의 Apple 로그인은 준비 항목이 같지 않다. 웹 흐름을 함께 제공하거나 Hive가 해당 흐름에 요구할 때 Services ID·도메인·Return URL·서버 키를 설정한다. iOS 네이티브 로그인만을 위해 임의의 웹 Return URL을 만들지 않는다. `.p8` 개인키를 앱에 넣지 않는다.

**완료 확인:** Apple App ID와 Xcode 앱 Target 양쪽의 Capability가 일치한다.

### 1-4. Xcode 계정·서명·테스트폰 준비

**담당: 개발자**

1. Xcode → Settings → Accounts에서 Apple 계정을 추가한다.
2. 테스트 iPhone을 연결하고 기기에서 이 컴퓨터를 신뢰한다.
3. iPhone에서 개발 실행에 필요한 Developer Mode를 활성화한다. Xcode나 기기에 안내가 나타나면 따른다.
4. iOS 프로젝트를 만든 뒤 앱 Target의 Signing & Capabilities에서 Team을 지정한다.
5. 처음에는 Automatically manage signing을 사용해 개발 서명을 구성한다.
6. 실제 Bundle Identifier를 1-2에서 등록한 값으로 맞춘다.
7. 실행 대상을 연결된 iPhone으로 선택하고 기본 게임부터 Run한다.

자동 서명이 불가능한 조직 환경에서는 Apple Development 인증서, 등록 기기, 해당 App ID가 들어간 개발 Provisioning Profile을 준비해 수동 지정한다. TestFlight용 배포 서명은 개발 기기 설치용 프로파일과 구분한다.

**완료 확인:** Hive 기능 이전에 기본 JellyMon 화면이 iPhone에서 실행된다. 서명 오류가 있으면 SDK 오류 조사보다 이 단계를 먼저 해결한다.

### 1-5. App Store Connect 앱 등록

**담당: 운영자**

1. [App Store Connect](https://appstoreconnect.apple.com/) → Apps로 이동한다.
2. `+` → New App을 선택한다.
3. 플랫폼 iOS, 앱 이름, 기본 언어를 입력한다.
4. Bundle ID 목록에서 1-2의 App ID를 선택한다.
5. 내부 관리용 SKU를 입력하고 앱을 생성한다.
6. 이후 TestFlight에 업로드할 앱인지 확인한다.

[Apple 앱 등록 안내](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)

**완료 확인:** 앱 상세 페이지의 Bundle ID가 실제 Xcode Target과 같다. SKU는 Hive App ID나 OAuth Client ID가 아니다.

### 1-6. Hive에 iOS App ID 추가

**담당: 운영자**

1. Hive Console에서 기존 JellyMon 프로젝트를 선택한다.
2. 앱센터의 App ID 관리에서 iOS 앱 항목을 추가한다.
3. 플랫폼·마켓을 iOS/App Store에 맞게 설정하고 Bundle ID 등 요청되는 정보를 입력한다.
4. 생성된 **Hive iOS App ID**를 별도로 기록한다. Bundle ID와 자동으로 같다고 가정하지 않는다.
5. 개발 환경 sandbox의 보안 키 발급·활성 상태를 확인한다.
6. Auth v4 사용, 약관 연결 및 배포 상태를 확인한다.
7. iOS에서 제공할 게스트·Google·Apple 로그인 수단을 설정한다.
8. Game Center를 사용하지 않을 경우 별도 기능처럼 추가하지 않는다. Apple 로그인과 Game Center는 다르다.

Hive는 SDK 설치 전 App ID 등록을 요구하며, Native 25.0.0 이상은 인증 보안 키 발급이 필요하다. [Hive iOS 사전 준비](https://developers.hiveplatform.ai/en/v4.26.4.0/dev/overview/getting-started/pre-install/ios-pre-install/), [Native 보안 키 안내](https://developers.hiveplatform.ai/ko/latest-version/releases/native/)

**완료 확인:** 같은 JellyMon 프로젝트 아래 Android와 iOS 항목이 있고, iOS App ID·sandbox 설정·로그인 제공자를 다시 열어 확인할 수 있다.

### 1-7. DataStore·리더보드·광고 콘솔 사전 확인

**담당: 운영자**

- DataStore: 기존 게임 저장소와 공개키의 소속 게임을 확인한다. 기존 저장소를 무작정 새로 만들거나 키를 교체하지 않는다.
- 리더보드: 같은 게임의 보드 163을 공동 사용하려는지 확인한다. 누적·내림차순·운영 중 상태를 확인한다.
- 광고: AdMob iOS 앱과 iOS 광고 단위를 따로 만든 뒤 Hive Adiz의 iOS 앱에 매핑한다. 상세 절차는 5-3에서 진행한다.

**1번 완료 체크**

- [ ] Team ID·Bundle ID·Hive iOS App ID를 구분해 확보했다.
- [ ] Apple 로그인 Capability를 설정했다.
- [ ] Xcode에서 올바른 팀으로 서명할 수 있다.
- [ ] App Store Connect 앱이 준비됐다.
- [ ] Hive iOS 인증·약관·보안 키 설정을 저장했다.

## 2. Google 로그인 설정

### 2-1. 기존 Google Cloud 프로젝트 선택

**담당: 운영자**

1. [Google Cloud Console](https://console.cloud.google.com/)을 연다.
2. Android JellyMon OAuth를 관리하는 프로젝트를 선택한다.
3. Google Auth Platform의 Branding/Audience/Clients 또는 APIs & Services의 OAuth 화면으로 이동한다.
4. 앱 이름·지원 연락처·사용자 유형을 확인한다.
5. 테스트 상태라면 사용할 Google 계정을 테스트 사용자로 등록한다.

Android와 iOS 계정 공유를 계획한다면 먼저 같은 Google 프로젝트와 Hive 게임의 연결 관계를 확인한다. 새 Cloud 프로젝트부터 만들지 않는다.

### 2-2. iOS OAuth Client ID 생성

**담당: 운영자**

1. Clients 또는 Credentials에서 OAuth Client 생성을 선택한다.
2. Application type을 **iOS**로 지정한다.
3. 이름을 `JellyMon iOS`처럼 입력한다.
4. Bundle ID에 1-2에서 정한 정확한 값을 입력한다. 현재 테스트 앱은 `com.jellymontest.game`이다.
5. 콘솔에서 추가로 요청하는 App Store ID·Team ID 항목이 있으면 해당 Apple 정보로 입력한다.
6. 생성된 iOS Client ID와 제공되는 설정 정보를 보관한다.
7. 기존 Web application Client ID도 확인하여 구분해 기록한다.

Android OAuth의 SHA-1을 iOS에 대신 등록하는 단계는 없다. [Google iOS 로그인 준비](https://developers.google.com/identity/sign-in/ios/start-integrating)

### 2-3. URL Scheme과 Hive 설정 값 전달

**담당: 운영자 → 개발자**

| 전달 항목 | 목적 |
| --- | --- |
| iOS OAuth Client ID | iOS 앱을 식별하는 Google 자격증명 |
| Web OAuth Client ID | Hive 제공자 설정의 `serverClientId` 대조 |
| Reversed Client ID | Google 로그인 후 앱으로 돌아오는 URL Scheme |
| Bundle ID | Google·Apple·Xcode 값 일치 확인 |

개발자는 Hive iOS 제공자 설정에 요구되는 값과 URL Scheme을 반영한다. Google 공식 문서의 직접 SDK 설정과 Hive의 래퍼 설정은 구분한다. Hive를 사용할 때 직접 Google 로그인 샘플 전체를 중복 설치하지 않는다.

`serverClientId`는 Web 유형 Client ID이며 iOS Client ID와 다르다. `reversedClientId`는 iOS 로그인 복귀 설정에 사용한다. 설치한 Hive 버전의 iOS 예시를 기준으로 적용한다. [Hive IdP별 키 입력](https://developers.hiveplatform.ai/en/latest-version/dev/authv4/hive-sdk-prep/common/idp-console-keys/)

### 2-4. 개발자가 Xcode에 반영할 내용

1. Hive Google 제공자 모듈을 SDK 의존성에 추가한다.
2. iOS용 Hive 설정 리소스에 필요한 제공자 설정을 넣는다.
3. URL Types/URL Schemes에 Google의 reversed client ID를 등록한다.
4. URL 열기 콜백과 앱 복귀 이벤트를 Hive가 요구하는 방식으로 전달한다.
5. 기존 Godot AppDelegate/Scene 처리와 충돌하거나 이중 호출하지 않도록 구성한다.

Google 설정 변경이 Android XML에만 반영되어 있으면 iOS에는 적용되지 않는다. iOS 번들에 들어갈 설정 파일을 따로 확인한다.

### 2-5. Google 로그인 검수 — 3·4번 구현 후

1. iPhone에서 Hive 로그인 화면을 연다.
2. Google을 선택하고 테스트 계정으로 로그인한다.
3. 로그인 완료 후 게임으로 돌아오는지 확인한다.
4. 실제 Hive Player ID가 전달되는지 확인한다.
5. 취소하면 로그인 성공 처리하지 않는지 확인한다.
6. 앱 재실행 후 같은 계정이 유지되는지 확인한다.
7. 게스트를 Google에 연결하는 기능은 연결 전후 PID 유지 여부를 따로 검사한다.

**2번 완료 체크**

- [ ] iOS OAuth와 Web OAuth를 구분했다.
- [ ] Bundle ID가 Apple·Google에서 일치한다.
- [ ] 테스트 계정 접근 권한을 설정했다.
- [ ] 개발자에게 Client ID와 URL Scheme 정보를 전달했다.
- [ ] 실제 로그인 성공 검수는 브리지 구현 후 진행할 항목으로 남겨 두었다.

## 3. Godot iOS Hive 브리지 개발

이 절은 콘솔에서 수행할 수 없는 **개발 작업**이다. 아래 구조와 브리지 API는 현재 프로젝트에 구현되어 있다.

### 3-1. 기본 iOS export부터 검증

1. 현재 Godot 4.7 실행 파일과 맞는 iOS export template을 설치한다.
2. Project → Export → iOS를 선택한다.
3. Team ID·Bundle Identifier·버전·빌드 번호를 설정한다.
4. `build/ios` 등 출력 폴더로 Xcode 프로젝트를 내보낸다.
5. Xcode에서 프로젝트를 열고 1-4의 서명 설정으로 iPhone에 실행한다.

Godot iOS export는 macOS와 Xcode를 사용한다. [Godot iOS 내보내기](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)

현재 preset의 최소 iOS 버전은 14.0이지만, 적용할 Hive·Adiz·Google SDK와 Xcode가 요구하는 최소 버전을 대조해 최종 결정한다. Android SDK와 같은 버전 번호가 iOS에서 반드시 호환된다고 가정하지 않는다.

**완료 확인:** 세로 화면·터치·기본 게임이 정상 실행된다. 이때 로컬 플레이 성공을 Hive 성공으로 기록하지 않는다.

### 3-2. SDK 설치 방식과 버전 고정

현재 구성은 CocoaPods 방식이며 Hive SDK 26.4.0, Hive Adiz 3.0.0, iOS 14.0 이상으로 고정되어 있다.

1. Mac에서 `xcodebuild -version`, `pod --version`으로 도구를 확인한다.
2. CocoaPods가 없다면 개발 환경의 Ruby/패키지 관리 방식에 맞게 설치한다.
3. Hive iOS SDK의 설치·기능 문서에서 적용할 버전을 선택한다.
4. [`native/hive_ios/Podfile`](../native/hive_ios/Podfile)의 Xcode 앱 Target 이름과 버전을 확인한다.
5. Hive Core/인증, Google 제공자, 필요한 보안 모듈, DataStore, Adiz 의존성을 선택한다.
6. `pod install` 후 생성된 `.xcworkspace`를 연다.
7. Podfile과 Podfile.lock을 보관하고 빌드가 재현되는지 확인한다.

Hive 공식 저장소를 Podfile source에 등록하는 방식은 [Hive iOS SDK 설치](https://developers.hiveplatform.ai/en/latest-version/dev/overview/getting-started/install/ios-install/)를 따른다. 정확한 Pod 이름·버전·링커 설정은 선택한 SDK 문서에서 가져온다. SPM과 Pods에 같은 라이브러리를 중복 등록하지 않는다.

Godot에서 iOS 프로젝트를 내보낸 다음 [`tools/prepare_ios_hive.sh`](../tools/prepare_ios_hive.sh)를 실행한다. 생성된 `build/ios/JellyMon.xcworkspace`를 Xcode로 열어야 하며 `.xcodeproj`를 직접 열면 Pods로 연결한 Hive가 빠진다.

### 3-3. 브리지 파일 구성

```text
native/hive_ios/                  # Objective-C++ 소스, Podfile, SCons 설정
  plugin/hive_bridge.mm           # Godot ↔ Hive 연결
  plugin/hive_bridge_module.cpp   # singleton 등록
  hive_config.xml                 # Hive iOS 런타임 설정
ios/plugins/HiveBridge/          # Godot이 찾을 플러그인
  hive_bridge.gdip
  hive_bridge.xcframework
  hive_config.xml
```

1. Godot 엔진 헤더와 연결되는 Objective-C++ 플러그인을 만든다.
2. 현재 Godot export template과 같은 버전의 헤더를 사용한다.
3. Godot singleton으로 메서드와 시그널을 등록한다.
4. `.gdip`에서 초기화 함수·바이너리·의존성·필요한 plist 항목을 지정한다.
5. `ios/plugins` 아래에 넣고 Godot iOS export의 Plugins에서 활성화한다.

Godot은 `.gdip`와 정적 라이브러리 또는 정적 라이브러리를 담은 XCFramework를 지원한다. [Godot iOS 플러그인 개발](https://docs.godotengine.org/en/stable/tutorials/platform/ios/ios_plugin.html)

기기용 arm64와 시뮬레이터용 arm64는 서로 다른 빌드 대상이다. 최종 인증·광고 검수는 실제 iPhone에서 한다.

### 3-4. 공통 브리지 계약 구현

다음 이름은 기존 Android 브리지와 맞출 **앱 내부 API 계약**이다. Hive iOS SDK의 실제 함수 이름이 모두 같다는 뜻은 아니다.

| 앱 내부 메서드 | iOS 구현 책임 |
| --- | --- |
| `initialize(test_ads, sandbox)` | 환경 설정, SDK 초기화, 결과 시그널 |
| `login()` | 자동/명시적 로그인, PID·오류 전달 |
| `isGuestAccount()` | 현재 계정의 게스트 여부 |
| `disconnectAccount(...)` | 명시적 확인 후 SDK 처리 및 결과 |
| `prepareRankingAuth(request_id, player_id)` | 현재 계정의 유효한 토큰 확보 |
| `loadGameSnapshot(request_id, player_id)` | 전체 저장 키 조회 |
| `saveGameSnapshot(request_id, player_id, json)` | 전체 저장 키 쓰기 |
| `isRewardedAdReady()` | 광고 준비 여부 |
| `showRewardedAd()` | 사용자 요청으로 광고 표시 |
| `reloadRewardedAd()` | 다음 광고 로드 |

메서드 인수·시그널 이름·순서는 `scripts/PlatformService.gd`와 Android `HiveBridgePlugin.kt`를 기준으로 맞춘다. iOS SDK 호출 결과를 이 계약으로 변환한다.

개발 기준:

- SDK UI는 메인 스레드에서 호출한다.
- Godot 객체 접근과 시그널 전달은 안전한 게임 스레드 경로로 전환한다.
- 앱 활성화·백그라운드·URL 복귀 이벤트를 전달한다.
- 로그인 또는 광고 요청 연타를 방지한다.
- 계정이 바뀐 후 도착한 이전 요청을 무시한다.
- SDK 오류 코드는 남기되 토큰·키 원문은 출력하지 않는다.

### 3-5. 내보내기 후 설정 자동화

Godot에서 다시 export하면 출력 Xcode 프로젝트가 바뀔 수 있다. Xcode에서만 수동 수정한 뒤 끝내지 않는다.

1. 원본 플러그인·Podfile 템플릿·설정 리소스를 출력 폴더 밖에 보관한다.
2. export 후 의존성 설치와 리소스 반영을 재실행할 스크립트를 준비한다.
3. Sign in with Apple entitlement, URL Scheme, Hive 설정 파일의 Target 포함 여부를 확인한다.
4. 깨끗한 출력 폴더에 재export해도 같은 기능이 실행되는지 검수한다.

**3번 완료 체크**

- [x] 기본 iPhone 빌드 및 서명 성공.
- [x] Hive 플러그인 singleton이 앱 실행 파일에 등록됨.
- [x] Auth v4·DataStore·Adiz와 설정 리소스가 앱에 포함됨.
- [ ] 실제 iPhone에서 SDK 초기화 성공 확인.
- [ ] 실제 게스트 로그인 성공과 PID 발급.
- [x] 재export → `pod install` → Xcode 재빌드 성공.

## 4. 기존 공통 서비스 코드 수정

### 4-1. 플랫폼별 설정 분리

**수정 대상:** `assets/data/platform_services.json`, `scripts/PlatformService.gd`

현재 `PlatformService.gd`는 OS 이름에 따라 `android`와 `ios` 설정을 각각 읽는다. iOS 설정은 다음 형태로 반영되어 있다.

```json
{
  "ios": {
    "singleton": "HiveBridge",
    "bundle_id": "com.jellymontest.game",
    "zone": "sandbox",
    "test_ads": true
  }
}
```

1. OS 이름으로 Android/iOS/데스크톱을 구분한다.
2. 선택한 플랫폼 설정에서 singleton·zone·test_ads를 읽는다.
3. 브리지 초기화에 올바른 환경을 전달한다.
4. 로그에 플랫폼·환경·초기화 성공 여부를 표시한다.
5. Android 기존 설정이 바뀌지 않았는지 회귀 검사한다.

### 4-2. Android 전용 메서드 조회 분리

현재 로그인 해제·랭킹·저장 경로에는 `has_java_method()`가 있다. iOS 플러그인은 Java 객체가 아니다.

1. 공통 메서드 존재 확인 함수를 만든다.
2. Android에서는 기존 Java 방식으로 확인한다.
3. iOS에서는 Godot에 등록된 메서드 조회 방식으로 확인한다.
4. 없는 기능은 미지원 상태를 반환한다.
5. iOS에서 Android 전용 검사 함수를 호출하지 않는지 확인한다.

로그인만 성공시키고 이 부분을 놓치면 랭킹 토큰·DataStore 호출에서 실패할 수 있다.

### 4-3. 로컬 성공 대체 처리 제한

현재 코드는 Android 이외 플랫폼을 로컬 개발 모드로 처리하고, 일부 debug 광고 요청에 모의 보상을 지급한다.

1. 로컬 모의 모드를 데스크톱 개발용으로 명시적으로 제한한다.
2. Android와 iOS는 브리지가 없으면 `Hive 미포함` 또는 `미연결`로 표시한다.
3. iPhone에서 광고 SDK 없이 광고 보상이 지급되지 않게 한다.
4. 실제 PID가 없으면 랭킹·클라우드 동기화를 시작하지 않는다.

**완료 확인:** iOS 브리지를 끈 테스트 빌드에서 로그인 성공/광고 완료로 표시되지 않는다.

### 4-4. 계정 연동·로그아웃·탈퇴 구분

현재 Android 구현은 일반 계정에 `signOut`, 게스트에 확인 후 `playerDelete`를 사용한다. iOS에 그대로 복사하기 전에 선택한 SDK의 지원과 의미를 확인한다.

| 동작 | 요구되는 결과 |
| --- | --- |
| 로그인 | 계정 인증 후 PID 확보 |
| 게스트→Google/Apple 연동 | 기존 PID를 보존하는 IdP 연결 검수 |
| 로그아웃 | 세션 종료; 외부 Google/Apple 계정 삭제와 다름 |
| 기기 초기화 | 사용자 요청대로 로컬 게임 데이터 초기화 |
| 서비스 탈퇴 | 서버 데이터·외부 인증 해지까지 별도 정책·구현 |

`DELETE ACCOUNT` 확인은 현재 프로젝트의 연결 해제/초기화 UI 정책이다. 그 문구를 입력받는 것만으로 App Store의 계정 삭제 요구사항이 충족되지는 않는다. Google 등 외부 로그인 제공 시 로그인 선택지와 계정 생성 앱의 삭제 요구사항을 검토한다. [Apple 심사 지침 4.8 및 5.1.1](https://developer.apple.com/app-store/review/guidelines/)

**4번 완료 체크**

- [x] iOS 설정 분리.
- [x] Java 전용 검사 분리.
- [x] 기기에서 로컬 가짜 성공 처리 차단.
- [ ] 계정 전환 시 이전 데이터 적용 차단.
- [ ] Android 로그인·광고·저장 회귀 검사.

## 5. 랭킹·DataStore·광고 통합

### 5-1. 먼저 DataStore 저장·복원

**콘솔 담당**

1. Hive → 게임 데이터 스토어 → 데이터 관리에서 JellyMon 저장소를 확인한다.
2. 저장소가 없는 경우에만 생성하고 공개키를 확보한다.
3. 같은 게임의 앱센터 → Hive 제품 설정에서 DataStore 사용·공개키 저장 상태를 확인한다.
4. iOS 앱이 같은 게임과 올바른 환경을 사용하는지 대조한다.

[Hive DataStore 콘솔 절차](https://developers.hiveplatform.ai/ko/latest/operation/game-data-store/)

**개발 담당**

1. Hive iOS DataStore 모듈은 CocoaPods와 브리지에 추가되어 있다.
2. 브리지의 읽기·쓰기 결과는 기존 `CloudSaveService` 계약에 연결되어 있다.
3. 현재 전체 저장 키 `jellymon_save_v1`을 사용한다.
4. 저장 형식·스키마·PID 확인·크기 검사·충돌 선택을 유지한다.
5. 읽기 실패를 빈 저장으로 처리하지 않는다.
6. 쓰기 후 재조회 결과가 같을 때만 저장 완료를 표시한다.

[Hive iOS DataStore 준비](https://developers.hiveplatform.ai/en/latest/dev/datastore/hive-sdk-prep/ios/)

**검수 순서**

1. iPhone 로그인 PID와 현재 레벨·재화·방 배치를 기록한다.
2. 저장하고 앱의 `Hive 저장 확인` 상태를 확인한다.
3. Hive 콘솔에서 해당 PID의 키와 데이터를 조회한다.
4. 두 번째 기기에서 같은 계정으로 로그인한다.
5. 같은 PID인지 확인한 후 클라우드 복원을 선택한다.
6. 재화 감소·가구 변경·충돌 취소도 검사한다.

Android와 iOS에서 같은 이메일을 선택했다고 같은 Hive PID가 보장되는 것은 아니다. 계정 연동이 먼저 검증되어야 하며 닉네임/이메일 기준으로 데이터 병합을 구현하지 않는다. 기존 Android DataStore는 실제 401/500 오류가 있었으므로, iOS 추가만으로 그 문제가 해결된다고 보지 않는다.

**완료:** 콘솔 조회와 두 기기 복원 값이 일치한다.

### 5-2. 랭킹 서버에 iOS 인증 지원

**콘솔 담당**

1. Android/iOS가 같은 게임의 누적 랭킹을 사용할지 확정한다.
2. 보드 163의 내림차순·누적·운영 기간과 환경을 확인한다.
3. 해당 게임의 서버 Certification Key를 서버 운영자에게 비공개로 제공한다.

인증키 위치와 sandbox/live API 구분은 [Hive Leaderboard API](https://developers.hiveplatform.ai/en/latest/api/leaderboard-api/)를 참고한다.

**개발 담당**

현재 `server/leaderboard/src/hive.ts`는 `HIVE_APP_ID` 한 개로 토큰 검증을 한다.

1. iOS Hive App ID가 Android 값과 다른지 확인한다.
2. 다르면 서버 설정에 허용된 앱 목록 또는 플랫폼별 매핑을 추가한다.
3. 요청의 플랫폼/앱 식별자는 허용 목록에서만 선택한다.
4. 클라이언트가 보낸 임의 App ID나 인증 서버 주소를 그대로 신뢰하지 않는다.
5. 해당 App ID로 Hive 토큰을 검증하고 검증된 PID로 기록한다.
6. iOS 브리지에서 필요한 토큰을 `RankingService`에 전달한다.
7. 기존 별 3개·최고 레벨·최초 시각·TOP 100 규칙을 유지한다.

iOS도 현재 `prepareRankingAuth`에서 Hive access token, player token, DID와 PID를 기존 랭킹 서비스에 전달한다. Android와 iOS의 Hive App ID가 다르면 랭킹 서버의 허용 앱 설정은 별도로 확장해야 한다.

**검수 순서**

1. Android 테스트 계정의 기존 조회가 정상인지 확인한다.
2. iPhone에서 다른 테스트 계정으로 모험을 3성 클리어한다.
3. 서버 접수와 Hive 163번 기록을 확인한다.
4. 양쪽 기기에서 같은 TOP 100 결과가 보이는지 확인한다.
5. 같은 레벨은 먼저 달성한 계정이 위에 있는지 확인한다.

서버 `/healthz` 성공은 Hive 점수 등록 성공과 다르다. POST 202는 전송 대기이며 최종 조회에서 PID·레벨·시각까지 대조한다.

### 5-3. iOS 광고 설정

**AdMob 담당**

1. AdMob → Apps → Add app으로 이동한다.
2. 플랫폼 **iOS**를 선택한다.
3. 스토어 등록 여부에 맞게 앱을 추가한다.
4. iOS App ID를 기록한다: `ca-app-pub-…~…`.
5. 앱의 광고 단위에서 Rewarded를 만든다.
6. Rewarded 광고 단위 ID를 기록한다: `ca-app-pub-…/…`.
7. 테스트 기기와 광고 개인정보 메시지를 설정한다.

Android 광고 ID를 iOS 앱에 복사하지 않는다.

**Hive 담당**

1. Adiz에서 JellyMon iOS 앱을 선택한다.
2. 위 iOS Rewarded 단위를 매핑한다.
3. 기본 Rewarded로 사용할 광고 설정을 확인하고 저장한다.
4. 앱 식별자·환경·사용 상태를 대조한다.

**개발 담당**

1. 호환되는 Hive Adiz iOS SDK를 추가한다.
2. 앱 Info.plist에 iOS AdMob App ID 등 SDK 요구 설정을 반영한다.
3. 필요한 광고 네트워크 식별자·개인정보 리소스는 해당 SDK 문서를 따라 포함한다.
4. 테스트 모드로 초기화·로드·재생·보상·종료 콜백을 구현한다.
5. 기존 게임의 보상 요청 식별과 한 번만 지급하는 처리를 연결한다.
6. 광고 후 음향·타이머·화면 복귀를 검수한다.

[Hive Adiz iOS 안내](https://developers.hiveplatform.ai/en/latest/dev/ad-monetization/hive-adiz/ios/)

광고 지역별 동의 흐름과 iOS 추적 권한은 구분한다. 추적하는 경우 ATT 권한 및 설명 문구를 준비하고, 거부해도 게임 이용이나 보상을 부당하게 막지 않는다. 단순히 광고를 넣었다는 이유로 모든 경우에 ATT 팝업을 강제하는 식으로 구현하지 않는다. [Apple 개인정보·추적 지침](https://developer.apple.com/app-store/review/guidelines/)

**광고 검수**

| 행동 | 기대 결과 |
| --- | --- |
| 테스트 광고 끝까지 보고 닫기 | 보상 1회 |
| 중도 종료 | 보상 없음 |
| 버튼 연타 | 광고/보상 중복 없음 |
| 오프라인·로드 실패 | 안내와 재시도, 잘못된 지급 없음 |
| 광고 도중 백그라운드 후 복귀 | 게임 상태 정상 |
| 보상 후 재실행 | 지급 상태 보존 |

### 5-4. TestFlight 통합 검수

1. Xcode에서 release/archive 가능한 서명 상태를 만든다.
2. 앱 버전과 빌드 번호를 설정한다.
3. Product → Archive 후 Organizer에서 App Store Connect로 업로드한다.
4. 처리 완료 후 TestFlight 내부 테스트 빌드를 배포한다.
5. 외부 테스트가 필요하면 해당 검토 절차와 테스트 정보를 준비한다.
6. TestFlight 설치본으로 로그인·복원·랭킹·광고를 다시 시험한다.
7. App Store 제출 정보에 실제 SDK 데이터 사용, 광고, 계정·삭제 기능을 반영한다.

개발 USB 설치와 TestFlight 배포본의 환경이 같다는 가정은 하지 않는다. 검수 기록에 앱 빌드 번호와 Hive zone을 남긴다.

**5번 완료 체크**

- [ ] iPhone DataStore 저장·재조회 성공.
- [ ] 동일 계정의 다른 기기 복원 성공.
- [ ] Android/iOS 양쪽 랭킹 인증·등록·조회 성공.
- [ ] iOS 테스트 광고 재생·보상·취소 검수.
- [ ] TestFlight 설치본 통합 검수.

## 부록 A. 막혔을 때 확인할 항목

### 2026-09-10 실제 기기 실행 오류 수정

#### iOS 광고 초기화가 진행되지 않음

- 기존 브리지는 `UIApplication.sharedApplication.delegate.window`에서만 광고 표시용 컨트롤러를 찾았다. Godot 4.7 SwiftUI 실행에서는 이 값이 nil이어서 Adiz 초기화 전에 반환했다.
- 활성 `UIWindowScene`의 key window를 조회해 실제 게임 화면 컨트롤러를 사용하도록 수정했다.
- 2026-09-10 16:51 실제 iPhone에서 `delegate_window=0`이지만 Scene에서 화면을 찾았고, Adiz `initialized success=1 code=0` 및 보상형 광고 `state=ready`를 확인했다. 설정은 sandbox, test_ads=true이며 테스트 광고 로드 성공을 뜻한다. 실광고 운영 설정과 시청 완료 보상 검수는 별도다.

#### Google 로그인 `-1200105`

- 설치된 iOS Hive 26.4.0 헤더에서 이 코드는 `AuthV4ProviderMissingKey`이며 로그인 제공자 설정 키가 누락됐다는 뜻이다.
- 조사 당시 iOS `hive_config.xml`에는 `providers/google`이 없었고, 테스트폰 설치에 사용한 앱의 Info.plist에도 Google 복귀 URL Scheme이 없었다. Hive 초기화 성공과 Google 로그인 설정 완료는 별개다.
- Google Cloud Console의 같은 프로젝트에서 **iOS 유형**, Bundle ID **`com.jellymontest.game`**인 OAuth Client ID를 생성하거나 확인한다. 위 2-2 절을 따른다.
- 이 iOS Client ID에서 Reversed Client ID를 만들고, Hive의 `<google clientId="iOS OAuth Client ID" serverClientId="웹 OAuth Client ID" reversedClientId="iOS Reversed Client ID" />` 설정과 Info.plist의 `CFBundleURLTypes`에 반영한 후 재빌드한다. 설치된 26.4.0 ProviderGoogle은 `clientId`와 `serverClientId`를 각각 읽으므로 `clientId`를 반드시 명시한다. 공식 예시의 `serverClientId`와 `reversedClientId` 두 속성만 복사하면 이 SDK에서는 iOS Client ID가 누락된다. [Hive Google 키 설정](https://developers.hiveplatform.ai/en/latest-version/dev/authv4/hive-sdk-prep/common/idp-console-keys/)
- Android 설정의 Web Client ID는 이미 존재한다. 다만 Android 설정에 있는 `reversedClientId`는 Web Client ID를 역순으로 만든 값이므로 iOS용으로 그대로 복사하지 않는다. 실제 iOS OAuth Client ID 확인이 필요하다.
- 후속 작업에서 전달받은 iOS OAuth Client ID `233149254808-ua4q690ufoo2i7huo13cfvndb26dks88.apps.googleusercontent.com`을 기준으로 Reversed Client ID를 반영했다. iOS 원본 및 플러그인의 `hive_config.xml`에는 기존 Web Client ID와 iOS Reversed Client ID를 설정했고, `export_presets.cfg`의 iOS `application/additional_plist_content`에 Google 복귀 URL Scheme을 추가했다. Google 콘솔의 해당 OAuth 클라이언트 Bundle ID는 `com.jellymontest.game`이어야 한다. 실제 Google 로그인 완료는 기기에서 별도로 확인한다.
- `clientId` 속성 누락을 수정한 후 2026-09-10 16:47:58 실제 iPhone에서 `login success=1 code=0` 콜백을 확인했다. 초기화 역시 `setup success=1 code=0`이었다. 로그인 결과 진단 파일에는 결과 코드와 누락 키 메시지만 저장하며 계정 ID와 토큰은 저장하지 않는다.

#### Hive 초기화 후속 검증

- 설치된 iOS Hive 26.4.0 헤더에서 `-1200011`은 `AuthV4InvalidParamDid`이며 상세 메시지는 `Failed to seup. Empty DID.`다. 공통 웹 오류표와 숫자 배치가 다르므로 설치된 iOS 헤더를 기준으로 해석한다.
- `native/hive_ios/plugin/hive_app_delegate.mm`에서 Godot의 앱 시작 이벤트를 `HIVEAppDelegate`로 전달하도록 보완했다.
- 기존 iOS 설정의 `<market>AS</market>`를 공식 App Store 값인 `AP`로 수정했다. 환경은 sandbox다.
- 앱 시작 연결 보완만으로는 DID 오류가 남았지만, 마켓 코드 수정 후 실제 iPhone에서 `did_present=true`를 확인했다.
- 2026-09-10 16:10 테스트의 다음 오류는 `-1200056 / [AuthV4-Common] Invalid response data : `다. 따라서 DID 오류는 해결됐으나 Hive 초기화·로그인 성공은 아직 확인되지 않았다.
- 같은 날 후속 실행에서 초기화 응답 수신 뒤 `HerculesService.swift:59: useHercules is true. Hercules framework should exist.`로 앱이 종료되는 별도 문제를 확인했다. 현재 Podfile에는 선택 모듈 Hercules가 없으므로 `AuthV4.setup` 전에 `[HIVEConfiguration setUseHercules:NO]`를 호출하도록 수정했다. 추후 Hercules를 사용할 때는 동일 SDK 버전의 모듈을 추가한 뒤 활성화한다. [공식 Hercules 설정 안내](https://developers.hiveplatform.ai/en/v4.25.5.0/dev/hercules/getting-started/)
- `-1200056`은 설치된 iOS SDK의 `AuthV4InvalidResponseData`다. 이 코드만으로 App ID 등록 오류나 Hercules 누락이 원인이라고 단정하지 않는다. 초기화 성공 여부는 테스트폰의 `Documents/hive_initialization_status.json`에서 `success`와 `code`로 확인한다. 계정 로그인 성공은 별도로 확인해야 한다.
- 2026-09-10 16:21:59 수정 빌드의 실제 iPhone 실행에서 `setup success=1 code=0 did_present=1`을 확인했다. `-1200056`은 이 실행에서 재현되지 않았고, Hercules 누락으로 인한 종료도 발생하지 않았다. 계정 연결 버튼을 통한 로그인 완료는 별도 확인 항목이다.
- 기기 앱 Documents의 `hive_initialization_status.json`에는 마지막 초기화의 성공 여부·오류 코드·메시지·DID 존재 여부가 기록된다. DID 원문과 인증 토큰은 기록하지 않는다.
- 공식 마켓 설정: https://developers.hiveplatform.ai/en/v4.26.4.0/dev/basic-config/xml/common/

`build/ios/JellyMon.xcworkspace` 빌드는 성공했지만 앱 실행 직후 종료됐다.
기기의 `JellyMon-2026-09-10-153727.ips`에서 `TCC / SIGKILL`과
`NSUserTrackingUsageDescription` 누락을 확인했다. Hive 연동 SDK의 추적 권한
요청 시 iOS가 설명 문구를 찾지 못해 종료한 것이다.

`ios/plugins/HiveBridge/hive_bridge.gdip`과 `export_presets.cfg`에 한국어 설명을
추가했고 현재 출력본 `build/ios/JellyMon/JellyMon-Info.plist`에도 반영했다.
실제 빌드된 앱의 Info.plist에 해당 키가 포함되는 것을 확인한 후 재설치했다.
추적 허용 여부는 기기의 권한 팝업에서 사용자가 선택한다.

| 증상 | 우선 확인 |
| --- | --- |
| Signing requires a development team | Xcode Team, 실제 Team ID, 계정 권한 |
| Provisioning Profile 오류 | Bundle ID, 기기 등록, Capability, 자동 서명 상태 |
| Hive singleton 없음 | ios/plugins 위치, .gdip, export Plugins 활성화 |
| Undefined symbols / library not found | SDK 링크·아키텍처·Godot 헤더·Pods workspace |
| Framework 'AppAuth' not found | `build/ios/JellyMon.xcodeproj` 창을 닫고 같은 폴더의 `JellyMon.xcworkspace`를 연다. 왼쪽 목록에 JellyMon과 Pods가 함께 있어야 한다. |
| 초기화 성공 후 로그인 실패 | Hive iOS App ID, sandbox, 보안 키, 약관·제공자 |
| Google 로그인 후 복귀 안 됨 | reversed Client ID, URL Scheme, URL 전달 콜백 |
| Google 실패, 게스트 성공 | iOS OAuth Bundle ID, Web Client ID, 테스트 사용자 |
| Apple 로그인 실패 | Capability·entitlement·프로파일 일치 |
| iOS에서도 로컬 개발 모드 | PlatformService의 Android 외 플랫폼 처리 |
| 로그인 성공, 랭킹 실패 | Java 전용 검사, 토큰 전달, 서버 App ID 허용 설정 |
| DataStore 401 | 현재 PID·게임·환경·공개키 설정, SDK 재초기화 |
| DataStore 500 | 재현 시각·오류 코드로 Hive 서버 조사 |
| 광고 안 나옴 | iOS App ID/단위 ID, 기본 Rewarded, 로드·동의 상태 |
| 재export하면 실패 | 출력 Xcode에만 수동 반영한 설정 누락 |

오류를 전달할 때는 단계 번호, 앱 빌드 번호, OS/SDK 버전, 오류 문구, 발생 시각을 함께 기록한다. 키·토큰·전체 SDK 로그를 가리지 않고 공유하지 않는다.

## 부록 B. 운영 전환

| 항목 | 개발 | 운영 |
| --- | --- | --- |
| 앱 Hive zone | sandbox | real로 연결하도록 구현·검수 |
| 현재 랭킹 서버 zone 문자열 | sandbox | live |
| 광고 | 테스트 모드·테스트 기기 | 실제 매핑, 최종 설정 확인 |
| 서명 | 개발 실행 | App Store 배포 |
| 서버 주소 | 테스트 HTTPS | 지속 운영 HTTPS |
| 계정·기록 | 테스트 환경 | 운영 환경에서 새로 확인 |

개발 계정과 저장이 운영 환경으로 자동 이전된다고 가정하지 않는다. 운영 전환 때 보안 키·App ID·리더보드·DataStore·광고 설정을 환경별로 대조한다.

## 부록 C. 개발자에게 전달할 자료

설정이 끝난 항목부터 다음 형식으로 전달한다.

```text
완료 단계: 예) 1-1 ~ 2-3
Apple 팀 이름:
Apple Team ID:
iOS Bundle ID:
Hive 프로젝트 이름/번호:
Hive iOS App ID:
Hive 환경: sandbox
Google iOS Client ID:
Google Web Client ID:
Google reversed Client ID:
AdMob iOS App ID:
AdMob iOS Rewarded 단위 ID:
테스트 iPhone 모델 / iOS 버전:
남은 오류와 단계 번호:
```

비밀키·인증서 개인키·비밀번호는 이 양식에 넣지 않는다. 필요할 때 권한 있는 개발자가 비공개 저장 위치에서 설정한다.

## 부록 D. 관련 프로젝트 문서

- [Hive·Google 전체 연동 가이드](HIVE_GOOGLE_INTEGRATION_GUIDE.md)
- [현재 Android 설정](HIVE_ANDROID_SETUP.md)
- [DataStore 저장·복원](HIVE_CLOUD_SAVE.md)
- [계정 연결 해제](HIVE_ACCOUNT_DISCONNECT.md)
- [보상형 광고](HIVE_REWARDED_ADS.md)
- [모험 랭킹](HIVE_THREE_STAR_RANKING.md)
- [랭킹 서버 배포](../server/leaderboard/README.md)

이 문서의 제안 경로·구현 계약과 현재 존재하는 코드는 구분해서 읽는다. 공식 문서의 최신 페이지와 실제 설치할 SDK가 다르면 해당 버전의 지원 범위·필수 설정을 다시 대조한다.
