# Android 실기기 시작 시간 확인 — 2026-09-09

기기: Samsung Galaxy Note10 SM-N971N (Mali-G76). 현재 Android export preset으로 진단용 debug APK를 생성하고 설치했다. 측정 패키지는 `com.example.jellymon`이며 기존 `com.jellymon.game`의 저장 데이터는 수정하거나 삭제하지 않았다. 앱 강제 종료 후 재실행 2회, OS 재부팅/캐시 삭제는 하지 않았다.

| 단계 (Godot ticks 기준) | 1회 | 2회 |
|---|---:|---:|
| Main._ready 도달 | 2821ms | 2904ms |
| 플랫폼 초기화 호출 반환 | 2828ms | 2910ms |
| 저장 로드 완료 | 2831ms | 2913ms |
| 홈 구성 완료 | 3067ms | 3158ms |
| 첫 frame_post_draw | 3221ms | 3309ms |

Main 진입 이전 구간이 전체 측정 시간의 약 88%다. 이 구간에는 엔진/그래픽 초기화, 오토로드 및 스크립트/초기 리소스 준비가 포함될 수 있으며 세부 원인별 시간은 추가 계측이 필요하다. 첫 frame_post_draw는 렌더링 완료 지표이며 실제 화면의 검은색 지속 시간을 동영상으로 측정한 값은 아니다. Android am start의 Activity 표시 시간은 게임 프레임 시간과 다르다.

현재 preset은 Gradle build=false이고 Hive 플러그인은 이 테스트 APK에 포함되지 않았다. 따라서 이 실행의 지연은 Hive 서버 응답 대기가 아니다. Hive 포함 빌드의 시작 성능이나 로그인 성공을 검증한 결과는 아니다.

최신 홈 화면이 정상 표시되는 것을 기기 캡처로 확인했다. 테스트 계정은 처음 진행 상태이므로 진주색 주민이 있는 기존 계정의 시작 성능을 그대로 대표하지 않는다.

다음 개선 우선순위: 엔진 시작 스플래시 표시, 가벼운 부트 장면과 게임 코드 지연 로딩, 초기 리소스/오토로드 세부 계측. 진주색 이미지 사전 생성은 보조 개선이며 이번 실기기 로그로 주요 원인이라고 확정할 수 없다.

소스에는 debug 빌드에서만 출력되는 `[startup]` 단계 로그를 추가했다. 최적화나 Hive 설정 변경은 하지 않았다.

- APK: `output/startup-device/JellyMon-startup-debug.apk`
- 측정 로그: `output/startup-device/diagnostic-logcat.txt`
- 화면: `output/startup-device/diagnostic.png`
