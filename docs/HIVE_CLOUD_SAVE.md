# Hive 전체 게임 데이터 저장 및 복원

## 2026-09-10 iPhone 오류 진단

### Android 실기기 비교 결과

- 연결된 Galaxy Note10+ (`SM_N971N`)의 설치 앱에서 `initialize zone=SANDBOX`를 확인했다.
- 같은 실행에서 `snapshot load success=true code=Success` → `snapshot save success=true code=Success` → `snapshot load success=true code=Success`가 기록됐다. 단순 로그인 성공이 아니라 저장과 재조회까지 성공했다.
- Android SDK 수신 응답에 `data_store=1`, 비어 있지 않은 `data_store_key`(392자)가 포함됐다. 공개키 원문은 진단 문서에 저장하지 않는다. 비교용 SHA-256: `ec12d5e0798a609d66e2a5b4e1f0c26c4c077b25b0a7f633b3b4b6bc602dc875`.
- Android DataStore 주소는 `https://sandbox-gds-api.qpyou.cn/users/get/userkey` 및 `/users/insert`다. iOS에서 실패한 조회와 같은 호스트/경로다.
- 따라서 저장소의 일반적인 미생성이나 Sandbox 서비스 전체 장애로 볼 근거는 약하다. 다음 비교 대상은 iOS App ID에 대한 초기화 응답의 `data_store`, 공개키 지문, 실제 DataStore 요청 형식이다. Android 성공만으로 iOS의 설정 수신 성공을 단정하지 않는다.
- iPhone을 다시 연결해 18:06 초기화 응답을 확인했다. iOS도 `data_store=true`, 공개키 392자이며 위 Android SHA-256과 완전히 일치했다. DataStore 활성화·공개키의 미전달/불일치는 이번 오류의 원인에서 제외한다. 같은 실행에서도 조회는 `-8000007`로 실패했다.
- 18:10 추가 추적: iOS 단일 키 조회는 `POST https://sandbox-gds-api.qpyou.cn/users/get`으로 전송된다. 요청에는 `app_id=com.jellymontest.game`, `data_key=jellymon_save_v1`, `sdk_version=4.26.4.0`이 들어 있으며, 응답은 HTTP 500 / `{"detail":"Server Internal Error"}`다. 이전 `getMyData` 호출의 `/users/get/userkey`도 실패했다. 따라서 단일 키 조회 API 선택만의 문제로 볼 수 없다.
- 현재 확정 범위는 iOS App ID/SDK 요청에 대한 DataStore 서버 처리 실패다. 잘못된 요청 형식인지 해당 App ID/계정의 서버 처리 문제인지는 서버 내부 로그 또는 동일 요청 조건 비교가 더 필요하다. 공개키를 재발급하거나 정상 Android 설정을 바꾸지 않는다.
- Hive 지원팀 요청 추적 정보: 2026-09-10 18:10 KST, `/users/get`, `x-cloud-trace-context`의 trace ID `a0b2d46fc37537425b4eb41cfb442dcd`. 인증 토큰이나 공개키 원문 없이 해당 요청의 서버 내부 예외를 조회할 때 사용할 수 있다.
- iOS Debug Sandbox 빌드는 초기화 응답에서 활성화 여부와 공개키 SHA-256만 `Documents/hive_datastore_configuration.json`에 기록한다. 초기화가 끝나면 진단 리스너를 해제한다. 임시 SDK 원문 추적과 로그 형식 진단은 제거했다.

- 환경: Hive SDK 26.4.0, App ID `com.jellymontest.game`, Game Index 3674 (JellyADtest), sandbox.
- Hive 초기화와 Google 로그인은 각각 `success=1 code=0`으로 완료됐다.
- 전체 데이터 조회에서 `POST https://sandbox-gds-api.qpyou.cn/users/get/userkey`의 실제 HTTP 응답은 **500**, 본문은 `{"detail":"Server Internal Error"}`였다.
- SDK는 이 오류 본문을 정상 DataStore 응답으로 해석하지 못해 기본 문구 `Not initialized.`를 남겼다. 최종 앱 오류는 `-8000007 / [DataStore] Server response error : Not initialized.`다. 따라서 이 문구만으로 로그인 SDK 미초기화나 공개키 미등록을 단정하지 않는다.
- iOS 조회를 `getMyData`에서 필요한 저장 키의 `get`으로 변경해 확인했으나, 17:08 기기 실행에서도 같은 `-8000007`이 재현됐다. 클라우드 저장/복원은 아직 성공하지 않았다.
- 조회 실패는 빈 데이터로 취급하지 않는다. **명시적인 `DataStoreNotExistKey`(-8000001)만** 새 저장으로 처리한다. 임시 원문 응답 추적은 제거했고, `Documents/hive_datastore_status.json`에는 호출 종류·결과 코드·메시지만 남긴다.
- 다음 확인: Hive Console → 게임 데이터 스토어 → 데이터 관리에서 `[3674] JellyADtest`의 저장소가 생성됐는지, 해당 저장소 공개키가 같은 게임의 Hive 제품 설정에 등록돼 있는지 확인한다. 일치하는데도 재현되면 위 App ID·sandbox·시각·API 경로·HTTP 500 응답을 Hive 지원팀에 전달해 해당 요청의 서버 로그 확인을 요청한다. 이 진단만으로 구체적인 서버 내부 원인이나 전체 서비스 장애를 확정할 수 없다.
- 리더보드 163은 랭킹용이며 DataStore 저장소 ID로 사용하지 않는다.

## 콘솔 활성화

1. Hive Console → **게임 데이터 스토어 → 데이터 관리**에서 JellyMon 게임을 선택하고 **데이터 관리 시작**을 누른다.
2. 생성된 **DataStore 공개키**를 복사한다. 로그인용 Client ID/Client Secret이나 리더보드 Certification Key를 넣는 칸이 아니다.
3. **앱 센터 → 게임 목록 → 해당 게임 → Hive 제품 설정**으로 이동한다.
4. 데이터 스토어를 **사용(Enable)**으로 바꾸고 방금 발급된 공개키를 등록한 뒤 저장한다.
5. 앱을 완전히 종료하고 다시 실행한다. SDK 초기화에서 변경된 설정을 받는다. 계정에 로그인한 뒤 메뉴의 **클라우드 저장 / 복원**을 누른다.
6. 콘솔의 게임 데이터 스토어에서 해당 Player ID로 조회한다. 전체 저장 키는 `jellymon_save_v1`이다. 앱에서 `전체 게임 데이터 · Hive 저장 확인`이 표시되면 쓰기 후 재조회까지 확인한 상태다.

공식 문서: https://developers.hiveplatform.ai/en/latest/operation/game-data-store/
Android 설정: https://developers.hiveplatform.ai/en/latest/dev/datastore/hive-sdk-prep/android/

## 저장 범위

`SaveGame.to_dictionary()`에 정의된 전체 플레이 데이터: 레벨별 별과 클리어 시간/시각, 별 3개 최초 달성 시각, 별가루, 하트와 회복 기준 시각, 부스터, 가구 소유/배치와 테마, 주민/관계/앨범 기록, 출석, 닉네임, 시나리오/튜토리얼, 일일/주간/시즌 진행 및 수령 기록, 구매 상태, 설정 등.

인증 토큰, 기기 분석 로그, 실제 사진 이미지 파일은 저장하지 않는다. 구매 상태의 백업은 스토어 영수증 검증이나 구매 복원을 대체하지 않는다.

## 동작

- 계정에 로그인하고 기존 클라우드 데이터를 먼저 읽는다. 읽기에 실패하면 기존 클라우드를 빈 데이터로 덮어쓰지 않는다.
- 클라우드 키가 없으면 기기의 기존 진행을 처음 업로드한다. 기존 `jellymon_adventure_v1` 요약 키는 지우지 않는다. 새 전체 저장에는 요약에 해당하는 기록도 포함된다.
- 기기 데이터가 바뀌면 저장을 예약하고, 앱이 백그라운드로 이동할 때와 주기적으로도 동기화를 시도한다. 프로세스 강제 종료 직전의 네트워크 저장 완료는 보장하지 않으며 로컬 파일에서 다음 실행 시 재시도한다.
- 쓰기 성공 후 다시 읽어 내용이 같은지 확인한 뒤에만 저장 완료를 표시한다.
- 마지막 동기화 기준과 클라우드가 같으면 기기의 변경 사항을 업로드한다. 클라우드와 기기가 달라 어느 쪽을 사용할지 확정할 수 없으면 선택 팝업을 띄운다. **클라우드 사용 / 기기 데이터 사용 / 나중에**를 선택할 수 있다. '나중에'를 누른 뒤에는 메뉴 버튼으로 다시 선택한다.
- 기기 데이터를 선택해도 클라우드를 다시 읽어 선택 이후의 변경을 확인한다. 재화나 구매 상태를 합산하지 않는다.
- 현재 SDK의 단순 get/set 방식은 두 기기의 완전히 동시인 쓰기를 원자적으로 잠그지 않는다. 동일 계정의 동시 플레이를 엄격히 막으려면 서버의 세션/버전 잠금이 추가로 필요하다.
- 잘못된 형식, 다른 Player ID, 지원하지 않는 스키마, 앱 제한 크기(512 KiB)를 넘는 저장은 적용하지 않는다.
- 연결 해제 성공 시 기기 저장과 동기화 기준만 초기화한다. 클라우드 삭제 API는 호출하지 않는다. 계정 전환 시 이전 요청 응답을 무시한다.
- 복원하려면 **동일한 Hive Player ID**에 다시 로그인해야 한다. 게스트 연결 해제로 삭제된 계정의 데이터를 새 게스트 계정으로 옮기지는 않는다.

## 검증

`tools/verify_cloud_save.tscn`: 모의 Hive 업로드/재조회, 복원, 로컬 파일 재로딩, 재화 감소 저장, 충돌 시 양쪽 선택, 읽기 실패 시 미전송, 이전 계정 응답 차단.
`tools/verify_disconnect_ui.tscn`: 기존 연결 해제 및 기기 초기화 회귀 검증.

콘솔 활성화 전 `DataStoreDisabled`는 구현 오류와 구분해 표시한다. 실제 Hive 저장/복원 성공 여부는 활성화된 환경에서 별도로 확인해야 한다.
