# JellyMon 랭킹 서버 (Hive 163)

별 3개로 클리어한 최고 레벨을 등록하고 상위 100명을 조회하는 작은 Node.js + TypeScript 서버입니다. 같은 레벨이면 최초 달성 시각이 빠른 사람이 위에 표시됩니다. 게임의 기존 RankingService와 바로 연결됩니다.

## Docker로 실행

`server/leaderboard` 폴더 전체를 서버에 복사합니다. Docker Engine과 Compose가 필요합니다.

```sh
cd server/leaderboard
cp .env.example .env
chmod 600 .env
```

`.env`를 편집합니다.

- `HIVE_APP_ID`: Hive에 등록된 실제 App ID. 예시의 `com.jellymon.game`이 콘솔 값과 같은지 확인합니다.
- `HIVE_ALLOWED_APP_IDS`: 같은 게임의 허용 App ID 목록(쉼표 구분). Android/iOS를 함께 서비스할 때 `com.jellymon.game,com.jellymontest.game`으로 설정합니다. 새 앱은 `app_id`를 전송하며 서버는 허용 목록을 검사한 뒤 해당 ID로 Hive 토큰을 검증합니다. `app_id`가 없는 구버전 앱은 `HIVE_APP_ID`로 검증합니다. iOS 지원을 적용하려면 서버 코드와 `.env`를 함께 갱신하고 `npm run build` 후 서버를 재시작해야 합니다. 리더보드는 두 플랫폼 모두 163번을 사용합니다.
- `HIVE_LEADERBOARD_ID=163`
- `HIVE_CERTIFICATION_KEY`: Hive 서버용 Certification Key. Client Secret, 로그인 토큰, DataStore 공개키와는 다릅니다. 키는 서버에만 보관합니다.
- `HIVE_ZONE=sandbox`: 현재 테스트 앱과 같은 환경. 운영 앱이면 `live`로 변경합니다.
- `RANKING_DOMAIN`: 공개 도메인 이름. 예: `ranking.my-game.com` (https:// 제외).

163번 보드는 내림차순(높은 점수 우선), 누적(초기화 없음)으로 설정합니다. 이 서버 전용으로 사용해야 합니다.

### 도메인으로 HTTPS까지 실행

도메인의 DNS A/AAAA 레코드를 서버에 연결하고 외부에서 TCP 80/443 포트로 접근 가능하게 한 뒤 실행합니다. 기존 웹서버가 해당 포트를 사용 중이면 아래의 기존 프록시 방식을 사용합니다.

```sh
docker compose --profile https up -d --build
docker compose ps
curl --fail https://ranking.my-game.com/healthz
curl --fail https://ranking.my-game.com/v1/ranking/top
```

`healthz`는 `{"status":"ok"}`를 반환합니다. 랭킹 조회는 빈 보드라면 `{"entries":[],"limit":100}`을 반환합니다. 후자의 성공까지 확인해야 Hive 연결이 확인된 것입니다. `/healthz`는 서버와 DB 확인용이며 Hive 키 검증을 하지 않습니다.

앱에 연결할 주소는 `https://ranking.my-game.com`입니다. `/v1/ranking/top` 경로는 제외하고 알려 주세요.

### 기존 HTTPS 프록시/호스팅 사용

```sh
docker compose up -d --build ranking
curl --fail http://127.0.0.1:8787/healthz
```

기존 Nginx 등의 HTTPS 프록시에서 `127.0.0.1:8787`로 전달합니다. 외부에는 HTTPS 주소를 제공합니다. Dockerfile 기반 호스팅에서는 내부 포트 8787과 영구 볼륨 `/data`를 지정합니다. Compose의 `RANKING_DB_PATH`는 `/data/ranking.sqlite3`으로 고정되어 있습니다.

## npm으로 실행

Node.js 22.13 이상(배포 이미지는 Node 24)과 영구 디스크가 필요합니다. Node 내장 HTTP와 SQLite를 사용하므로 런타임 npm 의존성은 없습니다. 일부 Node 버전에서는 SQLite experimental 경고가 표시될 수 있습니다.

```sh
cd server/leaderboard
cp .env.example .env
chmod 600 .env
# .env의 HIVE_APP_ID, HIVE_CERTIFICATION_KEY 등을 편집
npm ci
npm test
npm start
```

`npm test`가 TypeScript 빌드와 테스트를 수행합니다. 빌드만 하려면 `npm run build`를 실행합니다. `npm start`는 `.env`를 자동으로 읽습니다. 기존 환경변수가 있으면 환경변수 값이 우선합니다.

기본 주소는 `127.0.0.1:8787`, DB는 `./data/ranking.sqlite3`입니다. 컨테이너형 호스팅에서는 `HOST=0.0.0.0`, `PORT=8787`을 지정합니다. `RANKING_DB_PATH`의 부모 폴더는 자동 생성되며 실행 사용자에게 쓰기 권한이 있어야 합니다. HTTPS는 호스팅 또는 프록시에서 처리합니다.

```sh
curl --fail http://127.0.0.1:8787/healthz
curl --fail http://127.0.0.1:8787/v1/ranking/top
```

운영에서는 프로세스 관리자 또는 Docker의 재시작 정책을 사용합니다. SIGTERM/SIGINT를 받으면 진행 중 요청과 Hive 전송을 정리한 뒤 종료합니다.

## API와 저장

| API | 용도 |
| --- | --- |
| `GET /healthz` | 서버·DB 상태 |
| `GET /v1/ranking/top` | Hive 상위 100명, 10초 캐시 |
| `POST /v1/ranking/record` | Hive 로그인 검증 후 3성 최고 기록 등록 |

POST 본문: `player_id`, `did`, `level`, `stars`(3), `achieved_at_ms`(Unix 밀리초), `nickname`. 헤더: `X-Hive-Player-Token`, `X-Hive-Access-Token`. 게임이 자동으로 전달합니다. 인증되지 않은 기록은 거부합니다.

Hive 전송 실패 시 SQLite에 저장하고 30초 간격으로 재시도합니다. HTTP 202와 `pending: true`는 기기에서 서버로 접수되었지만 Hive 전송이 대기 중이라는 뜻입니다. 서버 한 개와 영구 SQLite 볼륨으로 운영합니다. 여러 인스턴스로 복제하지 마세요.

현재 클리어 여부와 달성 시각은 클라이언트 보고 값입니다. 로그인 검증은 있지만 플레이 재검증을 통한 부정행위 방지는 포함되어 있지 않습니다.

## 재시작·업데이트·백업

```sh
docker compose logs --tail=100 ranking
docker compose --profile https up -d --build
```

일반 재시작/재배포에서는 `ranking_data` 볼륨이 유지됩니다. `docker compose down -v`는 DB와 인증서를 삭제하므로 사용하지 마세요. DB를 잃으면 기존 최고 기록 비교 및 전송 대기도 잃습니다. 백업은 SQLite 온라인 백업 기능 또는 서비스를 중지한 상태의 볼륨 스냅샷으로 진행합니다.

## 테스트

```sh
npm test
```

테스트는 가짜 Hive와 임시 DB만 사용합니다. 실제 163번 보드에 테스트 기록을 쓰지 않습니다. 실서비스 확인은 배포 후 조회 API와 실제 테스트폰 클리어로 진행합니다.

실행 설정 참고: [Node SQLite 문서](https://nodejs.org/api/sqlite.html), [Caddy reverse_proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy).

## 소스 구조

- `src/index.ts`: 환경설정, 실행, 종료 처리
- `src/server.ts`: HTTP API, 조회 캐시, 재시도
- `src/hive.ts`: Hive 인증·163번 점수 등록·조회
- `src/ranking.ts`: 순위 계산, SQLite 영구 기록과 전송 대기
- `test/ranking.test.ts`: 임시 DB/가짜 Hive 및 실제 로컬 HTTP 테스트

`legacy-python/`은 이전 구현의 참고용 보관본입니다. 실행과 Docker 빌드에는 포함되지 않습니다. 기존 Python 서버의 records 테이블과 호환되지만 같은 DB에 두 서버를 동시에 실행하지 마세요.
# Google Play 결제 API

기존 서버에 `/v1/billing/order`, `/verify`, `/ack`, `/entitlements`를 추가했습니다. 실제 경로는 모두 `/v1/billing/` 접두사를 사용하며 Hive 인증이 필요합니다. 기본값은 결제 비활성화입니다.

`config/iap-products.json`을 서버에 함께 배포하고 `.env.example`의 `HIVE_IAP_*` 설정을 적용한 뒤 재시작하세요. `GET /healthz`의 `billing:true`로 활성화를 확인합니다. 상세 콘솔 등록값과 테스트 순서는 [Google Play · Hive IAP 가이드](../../docs/GOOGLE_PLAY_HIVE_IAP_SETUP.md)를 참고하세요.

SQLite 구매 기록을 보존해야 중복 지급을 방지할 수 있습니다. 완료된 패키지 재화를 재설치마다 재지급하지 않으며 영구 권한·가구만 복원합니다. 환불 이후 자동 회수는 별도 구현 대상입니다.

### iOS App Store 결제

iOS 주문은 `platform: "ios"`와 iOS Hive App ID를 전송합니다. 서버에
`HIVE_IAP_IOS_APP_ID`, `HIVE_IAP_IOS_BUNDLE_ID`를 설정하고 해당 Hive App ID를
`HIVE_ALLOWED_APP_IDS`에 포함해야 합니다. 기존 Android 요청은 호환됩니다.
스토어별 주문을 분리하기 위해 기존 결제 테이블에 `market` 컬럼을 자동 추가하며
기존 거래는 Google(2)로 유지합니다. 배포 전 DB를 백업하세요.

Docker Compose의 빌드 컨텍스트는 이제 저장소 루트입니다. 저장소 전체를 체크아웃하고
이 디렉터리에서 기존 `docker compose` 명령을 실행합니다. 빌드/런타임 이미지에
상품 카탈로그를 포함하고, Compose에서 IAP 환경변수도 전달합니다.

[Apple/Hive 등록·구매·복원·출시 가이드](../../docs/IOS_HIVE_IAP_SETUP.md)를 참고하세요.
