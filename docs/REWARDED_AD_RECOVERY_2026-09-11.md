# Android 보상 광고 실패 복구 (2026-09-11)

## 원인

테스트폰 기존 로그에서 AdMob `Internal error` 및 `Network error` 후 Hive Adiz `-101: Need load`가 반복됐다. 브리지는 `isLoaded()`가 true이면 계속 show를 호출했고, show 실패 후 광고 인스턴스 폐기·재로딩 경로가 없었다. SDK의 캐시된 로드 상태와 실제 광고 가용 상태가 어긋나면 앱 재시작 전까지 재생 실패가 반복될 수 있었다.

[Hive 공식 Android Adiz 문서](https://developers.hiveplatform.ai/en/v4.26.0.0/dev/ad-monetization/hive-adiz/android/)에서도 -101은 광고 로드 필요 상태이며, 종료 후 다음 노출 전에 다시 load가 필요하다고 설명한다.

## 변경

`native/hive_android/plugin/src/main/java/com/jellymon/hive/HiveBridgePlugin.kt`

- `onLoad` 콜백을 받은 광고만 게임에서 준비 완료로 취급한다.
- 재생 요청 시 준비 플래그를 소비하고, 실패 시 상태를 초기화한다.
- 실패한 광고 객체를 폐기하고 새 인스턴스로 재로딩한다. 대기는 2 → 4 → 8 → 16 → 최대 32초다.
- 로딩 중 중복 요청을 막는다. 재로딩이 끝나도 자동으로 광고를 띄우지 않는다.
- 세대 번호로 이전 객체에서 늦게 도착하는 콜백을 무시한다.
- 광고 종료 후 다음 광고를 준비한다. 앱 종료 시 예약 재시도를 취소한다.
- 보상 지급 조건은 `onRewarded` 확인 후 정상 종료로 유지한다.

## 검증

- Debug/Release AAR 빌드 성공. 두 AAR를 `addons/HiveBridge/bin/`에 반영.
- `output/JellyMon-ad-recovery.apk` 빌드 성공 및 DEX 안의 새 복구 코드 포함 확인.
- 실제 SM-N971N 테스트폰에 `adb install -r` 업데이트 설치 성공. 앱 데이터 유지.
- LEVEL 25를 정상 블록 이동으로 클리어하고 보상 2배 버튼을 눌러 테스트 광고 표시 확인.
- `onShow` → `onRewarded` → `onClose granted=true` → `rewarded completed=true` 확인.
- 광고 종료 직전 잠깐 네트워크를 차단해 다음 로드를 실패시켰다. DNS 실패 후 2/4/8/16초 재시도 로그와 네트워크 복구 뒤 `onLoad`, `state=ready` 확인. 앱 재시작 없이 복구됐다.
- Wi-Fi·모바일 데이터는 각각 원래 값 1로 복원하고 재확인했다.
- 테스트 과정에서 LEVEL 25가 2성으로 완료됐으며, 광고 보상까지 정상 게임 규칙에 따라 지급됐다.

로그: `/tmp/jellymon-ad-filtered.log`, `/tmp/jellymon-ad-bridge-build.log`, `/tmp/jellymon-ad-recovery-export-console.log`, `/tmp/jellymon-ad-recovery-verified.log`.

현재 설정은 `test_ads=true`다. 이번 확인은 실제 테스트 광고와 네트워크 복구 검증이며, 상용 광고 재고나 서버 장애 자체를 해결한다는 의미는 아니다.
