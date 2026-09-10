# 별 3개 모험 랭킹

## 플레이 규칙

- 유저별 **별 3개로 클리어한 최고 모험 레벨**을 대표 기록으로 사용한다.
- 높은 레벨이 우선, 같은 레벨이면 **그 레벨의 최초 별 3개 달성 시각**이 빠른 순이다. 소요 시간 순서가 아니다.
- 한 유저가 100레벨을 별 2개, 95레벨을 별 3개로 클리어했다면 95레벨로 참가한다.
- 재도전으로 같은 레벨을 다시 별 3개 달성해도 최초 시각은 유지한다.
- 신규 최고 별 3개 레벨을 달성하면 그 레벨과 달성 시각으로 갱신한다.
- 일일/주간 이벤트 기록은 모험 랭킹에 넣지 않는다.
- 유저당 한 줄, 최대 100명. 100명 미만이면 실제 인원만 표시한다.
- 밀리초까지 같은 레벨/시각이면 Player ID 문자열 순으로 표시한다. 그 경우 클리어 시각상 우열은 없다.

기존 저장에는 별 3개 **최초** 달성 시각이 없으며, 이전에 추가한 최단 시간 달성 시각으로 대체하면 선착순이 왜곡된다. 따라서 과거 기록을 임의 날짜로 등록하지 않는다. 해당 레벨을 다시 별 3개로 클리어하면 그 재도전의 달성 시각부터 등록할 수 있다.

## 화면

홈 → 메뉴 → **★★★ 모험 랭킹 · TOP 100**.

순위 / 닉네임 / 별 3개 최고 레벨 / 최초 달성 날짜와 시각을 표시한다. 시각은 한국시간(UTC+9), 밀리초 포함. 현재 로그인한 유저는 `나` 표시와 강조 배경을 사용한다. 새로고침, 빈 랭킹, 서버 준비 중, 통신 실패, 이전 결과 표시 상태를 지원한다. 메인 화면과 같은 A/B/D 테마를 사용한다.

`output/hive-ranking/preview-*.png`는 UI 검사에만 사용하는 **가상 유저 미리보기**이며 실제 Hive 랭킹이 아니다. 일반 게임에는 가상 유저를 생성하지 않는다.

## 구성

1. `SaveGame.three_star_first_at_ms`: 레벨별 최초 3성 달성 시각을 기기에 보관.
2. `RankingService`: 로그인·3성 기록 변경·랭킹 페이지 열기 때 전송. 실패하면 60초 후 재시도. 재실행 시 로컬 기록에서 재시도. 계정 소유자가 다르면 전송하지 않음.
3. `HiveBridge.prepareRankingAuth`: Hive access token 갱신 후 현재 Player ID/DID/player token/access token을 메모리로 전달. 토큰을 파일이나 로그에 저장하지 않음.
4. `server/leaderboard/src/index.ts`: Hive v2 토큰 검증 후 3성 기록을 수신. SQLite에 최고 기록과 전송 대기를 원자적으로 보관하고 Hive 리더보드에 기록.
5. 상위 100명은 Hive의 `/ranks?page=1&rowcount=100`에서 읽어 게임에 제공. 서버 캐시 10초. 신규 기록 등록 후 캐시 무효화.

리더보드 ID는 **163**, 클라이언트 서버 주소는 `https://engrailed-sadye-curatively.ngrok-free.dev`로 지정했다. 공개 서버의 `/healthz`는 200이지만 `/v1/ranking/top`은 502여서 실제 Hive 점수 등록/조회는 아직 검증하지 못했다. 인증/보드/데이터 오류를 구분하는 서버 변경 후 재배포하여 확인해야 한다. 이전 모험 기록 DataStore와 이번 공식 Leaderboard는 별도 서비스다.

## Hive 콘솔 및 배포 설정

1. Hive 콘솔 → **리더보드 → 랭킹 관리**에서 생성된 **163번** 보드를 사용한다. 164번은 사용하지 않는다.
2. 이름 예: `jellymon_three_star_adventure_v1`. **내림차순**, **누적(초기화 없음)**으로 설정하고 운영 기간을 지정한다.
3. 서버 환경변수 `HIVE_LEADERBOARD_ID=163`을 설정한다. 환경변수가 없으면 서버는 기본값 `163`을 사용한다. 기존 배포 환경에 다른 값이 있으면 163으로 변경해야 한다. 클라이언트의 `leaderboard_id`는 식별용이며 실제 요청 대상은 서버 설정이 결정한다.
4. 앱센터 → 프로젝트 관리 → 게임 상세 → 기본 정보의 **Certification Key(인증키)**를 서버의 `HIVE_CERTIFICATION_KEY`에 설정한다. Client Secret이나 DataStore 공개키와 다르다.
5. `HIVE_APP_ID`를 실제 Hive App ID, `HIVE_ZONE`을 앱과 같은 `sandbox`/`live`로 설정한다.
6. 영구 쓰기 가능한 SQLite 파일 경로를 `RANKING_DB_PATH`에 지정한다. DB를 유지해야 기존 최고 기록과 전송 대기가 보존된다. 운영 시 해당 파일을 백업한다.
7. Node.js + TypeScript 서버를 HTTPS 뒤에 배포한다. 실행 방법은 [서버 README](../server/leaderboard/README.md)를 따른다. 여러 서버를 운영하려면 공용 트랜잭션 DB로 이전한다.
8. `assets/data/platform_services.json`의 `ranking.api_base_url`에 배포된 HTTPS 주소를 설정하고 게임을 빌드한다. 경로 뒤에 `/v1/ranking/...`이 자동으로 붙는다.

`.env.example`을 `.env`로 복사해 설정한다. `npm start`와 Docker Compose는 `.env`를 읽는다. 앱에는 서버 주소만 들어가며, 서버 인증키를 넣지 않는다. 로컬 실행은 `server/leaderboard`에서 `npm ci && npm run build && npm start`이며 127.0.0.1:8787에서만 대기한다. 게임 클라이언트는 HTTPS만 허용한다.

### 순위 인코딩

Hive 점수는 15자리 정수 제한이 있으므로 `level * 500000000000 + 499999999999 - (achieved_at_ms - 1767225600000)`으로 기록한다. 레벨이 먼저 정렬되고 같은 레벨에서는 이른 밀리초가 높은 점수가 된다. 실제 레벨·닉네임·별3개·달성 시각은 `extraData`에 함께 저장한다. Hive의 동점 처리 방식에 선착순 정렬을 맡기지 않는다.

현재 레벨 1~1000을 지원하며 날짜 범위는 2026-01-01 UTC부터 500000000000ms 미만이다. 지원 레벨이나 기간을 확장할 때 점수 인코딩과 리더보드 버전을 함께 검토한다. 이 점수 체계와 무관한 기록을 같은 리더보드에 넣지 않는다.

### 달성 시각과 검증 범위

달성 시각과 별 개수는 게임 클라이언트에서 보고한 값이다. 오프라인 달성 후 전송해도 원래 기록을 사용한다. 서버는 계정의 Hive 토큰, 별3개 여부, 숫자 범위와 미래 시각 오차(60초)를 검증하지만, 게임 플레이를 재연산해 3성 달성을 증명하지는 않는다. 기기 시각이나 변조 클라이언트를 통한 순위 조작을 막아야 하는 경쟁 운영에는 서버의 플레이 결과 검증/리플레이 검증이 추가로 필요하다. 현재 구현을 조작 방지까지 보장하는 랭킹으로 간주하지 않는다.

## 검사

- `python3 -m unittest discover -s server/leaderboard -v`: 8개 검사 통과. 3성 자격, 계정 인증 실패, 레벨/밀리초 정렬, 중복 방지, 상위100명, 영구 전송 대기, 동시 요청, Hive API 계약.
- `Godot --headless --path . tools/verify_ranking.tscn`: 기존 기록 처리, 최초 시각 고정, 파일 저장/로드, 100명 정렬, 잘못된 3성 데이터 거부, 서버 미설정 상태, A/B/D 화면 검사.
- Hive Android 브리지 debug/release 빌드 통과.
- 기존 Hive 모험 기록 저장 회귀 검사 통과. 홈 메뉴 진입 버튼과 100위 마지막 행까지 시각 검수 완료.
- 이번 작업에서는 APK를 다시 내보내거나 테스트폰에 설치하지 않았다. 실제 서버 설정 후 APK 빌드 및 실기기 연동 확인이 필요하다.

공식 자료: [Hive 리더보드 API](https://developers.hiveplatform.ai/en/latest/api/leaderboard-api/), [리더보드 콘솔](https://developers.hiveplatform.ai/en/latest/operation/leaderboard/), [Hive v2 로그인 토큰 검증](https://developers.hiveplatform.ai/en/latest-version/api/hive-server-api/auth/v2/authv4-verifytoken/).

## Node.js + TypeScript 전환

현재 배포 대상은 `server/leaderboard/src`이다. 이전 Python 테스트 결과는 과거 검증 이력이며, 현재 검증 명령은 `cd server/leaderboard && npm test`이다. 기본 리더보드는 163이고 API 계약은 유지한다. 상세 설치/HTTPS/영구 DB 안내는 서버 README를 참고한다.
