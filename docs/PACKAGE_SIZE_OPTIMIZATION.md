# 패키지 용량 정리 · 2026-09-11

## 적용 내용

- `tmp/`, `docs/`, `native/`, `output/`에 `.gdignore` 추가. `server/`, `build/`의 기존 `.gdignore` 유지.
- 모든 export preset에서 위 6개 폴더와 `tools/`, `_to_delete/`, `assets_backup/`, 지정된 루트 임시 압축파일을 제외.
- Android는 `arm64-v8a`만 포함. x86_64 에뮬레이터 지원이 필요하면 별도 개발 preset을 사용한다.
- `sync_now.tgz`, `zi1LjBtV`, `ziqDdOWi` 삭제: 작업 트리 약 79.2MB 정리. Git 이력의 파일까지 삭제한 것은 아니다.
- 생성 폴더의 `.gdignore`는 Git에 보존하고 다른 생성물은 계속 무시한다.
- `Android`는 테스트 APK용으로 유지하고, `Android Google Play` AAB preset을 추가했다.
- Hive Android AAR 및 iOS XCFramework는 각각 `addons/`, `ios/plugins/`에 유지한다. 네이티브 소스 제외가 SDK 연동 제거를 의미하지 않는다.

## 측정 결과

MiB는 1,048,576바이트다. 아래는 로컬 파일 크기이며 스토어가 기기에 전송하는 다운로드 크기와 다르다.

| 파일 | 바이트 | MiB |
|---|---:|---:|
| 기존 `output/JellyMon.apk` | 391,559,137 | 373.42 |
| 새 `output/JellyMon-arm64.apk` (Debug) | 129,031,291 | 123.05 |
| 새 `output/JellyMon-arm64-debug.aab` (Debug) | 74,614,316 | 71.16 |

APK는 약 **67.05% 감소**했다. 기존 APK에서 `assets/tmp`의 압축 크기 약 116.9MB, x86_64 라이브러리 약 83.2MB를 확인했다. 개발용 이미지의 import 산출물도 빠지면서 `assets/.godot`은 약 93.7MB에서 32.3MB로 감소했다. `.godot` 안에는 실제 게임에 필요한 변환 리소스가 있으므로 통째로 제외하지 않는다.

루트 임시 압축파일 제거량을 APK 감소량에 그대로 더하면 안 된다. 파일별 APK 포함 여부와 압축 크기는 별개이며 실제 빌드 결과로 비교한다.

현재 Debug APK의 ARM64 네이티브 라이브러리는 약 78.3MB이며 압축하지 않는 기존 설정을 유지했다. **APK 60~90MB 달성을 확인한 것은 아니다.** AAB 파일은 71.16MiB이지만 설치 가능한 APK와 같은 지표가 아니다. Release 서명 후 빌드 및 Play Console의 기기별 다운로드 크기를 별도로 측정한다.

## 검증

- APK·AAB 빌드 모두 종료 코드 0.
- 두 산출물에서 제외 폴더의 직접 리소스와 x86 계열 라이브러리 없음 확인. AAB ABI는 arm64-v8a만 존재.
- APK의 게임 데이터 JSON 35개 유지 확인.
- APK에서 실제 패키징된 게임 리소스를 `/tmp`에 추출해 헤드리스 런타임을 실행했다. 홈 생성·종료 검증이 종료 코드 0으로 완료되었다. 샌드박스의 macOS 인증서 접근 오류는 별도 기록되었다.
- Android 실기기 설치·Hive 로그인/결제 재검증은 이번 용량 작업에서 수행하지 않았다.

## 빌드

```sh
# GODOT은 로컬 Godot 실행 파일 경로로 지정한다.
GODOT=/Users/kimsk/Documents/dev/tool/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . --export-debug Android output/JellyMon-arm64.apk
"$GODOT" --headless --path . --export-debug 'Android Google Play' output/JellyMon-arm64-debug.aab

# Android Google Play preset에 실제 Release keystore를 설정한 후 실행한다.
"$GODOT" --headless --path . --export-release 'Android Google Play' output/JellyMon.aab
```

검증한 AAB는 **Debug 빌드이므로 스토어 제출용이 아니다**. Release 키는 아직 설정되지 않았다. 새 AAB preset에도 실제 업로드 키를 설정해야 한다. 키·비밀번호를 저장소에 커밋하지 않는다. APK와 AAB preset의 상품·패키지·버전 등 공통 설정을 변경할 때는 둘을 함께 갱신한다.

## 스토어 크기 해석

- Google Play의 신규 앱은 AAB로 게시하며, Play가 기기별 APK를 생성한다. AAB 파일 크기를 사용자 다운로드 크기로 안내하지 않는다. [Android App Bundle 공식 안내](https://developer.android.com/guide/app-bundle)
- Apple은 App Store Connect에서 기기별 **압축 다운로드 크기**가 200MB를 초과하면 경고를 표시한다고 안내한다. Android APK 크기나 로컬 Xcode 프로젝트 크기로 iOS 다운로드 가능 여부를 판정하지 않는다. 이번에는 IPA/Archive 크기를 측정하지 않았다. [Apple 빌드 크기 확인 안내](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata/)
- iPhone의 App Store 셀룰러 사용에는 사용자 설정도 관여한다. [Apple App Store 설정 안내](https://support.apple.com/en-mide/guide/iphone/-iph3dfd91de/ios)
