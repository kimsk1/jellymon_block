# Hive 보상형 광고 — 2026-09-09

Hive Adiz Android 3.0.0 보상형 광고 모듈은 HiveBridge에 포함되어 있다. 게임에서는 Main.request_rewarded_ad → PlatformService → HiveBridge → Adiz 경로로 호출한다.

## 적용 위치

- 클리어 화면의 광고 시청 보상 2배
- 광고 시청을 통한 레벨 구간 해금

## 이번 보완

- 광고 준비 여부 조회와 재생을 Android UI 스레드에서 수행.
- 광고가 아직 준비되지 않았으면 재시도를 안내하고 로드한다. 로드 완료 후 자동으로 뒤늦게 재생하지 않는다.
- 진행 중 중복 요청 무시.
- 진행 중인 요청의 onRewarded만 인정하고 onClose에서 한 번만 완료 전달.
- 사전 로드 실패가 게임의 보상 콜백을 불필요하게 호출하지 않도록 구분.
- 광고 종료 후 다음 광고 로딩 상태 전송.

보상 시청 완료 후 앱 프로세스가 종료되기까지의 보상 복구를 보장하는 서버 지급 시스템은 별도 범위다. 현재 보상은 게임의 기존 로컬 저장 흐름을 사용한다.

## 테스트 및 상용 설정

현재 `test_ads=true` 및 Google 공식 테스트 App ID를 사용한다. 상용 광고로 운영하려면 Hive/AdMob 앱 및 Rewarded 광고 설정을 완료하고 실제 App ID 적용, test_ads=false 전환 후 빌드해야 한다.

테스트: GDScript 서비스의 중복 요청, 중복 완료 콜백, 시청 취소 미지급 검사 통과. Native debug/release 브리지 및 Android APK 빌드 완료.

Galaxy Note10에 기존 데이터를 유지한 채 APK를 업데이트하고 클리어 화면에서 Google 테스트 보상형 광고를 실제 재생했다. 광고 시청 완료 및 닫기 후 게임으로 복귀했고, 클리어 보상이 6개에서 12개로 변경되면서 보유 별가루가 30개에서 36개로 증가했다. 보상 수령 버튼의 완료 처리와 다음 광고 사전 로드도 확인했다. 시청 취소 미지급은 자동 검사로 확인했으며, 레벨 구간 해금의 실기기 광고 시청은 이번 검사에 포함하지 않았다.

- APK: `output/hive-ads/JellyMon-hive-ads-debug.apk`
- 광고 재생 화면: `output/hive-ads/ad-showing.png`
- 보상 지급 화면: `output/hive-ads/rewarded.png`
- 실행 로그: `output/hive-ads/device.log`

공식 가이드: https://developers.hiveplatform.ai/ko/latest/dev/ad-monetization/hive-adiz/android/
