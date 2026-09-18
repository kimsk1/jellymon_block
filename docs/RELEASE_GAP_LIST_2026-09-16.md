# 젤리몬 출시 가능 여부 점검 · 2026-09-16

기준: `game/` 저장소 HEAD `1260e44 adjust hive shop item` (2026-09-16 10:01), `docs/` 검증 기록, 설정 파일. 이번 점검은 코드·설정·문서를 대조한 결과이며, 실기기 실행이나 콘솔 상태를 새로 확인한 것은 아니다.

## 결론

**아직 출시 가능한 상태가 아니다.** 로그인·랭킹·클라우드 저장·상점 판매의 *코드 경로*는 갖춰졌지만, 저장소에 남아 있는 마지막 실기기 기록은 아래 상태에서 멈춰 있다.

| 기능 | 코드 | 실기기 검증 기록 (저장소 기준) |
|---|---|---|
| Hive 로그인 | 있음 | Android 성공, iOS 성공 |
| 랭킹 | 있음 (Leaderboard 163 + 자체 서버) | `/v1/ranking/top` **502**, 실제 등록·조회 미검증 |
| 클라우드 저장 | 있음 | Android 성공, iOS **HTTP 500** (Hive 지원팀 회신 대기) |
| 상점 판매 | 있음 (8 SKU, 서버 검증·ACK·복원) | Android 상점 초기화 **-6100011 Invalid market pid list**, iOS Sandbox 거래 **0건** |

9/11 점검 이후 커밋 3개(9/10~9/16)는 iOS 브리지 debug/release 분리, HiveIAPV4 Pod 추가, 상점 카드 스크롤 수정 등 빌드·UI 정리이고, 위 4개 실기기 문제가 해결됐다는 기록은 없다. 만약 실기기에서 이미 해결했는데 문서에만 반영이 안 된 것이라면 그 결과를 알려주면 이 목록에서 제외한다.

아래는 "있는 것"이 아니라 "없는 것"만 적었다. 번호는 우선순위 순서다.

---

## A. 출시 차단 (이것 없이는 심사 반려 또는 매출 0)

### A-1. 결제가 실기기에서 한 번도 성공하지 않았다
1. **Android** — Hive 상점 초기화 `-6100011 Invalid market pid list`. Play Console 단건 상품 8개 등록·활성화 → Hive 콘솔 Android App ID에 marketPid 매핑 → 라이선스 테스터 계정으로 구매·취소·복원·앱 강제 종료 후 복원까지 통과해야 한다.
2. **iOS** — App Store Connect 상품 등록, 유료 앱 계약·세금·은행, Hive iOS 상품 매핑, Sandbox 구매·복원. 현재 0단계. `HiveIAPV4` Pod은 9/16에 추가됐으므로 `CommonLibraryMissing(-12)`는 해결된 것으로 보이나 실구매 기록은 없다.
3. **환불 회수 없음** — `billing.ts`는 지급 전 환불 상태만 거절하고, 지급 후 환불(RTDN / App Store Server Notifications)을 받아 VIP·팩을 회수하는 흐름이 없다. 최소한 수동 회수 절차라도 문서화.
4. **재설치 복원 막힘** — `billing.ts:120` ACK 전 다른 `install_id` 복원을 409로 차단. 구매 직후 앱 삭제·기기 분실 시 자동 복원이 안 된다. 계정 기준 복구 경로 또는 운영자 처리 도구 필요.

### A-2. 운영 환경이 전부 테스트 설정이다
5. `platform_services.json`: Android/iOS `zone=sandbox`, `test_ads=true`. Hive 콘솔 라이브 전환 + 앱 JSON 2곳 + `ios/plugins/HiveBridge/hive_config.xml` + 서버 `HIVE_ZONE` 동시 전환.
6. 랭킹/결제 서버 주소가 **ngrok 임시 주소**(`engrailed-sadye-curatively.ngrok-free.dev`). 고정 도메인·HTTPS·상시 실행·헬스체크 알림. 서버가 죽으면 상점이 안 열리는 구조라 가용성이 곧 매출이다.
7. SQLite 단일 파일(`data/ranking.sqlite3`) **백업·복구 절차 없음**. 구매 원장이 여기 있다.
8. AdMob 실제 앱 ID·Rewarded 광고 단위 생성 → Hive Adiz 매핑. 현재 Google 테스트 ID.

### A-3. 식별자·빌드 설정
9. **iOS Bundle ID `com.jellymontest.game`** — 정식 ID로 App ID·프로비저닝·Hive App ID·Google OAuth Client·URL Scheme·서버 `HIVE_IAP_IOS_APP_ID/BUNDLE_ID`를 전부 재발급. 클라우드 저장 500도 `[3674] JellyADtest` 테스트 앱 기준이므로 정식 앱으로 다시 검증해야 한다.
10. **Android `package/unique_name="com.$genname.game"`** — export preset에 실제 패키지명이 없다. `com.jellymon.game`으로 고정. `version/name` 공란, `version/code=1`, iOS `short_version` 공란 → `1.0.0`.
11. **Android 릴리스 서명** — preset에 release keystore 없음. 업로드 키 생성·보관 + Play App Signing.
12. `permissions/internet=false` — Gradle 플러그인이 넣어주더라도 preset에서 명시.
13. `architectures/x86_64=true` — 스토어용 AAB에 불필요, 용량만 늘린다. 9/14 AAB 101MB는 개선됐지만 여전히 x86_64 포함. `gradle_build/min_sdk`·`target_sdk` 공란 — Play 2026 정책 targetSdk 요건 확인.
14. iOS 릴리스 Archive → TestFlight **1회 완주 기록 없음**. debug/release xcframework 분리는 됐으나 실제 Release 빌드·기기 실행 확인 필요.

### A-4. 스토어 심사 필수 자료·정책
15. **개인정보처리방침 URL** — `GOOGLE_PLAY_REGISTRATION.md`에 `[입력 필요]`. Hive가 기기 식별자·계정 정보를 수집하므로 필수.
16. **계정 삭제** — 코드에 계정 삭제(탈퇴) 경로가 전혀 없다 (`탈퇴|deleteAccount|withdraw` grep 0건). 현재 "연결 해제"는 signOut + 로컬 초기화이며 Hive 클라우드·랭킹 서버 기록은 남는다. Apple(로그인 지원 앱)·Google(계정 생성 앱) 모두 앱 내 삭제 개시 경로 + Google은 웹 삭제 요청 URL까지 요구한다. 서버 측 삭제 API(랭킹·구매 원장 중 법정 보관분 제외)와 Hive 탈퇴 API 연동 필요.
17. **데이터 안전 섹션 / Apple 개인정보 라벨** — export preset `collected_data/*` 전부 false인데 실제로는 식별자·구매 기록·분석 이벤트를 수집. 실제와 다르면 반려·삭제 사유.
18. **iOS ATT** — AdMob 사용 시 `NSUserTrackingUsageDescription` + ATT 프롬프트. `tracking_enabled=false` 재검토. (글로벌 출시면 EEA UMP 동의 폼도)
19. 고객지원 이메일·웹사이트, IARC 등급 설문, 심사용 상점 도달 설명·테스트 계정.
20. **스토어 자산** — iOS 1024px 아이콘 슬롯, 세로 스크린샷, Google 피처 그래픽.

### A-5. 콘텐츠·안정성 미해결
21. **L161** — ~~자동 탐색 실패~~ → 레벨 자체가 풀 수 없는 보드였음을 전수 탐색으로 확인하고 데이터 수정 완료(`docs/L161_FIX_2026-09-16.md`). 남은 일: Godot에서 `--autoplay-level=161`·`--validate-endgame` 재실행으로 `cleared=true` 확인.
22. **인게임 공지 불일치** — `live_messages.json` welcome: "100개의 모험", safety: 계정 연결·클라우드 저장을 "지원할 예정". 출시 빌드와 맞지 않는다.
23. **크래시 리포트 없음** — Crashlytics 또는 Hive 제공 크래시 도구. 첫 주 크래시율을 모르면 대응이 안 된다.
24. **원격 분석 비활성** — `analytics_remote.json` `enabled=false`, endpoint 공란. 25개 이벤트 스키마와 큐는 있으니 수신 서버만 연결하면 된다.

---

## B. 출시 전 강력 권장 (심사는 통과하지만 리뷰·매출에 직결)

25. **시즌·프리미엄 시각 기준** — `SaveGame.gd`는 기기 시각, 서버는 `Date.now()`. 시즌 경계에서 유료 혜택 초기화/지급 거절 가능. 서버 시각을 유료 권한 기준으로.
26. **클로즈드 베타 30~100명, 7일** — `CLOSED_BETA_SCORECARD.md` 지표(L1 클리어 85%, L10 도달 55%, D1 35%, D7 12%) 실측 없음. 기기 매트릭스도 Note10 1대 + iPhone 1대뿐.
27. **다국어** — 8개 언어 JSON은 있으나 스크립트 내 한국어 리터럴이 다수. 한국 단독 출시 후 확장을 권장. 8개 언어로 스토어 등록만 하고 UI가 한국어면 저평점 직행.
28. **랭킹 무결성** — 서버가 레벨 범위·시각 형식만 검사하고 플레이 증명은 없음. 랭킹에 보상을 붙이기 전에 이상 탐지·기록 제외 기능.
29. **알려진 설계 불일치** — 프리미엄 시즌 Lv1 별가루 수령 불가, VIP 일일 지원 버튼이 L15 해금 UI 안에 있어 L10 구매자 접근 불가(환불 사유), 주민 이름 새롬/새싹 불일치.
30. **경제 값 하드코딩 중복** — `game_balance.json`과 SaveGame/Game 값 동기화. 원격 밸런싱 전제 조건.
31. 푸시 알림(하트 충전·일일 미션 리셋) 미구현.
32. `git status`가 `.git/index.lock` 때문에 실행되지 않았다. 로컬에서 lock 파일을 정리하고 미커밋 변경이 없는지 확인한 뒤 출시 후보 커밋에 태그.

---

## C. 권장 순서

1. 식별자 확정 (iOS Bundle ID, Android 패키지명, 버전) → 9·10·11
2. 콘솔 등록 (Play 상품 8개 + Hive marketPid, ASC 상품 8개, AdMob 실ID) → 1·2·8
3. 서버 고정 도메인 배포 + 백업 → 6·7, 그 다음 zone live 전환 → 5
4. 실기기 결제 시나리오 12개 (구매·취소·복원·재설치·계정 전환) 양 플랫폼 통과 → 3·4 정책 확정
5. 계정 삭제·개인정보처리방침·데이터 안전 라벨 → 15~19
6. 크래시·분석 연결 → 23·24, L161·공지 정리 → 21·22
7. 서명된 Release 빌드로 내부 테스트 → TestFlight → 클로즈드 베타 → 한국 제한 출시

현재 위치는 "1번 이전"이다. A 항목 24개 중 코드 작업이 필요한 것은 3·4·16·22·25 정도이고, 나머지는 콘솔 등록·설정·문서·실기기 검증이다. 즉 남은 일의 대부분은 개발이 아니라 운영 준비다.
