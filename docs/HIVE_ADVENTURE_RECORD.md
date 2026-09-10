# Hive 최고 모험 기록 저장

## 저장 내용

Hive Game Data Store의 로그인된 Player ID별 `jellymon_adventure_v1` 키에 평면 JSON 문자열을 저장한다.

| 필드 | 의미 |
| --- | --- |
| `schema_version` | 현재 1 |
| `highest_cleared_level` | 별을 1개 이상 획득해 클리어한 최고 모험 레벨. 화면과 같은 1부터 시작하는 번호 |
| `best_clear_ms` | 해당 최고 레벨의 최단 실제 플레이 시간, 밀리초. 기록이 없으면 0 |
| `best_cleared_at_unix` | 그 최단 기록을 달성한 시각, UTC Unix 초. 과거 시각을 모르면 0 |

예: 레벨 86을 39.21초에 클리어하면 레벨 86, 39210ms, 해당 클리어 시각을 함께 저장한다. 레벨 87을 클리어하면 레벨 87의 기록으로 교체한다. 레벨 86을 재도전해 더 빠르게 끝내도 최고 레벨 87의 기록을 바꾸지 않는다. 같은 최고 레벨의 느린 재도전도 최고 기록을 변경하지 않는다.

소요 시간은 기존 `Game.elapsed_play_time` 기준이며 플레이 상태에서 튜토리얼 타이머가 멈추지 않은 동안 누적된다. 로딩·결과 화면 시간은 포함하지 않는다. 달성 시각은 기기 시계를 사용하며 서버가 검증한 시각이 아니다. 일일/주간 활동 기록은 이번 모험 기록에 포함하지 않는다.

## 동작

- 기존 로컬 최고 레벨과 최단 기록을 그대로 사용한다. 과거 클리어 시각은 만들어 넣지 않는다.
- 정상 로그인 후와 모험 클리어 후에 서버 기록을 조회한다.
- 서버 조회에 성공한 경우만 로컬과 비교한다. 높은 레벨, 같은 레벨이면 더 짧은 소요 시간을 우선한다.
- 변경할 기록을 업로드한 뒤 다시 조회해서 실제 값이 반영됐는지 확인한다. 콜백만으로 저장 완료를 표시하지 않는다.
- 전송 실패는 30초부터 최대 5분 간격으로 재시도한다. 재실행 시에도 로컬 기록으로 다시 동기화한다.
- 로컬 저장의 `hive_record_owner`에 첫 동기화 계정을 연결한다. 다른 계정으로 바뀌면 이전 계정의 로컬 기록을 자동 전송하지 않는다.
- 메뉴의 로그인 상태 아래에 기록 확인 중/저장 중/저장 확인/재시도 대기 상태를 표시한다.

이번 기능은 최고 모험 기록의 저장이다. 재화, 가구, 전체 레벨별 별 등을 새 기기에 복구하는 기능은 포함하지 않는다. 서버 기록을 조회해 비교하지만 게임의 로컬 맵 진행도는 자동 변경하지 않는다.

DataStore의 단순 읽기/쓰기 API를 사용하므로 두 기기에서 정확히 동시에 저장하는 경우의 원자적 최고 기록 갱신은 보장하지 않는다. 경쟁 랭킹이나 조작 방지용 기록으로 사용하려면 서버의 검증과 원자적 갱신이 추가로 필요하다.

## Hive 콘솔 준비

1. **Game Data Store → 데이터 관리**에서 이 게임의 저장소를 생성한다.
2. 발급된 데이터 스토어용 공개키를 **앱센터 → 게임 → Hive 제품 설정**에 등록하고 데이터 스토어를 사용으로 설정한다.
3. 앱을 완전히 다시 실행해 Hive 초기화 설정을 갱신한다.
4. 클리어 후 메뉴에서 `Hive 저장 확인`을 확인한다.
5. 콘솔에서 해당 Player ID의 `jellymon_adventure_v1` 키를 검색해 세 항목을 확인한다.

로그인용 client ID/secret과 별개 설정이며 client secret을 APK에 추가하지 않는다.

공식 안내: [Android 모듈 설정](https://developers.hiveplatform.ai/en/latest/dev/datastore/hive-sdk-prep/android/), [데이터 저장 API](https://developers.hiveplatform.ai/ko/latest/dev/datastore/), [콘솔 설정](https://developers.hiveplatform.ai/en/latest/operation/game-data-store/).

## 검증

- Hive DataStore 26.4.0 포함 네이티브 debug/release 브리지 빌드 성공.
- `tools/verify_hive_progress.tscn`: 기존 기록 이전, 잘못된 소요 시간 거부, 최고 레벨/최단 기록 선택, 파일 재로드, 조회 실패 시 덮어쓰기 방지, 재조회 확인, 계정 변경과 오래된 콜백 차단 검사 통과.
- 테스트 실행: `Godot --headless --path . tools/verify_hive_progress.tscn`
- Galaxy Note10에 데이터 보존 업데이트 설치 후 자동 로그인과 실제 DataStore API 호출 확인.
- 서버가 `DataStoreDisabled`를 반환해 **실제 서버 업로드·재조회 성공은 아직 확인하지 못했다.** 콘솔에서 데이터 스토어 활성화가 필요하다. 실패 후 자동 재시도는 실기기에서 확인했다.
- APK: `output/hive-progress/JellyMon-hive-progress-debug.apk`.
- 최종 APK는 Godot 전체 내보내기 후 JNI 함수 조회 수정(`has_java_method`)을 반영해 Gradle로 증분 빌드했다. 해당 디버그 스크립트만 소스 형식으로 갱신했고, 이후 일반 Godot 내보내기에도 수정된 원본이 적용된다.
