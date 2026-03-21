# EXECUTION_PLAN_v0.3

## 1. 프로젝트 개요

프로젝트명: Party Mini Games

목표:
친구들끼리 방을 만들고 실시간으로 미니게임을 즐길 수 있는 스마트폰 중심 멀티플레이 파티 게임 앱 MVP를 만든다.

현재 우선순위:
1. 로비/대기방 흐름 안정화
2. 369 게임 MVP 완성
3. 게임 진행 상태와 판정 로직 서버화
4. Flutter 게임 화면 분리
5. 멀티플레이 테스트 안정화

핵심 전제:
- 실제 플레이 대상 기기는 스마트폰이다.
- Windows는 개발/테스트용 환경으로 사용한다.
- 따라서 UI/입력/오디오/타이머 설계는 모바일 실사용 기준으로 판단한다.

---

## 2. 현재까지 완료된 상태

완료:
- GitHub 저장소 생성 및 공개 확인 완료
- Flutter 프로젝트 생성 완료
- Node.js + TypeScript + Socket.IO 서버 구성 완료
- Flutter 홈 화면 기본 UI 구성 완료
- Flutter ↔ Node Socket.IO 연결 완료
- 서버 연결 상태 표시 UI 완료
- 닉네임 입력 후 로비 입장 흐름 완료
- 방 만들기 완료
- 방 참가하기 완료
- room:update 기반 대기방 실시간 갱신 완료
- 방 코드 표시 완료
- 참가자 목록 동기화 완료
- 방장/참가자 구분 표시 완료
- 게임 선택 UI 기본 구조 완료
- 게임 시작 버튼 기본 구조 완료
- Game Engine 기본 인터페이스 파일 구조 추가 완료
- 369 / 눈치 / 번데기 엔진 초기 상태 생성 구조 완료
- Flutter widget test 수정 완료
- TypeScript import 및 파일 구조 문제 수정 완료

실행 확인 완료:
- Windows Flutter 앱 실행 성공
- Node 서버 localhost:3000 실행 성공
- Flutter 앱 2개 실행 기준 멀티 접속 테스트 성공
- 방 생성/방 참가/대기방 동기화 테스트 성공
- 수정 후 테스트 에러 해결 성공

---

## 3. 현재 프로젝트 구조

```text
party-mini-games/
├─ README.md
├─ docs/
│  ├─ EXECUTION_PLAN_v0.2.md
│  └─ EXECUTION_PLAN_v0.3.md
├─ app/
│  └─ flutter_app/
│     ├─ lib/
│     │  ├─ main.dart
│     │  └─ services/
│     │     └─ socket_service.dart
│     └─ test/
│        └─ widget_test.dart
└─ server/
   ├─ package.json
   ├─ tsconfig.json
   └─ src/
      ├─ index.ts
      └─ games/
         ├─ createGameEngine.ts
         ├─ types.ts
         └─ engines/
            ├─ ThreeSixNineEngine.ts
            ├─ NunchiGameEngine.ts
            └─ BeondegiGameEngine.ts
```

## Progress Update (2026-03-15)

### Completed
- GitHub repository created and verified
- Flutter project initialized
- Node.js + TypeScript + Socket.IO server initialized
- Flutter ↔ Node Socket.IO connection established
- Lobby system implemented
  - nickname input
  - room create/join
  - room:update real-time player list
  - host/participant role display
- Game selection system implemented
- Game engine interface created
- Initial engines implemented
  - 369
  - Nunchi
  - Beondegi

### 369 Game MVP (Phase 1)

Server
- game:started event
- game:submit event
- turn rotation logic
- number / clap validation
- wrong answer detection
- game over broadcast

Flutter
- automatic transition to 369 game screen
- show current turn player
- number input UI
- clap input button
- real-time game state update
- game over dialog

### UI Stability Fix

Resolved Flutter layout overflow issues
- LobbyScreen converted to scrollable layout
- ThreeSixNineGameScreen converted to scrollable layout
- removed Spacer causing bottom overflow

### Current Status

Playable 369 game MVP implemented.

Flow currently working:

Lobby  
→ Room create/join  
→ Select game  
→ Start game  
→ Game screen transition  
→ Turn based input  
→ Server validation  
→ Next turn or Game Over

---

## 4. 이번 작업 반영 사항 (2026-03-15, 엔진 구조 정리)

### 이번에 완료된 작업
- `index.ts`의 369 판정 로직을 `ThreeSixNineEngine`으로 이동
- `GameEngine` 인터페이스에 `submitTurn()` 추가
- `types.ts`에 공통 제출 타입 추가
  - `GameSubmitPayload`
  - `GameSubmitResult`
  - `GameSubmitInputMode`
- `NunchiGameEngine`, `BeondegiGameEngine`에 인터페이스 호환용 최소 `submitTurn()` 구현 추가
- `index.ts`는 방/턴/엔진 호출/브로드캐스트 중심의 라우팅 역할로 정리
- `game:submit` 이벤트 payload를 확장해 향후 음성 입력을 수용할 수 있는 타입 기반 준비 완료

### 구조상 의미
기존:
- `index.ts`가 369 규칙까지 직접 처리

현재:
- `index.ts`는 라우팅 담당
- 각 게임 엔진이 규칙 담당

즉, 서버 진입점과 게임 규칙 로직의 책임이 분리되었다.

### 현재 서버 구조에서 가능한 것
- 369 게임은 엔진 기반으로 실제 판정 가능
- 눈치/번데기 엔진은 아직 실제 규칙 미구현 상태이지만 공통 인터페이스는 맞춰져 있음
- 향후 버튼 입력과 음성 입력을 같은 `game:submit` 이벤트로 받을 수 있도록 서버 타입이 준비됨

예상 입력 확장 방향:
- `inputMode: "touch" | "voice"`
- `recognizedText`
- `text`
- `value`
- `moveType`

---

## 5. 현재 단계 판단

현재 단계는 다음 목표 중 상당 부분이 완료된 상태다.

완료:
1. `index.ts`에 있던 369 로직을 Game Engine 구조로 이동
2. `ThreeSixNineEngine.ts`에 실제 판정 로직 구현
3. `index.ts`를 게임 라우팅 중심으로 정리
4. `types.ts` 기준으로 game state / submit 타입 정리
5. 다른 게임 확장을 위한 공통 엔진 인터페이스 기반 확보

아직 남은 것:
- Flutter 쪽 `game:submit` 호출 payload를 최신 서버 구조에 맞게 정리
- 음성 입력을 실제 Flutter UI/서비스와 연결
- 눈치게임 실제 규칙 구현
- 번데기게임 실제 규칙 구현
- 공통 게임 화면 구조 추출 여부 검토

---

## 6. 다음 우선 작업

### 1순위
Flutter 클라이언트가 보내는 `game:submit` payload를 최신 서버 구조에 맞게 정리한다.

필요 확인 파일:
- Flutter socket service 파일
- 369 게임 화면 파일

목표:
- 현재 버튼 입력이 최신 payload 구조와 맞는지 확인
- 이후 음성 입력까지 같은 이벤트 구조로 확장 가능하도록 정리

### 완료 (2026-03-16)

Flutter `game:submit` 전송 구조 정리 완료.

주요 변경:

- `socket_service.dart`에 `submitGameInput()` 공통 메서드 추가
- 369 화면에서 숫자 입력 / 박수 입력이 공통 submit 구조를 사용하도록 리팩토링
- 서버 `game:submit` payload 구조와 일치하도록 정리

현재 payload 구조:

```
{
  roomCode: string
  moveType: "number" | "clap"
  value?: number
  text?: string
  inputMode?: "touch" | "voice"
  recognizedText?: string
}
```

이 구조는 다음 입력 방식들을 모두 수용하도록 설계되었다.

- 터치 입력 (현재)
- 음성 입력 (향후)
- 기타 입력 확장

즉, **클라이언트 입력 방식과 서버 이벤트 구조가 분리된 상태**로 정리되었다.

### 2순위
369 화면 입력 구조를 공통화 가능한지 검토한다.

예:
- 버튼 입력
- 박수 입력
- 이후 음성 입력

### 3순위
- 눈치 / 번데기 엔진 실제 규칙 구현
- 공통 게임 화면 구조 추출 여부 검토

---

# 8. Audio 시스템 설계 (2026-03-16 추가)

이 프로젝트는 **입력 음성 + 출력 음성/효과음**을 함께 사용하는 파티 게임 구조를 목표로 한다.

즉,

입력
- 터치 입력
- 음성 입력

출력
- 숫자 음성
- 박수 효과음
- 턴 안내음
- 게임 시작 구호
- 실패 효과음

을 지원하는 구조로 확장한다.

이를 위해 Flutter 클라이언트에 **AudioService 계층을 추가할 예정이다.**

## AudioService 역할

게임 화면에서 직접 오디오를 재생하지 않고  
모든 오디오 출력은 AudioService를 통해 호출한다.

예:

```
AudioService.playNumber(3)
AudioService.playClap()
AudioService.playTurnNotification()
AudioService.playGameOver()
```

## 구조 목적

이 구조는 다음을 가능하게 한다.

- 게임 화면 코드 단순화
- TTS / 효과음 / 플랫폼 대응 분리
- 게임별 오디오 로직 재사용

## 예상 AudioService 위치

```
flutter_app/lib/services/audio_service.dart
```

## 1차 구현 범위

초기 구현에서는 다음 기능만 추가한다.

- 숫자 음성 출력
- 박수 효과음
- 턴 시작 알림
- 게임 종료 효과음

이후 단계에서

- 실제 음성 인식 입력
- 고급 TTS
- 게임 시작 구호

등을 추가한다.

---

## 7. 다음 창 작업 원칙 재확인

다음 창에서도 반드시 아래 원칙을 유지한다.

1. 최신 GitHub 저장소 구조 먼저 확인
2. 최신 EXECUTION_PLAN 기준으로 현재 단계 파악
3. 사용자가 붙여준 최신 파일 기준으로만 수정
4. 확인 안 된 파일은 절대 추측하지 않고 요청
5. 수정안은 반드시 unified diff 형식으로 제공
6. 초보자 기준으로 단계별 설명 유지

---

## 9. Audio 시스템 진행 결과 업데이트 (2026-03-16)

### 이번 창에서 실제 확인한 내용

Flutter 클라이언트에 `AudioService` 계층을 추가했고,
369 게임 화면에서는 직접 오디오를 재생하지 않고 `AudioService`를 호출하는 구조로 정리했다.

반영된 흐름:
- 게임 첫 진입 시 내 턴이면 `playTurnStart()` 호출
- 턴 전환으로 내 턴이 되면 `playTurnStart()` 호출
- 숫자 입력 성공 시 `playThreeSixNineCue(number)` 호출
- 박수 입력 성공 시 `playClap()` 호출
- 게임 종료 시 `playGameOver()` 호출

즉, **369 게임 화면과 오디오 출력 호출 지점은 분리 완료** 상태다.

### 시도했던 구현과 결과

#### 1차 시도: `SystemSound`
- 플랫폼별 차이로 인해 Windows에서 안정적으로 들리지 않음
- 테스트용으로는 신뢰성이 낮다고 판단

#### 2차 시도: `audioplayers` + asset 파일 재생
- WAV/MP3 테스트까지 진행했으나
- Windows 환경에서 plugin thread 경고 및 연결 끊김 문제 발생
- 실제 게임용 오디오 계층으로 채택 보류

#### 3차 시도: Windows `MessageBeep`, `Beep`
- 구조 연결 확인용으로는 사용 가능했음
- 그러나 게임용 사운드 품질이 너무 낮고,
  운영체제 환경에 따라 음 구분도 제한적이어서 최종 방식으로는 부적합

#### 4차 시도: `flutter_tts`
- 진짜 음성형으로 전환하려고 시도했으나
- Windows 빌드에서 `nuget.exe not found` 문제로 중단
- 현재 MVP 단계에서는 빌드 안정성을 해치므로 제거 결정

### 현재 결론

현재 단계에서는 **플러그인 기반 오디오/TTS를 잠시 보류**하고,
`AudioService`는 **호출 인터페이스만 유지하는 placeholder 상태**로 둔다.

즉,
- 화면/게임 로직 쪽에서는 오디오 호출 구조가 이미 준비됨
- 실제 오디오 출력 구현만 추후 교체 가능

이 구조 덕분에 나중에 아래 방식 중 하나를 쉽게 붙일 수 있다.

1. 사전 녹음 음성 파일 재생 방식
2. 안정적인 Windows 전용 TTS 방식
3. 서버 생성 음성 파일 다운로드 방식

### 현재 AudioService 상태

현재 `AudioService`는 실제 소리를 내지 않고, 호출 지점을 보존하는 목적의 placeholder 구현이다.

보존된 메서드:
- `playNumber(int number)`
- `playClap()`
- `playThreeSixNineCue(int number)`
- `playTurnStart()`
- `playGameOver()`
- `shouldClapForNumber(int number)`

이 상태는 이후 오디오 구현을 다시 붙일 때 `main.dart`를 거의 수정하지 않고,
`audio_service.dart`만 교체할 수 있게 해 준다.

---

## 10. 현재 369 게임 MVP 상태 재정리 (2026-03-16)

### 서버
- `GameEngine` 구조 유지
- `ThreeSixNineEngine` 판정 로직 정상 동작
- `game:submit` 공통 입력 이벤트 구조 정상

### Flutter
- 로비 / 방 생성 / 참가 정상
- 게임 시작 후 369 화면 전환 정상
- 숫자 입력 / 박수 입력 정상
- `submitGameInput()` 공통 구조 적용 완료
- 첫 진입 내 턴 감지 및 턴 전환 감지 로직 완료
- 오디오 호출 구조 분리 완료 (`AudioService`)

### 현재 실제 플레이 기준 확인 완료 항목
- 방 생성 / 참가 / 시작 정상
- 369 턴 진행 정상
- 숫자/박수 판정 정상
- 틀릴 때 게임 종료 정상
- 첫 턴/턴 전환/입력 성공/종료 시점의 오디오 호출 지점 정상

---

## 11. 다음 창 우선 작업 (업데이트)

### 최우선
사전 녹음 음성 파일 기반 Audio 시스템 설계를 진행한다.

#### 목표
- 실제 게임에서 사용할 수 있는 자연스러운 음성/효과음 구조 설계
- 플러그인 불안정성 없이 유지 가능한 방식 선택
- 369 게임에 먼저 적용 가능한 최소 음성 세트 정의

#### 먼저 정할 것
1. 파일 네이밍 규칙
2. 최소 음성 세트 범위
3. 숫자 음성 전략
   - 숫자별 개별 파일
   - 조합형 파일
   - 최소 MVP 범위만 우선 제작
4. 박수/시작/탈락 같은 공통 음성 파일 규칙

예상 최소 세트 예:
- `turn_start.wav`
- `clap.wav`
- `game_over.wav`
- `1.wav`, `2.wav`, `4.wav`, `5.wav`, `7.wav`, `8.wav`
- 이후 10 이상 숫자 전략 별도 설계

### 그 다음
- 369 게임용 음성 파일 구조 확정 후 `AudioService` 재구현
- 필요하면 음성 파일 재생 패키지 재선정
- 눈치게임 / 번데기 게임 엔진 실제 규칙 구현 준비

---

## 12. 다음 창 작업 원칙 재확인 (업데이트)

다음 창에서도 반드시 아래 원칙을 유지한다.

1. 최신 GitHub 저장소 구조 먼저 확인
2. 최신 EXECUTION_PLAN 기준으로 현재 단계 파악
3. 사용자가 붙여준 최신 파일 기준으로만 수정
4. 확인 안 된 파일은 절대 추측하지 않고 요청
5. 수정안은 반드시 unified diff 형식으로 제공
6. 초보자 기준으로 단계별 설명 유지
7. 한 번에 많이 수정하지 않고 작은 단위로 진행
8. Audio 구현은 실제 운영 품질을 기준으로 판단하고, 테스트용 억지 구현은 길게 끌지 않음


---

## 13. Audio 시스템 현재 결론 및 Windows MVP 임시 전략 (2026-03-17 업데이트)

### 현재 결론
현재 단계에서는 플러그인 기반 오디오 재생을 최종 채택하지 않는다.

이유:
- `audioplayers`, `just_audio`, `flutter_tts`, Windows Beep 계열 모두 MVP 기준에서 안정성 또는 품질 문제가 있었다.
- 현재 프로젝트의 더 중요한 목표는 369 게임 규칙, 공통 입력 구조, 다른 게임 확장 가능성 확보이다.
- 오디오 구조는 이미 `AudioService` 호출 계층으로 분리되어 있으므로, 실제 재생 방식은 나중에 교체해도 된다.

### 현재 유지 정책
- `AudioService`는 placeholder 상태로 유지한다.
- 369 화면은 오디오를 직접 재생하지 않고 `AudioService`만 호출한다.
- `assets/audio/369/` 폴더와 파일 네이밍 규칙은 유지한다.

### 369 게임용 최소 음성 세트 규칙
폴더:
```
app/flutter_app/assets/audio/369/
```

파일 예시:
```
turn_start.wav
clap.wav
game_over.wav
number_1.wav
number_2.wav
number_4.wav
number_5.wav
number_7.wav
number_8.wav
```

### Windows MVP 임시 전략 2안

#### 1안: 무음 유지 + 시각 피드백 강화
가장 우선 추천하는 전략이다.

구성:
- `AudioService`는 placeholder 유지
- 실제 소리는 내지 않음
- 대신 게임 화면에 짧은 상태 배너/텍스트 피드백을 강화

장점:
- 구조 안정성 최고
- Windows 플러그인 이슈 회피
- 본체 개발(규칙/엔진/UI 흐름)을 계속 진행 가능

#### 2안: 외부 재생기 실행 기반 임시 음성
필요 시에만 검토한다.

구성:
- Flutter 오디오 플러그인을 쓰지 않고
- Windows 외부 프로그램 또는 OS 기본 재생기를 통해 WAV를 재생하는 임시 우회 방식

주의:
- 지연 가능성
- 사용자 경험이 투박함
- 정식 채택 방식으로 오래 끌지 않음

### 현재 채택 결론
현재는 **1안(무음 유지 + 시각 피드백 강화)** 을 채택한다.

---

## 14. 턴 제한시간 규칙 정리 (2026-03-17 업데이트)

턴 제한시간은 이제 선택 기능이 아니라 **핵심 게임 룰**로 간주한다.

### 공통 원칙
- 모든 게임은 턴 제한시간을 가진다.
- 제한시간 안에 입력하지 못하면 즉시 패배 처리한다.
- 제한시간 시작 시점은 **시작 구호가 끝난 직후 첫 번째 플레이어 턴부터** 적용된다.
- 이후에는 각 턴이 시작될 때마다 새 제한시간이 시작된다.
- 최종 판정은 반드시 서버가 수행한다.
- 클라이언트는 남은 시간 표시 역할만 맡는다.

### 게임별 제한시간 옵션

#### 369 게임
- 0.5초
- 1초
- 3초
- 5초

#### 번데기 게임
- 0.5초
- 1초
- 3초
- 5초

#### 눈치 게임
- 3초
- 5초
- 10초

### 구조상 의미
이 규칙은 UI 옵션 정도가 아니라 서버 게임 진행 구조에 직접 들어가야 한다.

필수 반영 방향:
- 방 생성 시 게임별 허용 시간 옵션 제공
- 선택된 제한시간을 room/game state에 저장
- 게임 시작 구호 종료 후 첫 턴 시작 시각 기록
- 제출 시점이 마감시간 이내인지 서버가 판정
- 시간 초과 시 자동 패배 / 게임 종료 처리

### 서버 authoritative 원칙
반드시 지킬 것:
- 시간 판정은 서버 기준
- 클라이언트 타이머는 표시용
- 네트워크 지연이 있어도 최종 판정은 서버가 수행

즉, 나중에 구현할 때는 **타이머 UI 먼저가 아니라 서버 엔진/room state 구조부터** 설계해야 한다.

---

## 15. 모바일 중심 설계 원칙 (2026-03-17 업데이트)

이 프로젝트는 Windows 앱이 아니라 **스마트폰 실사용 게임**을 목표로 한다.

따라서 앞으로의 판단 기준은 다음과 같다.

### UI
- 버튼은 손가락 터치 기준으로 충분히 커야 한다.
- 세로형 화면에서 잘 보여야 한다.
- 짧은 시간 제한에서도 즉시 누를 수 있는 배치가 중요하다.

### 타이머
- 0.5초 / 1초 제한은 모바일 반응 속도를 고려한 UI가 필요하다.
- 시작 구호 종료 직후 첫 턴이 시작되므로 렌더링 지연이 적어야 한다.

### 피드백
- 모바일에서는 소리 외에도 강한 시각 피드백이 중요하다.
- 배너, 색상 변화, 아이콘, 진동 등으로 확장 가능하도록 구조를 잡는다.

### 네트워크
- 모바일 환경은 와이파이/데이터 품질이 흔들릴 수 있으므로 서버 authoritative 구조를 반드시 유지한다.

---

## 16. 다음 창 우선 작업 (2026-03-17 기준)

### 최우선 후보
1. 369 화면의 시각 피드백 최소 개선
   - 오디오 없이도 덜 심심하게 보이도록
   - 상태 배너 / 턴 안내 / 입력 성공 메시지 강화

2. 서버 타이머 설계 준비
   - room state에 제한시간 옵션을 어떻게 저장할지 정리
   - 시작 구호 종료 시점부터 첫 턴 타이머를 어떻게 시작할지 구조 설계

3. 방 생성 UI에서 게임별 제한시간 옵션을 어떻게 보여줄지 설계
   - 369/번데기: 0.5, 1, 3, 5초
   - 눈치: 3, 5, 10초

### 작업 원칙 재확인
- 최신 GitHub 구조 먼저 확인
- 최신 EXECUTION_PLAN 기준으로 현재 단계 파악
- 사용자가 붙여준 최신 파일 기준으로만 수정
- 확인 안 된 파일은 절대 추측하지 않고 요청
- 수정안은 반드시 unified diff 형식
- 초보자 기준 설명 유지
- 한 번에 많이 수정하지 않고 작은 단위로 진행
- 모바일 실사용 기준으로 판단


---

## 15. Progress Update (2026-03-18) - 턴 제한시간 설정 구조 1차 반영

### 이번 창에서 확인한 기준
- 최신 판단 기준 문서는 `EXECUTION_PLAN_v0.3_updated_2026-03-17.md`로 고정했다.
- 실제 플레이 대상은 스마트폰이며, Windows는 개발/테스트용으로만 본다.
- `AudioService`는 placeholder 유지 상태를 계속 유지한다.
- Windows MVP 오디오는 계속 **무음 유지 + 시각 피드백 강화** 전략으로 간다.
- 턴 시간 판정은 반드시 서버가 담당한다.

### 이번 창에서 확인한 현재 단계
- 서버는 `index.ts` 중심으로 방 관리 / 게임 선택 / 게임 시작 / `game:submit` 라우팅을 담당한다.
- 369 게임은 실제 제출과 판정이 가능하다.
- 눈치게임 / 번데기 게임은 엔진 파일 구조는 있으나, 실제 규칙 구현은 아직 다음 단계다.
- Flutter는 현재 `main.dart` 안에 홈 / 로비 / 369 화면이 함께 있는 구조다.
- `socket_service.dart`는 ack 기반 이벤트 호출과 `submitGameInput()` 공통 입력 경로를 이미 갖고 있다.

### 이번 창에서 정리한 핵심 설계 방향
턴 제한시간은 단순 UI 옵션이 아니라 **방 설정 → 서버 room state → 게임 state → 서버 타이머 판정**으로 이어지는 구조로 넣는다.

즉, 순서는 아래처럼 고정한다.

1. 방 생성/대기방에서 게임별 허용 제한시간을 선택한다.
2. 선택값은 서버의 room state에 저장한다.
3. 게임 시작 시 서버는 이 설정값을 함께 브로드캐스트한다.
4. 실제 제한시간 시작/만료 판정은 다음 단계에서 서버 타이머가 맡는다.
5. 클라이언트는 남은 시간 표시만 맡는다.

### 이번 창에서 반영 대상으로 확정한 최소 변경 범위
#### 서버 (`server/src/index.ts`)
- `room:create`에서 초기 제한시간 값을 받을 수 있게 한다.
- `room:update_settings` 이벤트를 추가한다.
- 방장만 제한시간을 변경할 수 있게 한다.
- 게임별 허용 시간값만 받도록 서버 검증을 둔다.
- 게임 시작 시 `turnTimeLimitMs`를 응답/브로드캐스트에 포함한다.
- 다음 diff에서 `turnTimeLimitMs`가 없으면 `game:start`를 막도록 할 예정이다.

#### 공통 타입 (`server/src/games/types.ts`)
- 게임별 제한시간 옵션 타입을 둔다.
- `GameRoom.settings.turnTimeLimitMs`를 둔다.
- 게임별 허용 시간 검증 함수를 둔다.

#### Flutter (`app/flutter_app/lib/main.dart`)
- 로비에서 현재 선택 게임에 맞는 제한시간 옵션을 표시한다.
- 방장이 제한시간 칩을 고를 수 있게 한다.
- 참가자는 보기만 하고 변경은 못 하게 한다.
- `room:update`에서 서버의 `settings.turnTimeLimitMs`를 반영한다.
- 게임 시작 버튼은 제한시간이 없으면 비활성화한다.

### 이번 창에서 확인한 파일 상태
- `socket_service.dart`는 이번 단계에서 추가 수정 없이 사용 가능하다.
- `submitGameInput()` 경로는 이후 서버 타이머가 붙어도 그대로 재사용한다.
- 따라서 이번 축은 `main.dart` + `index.ts` + `types.ts` 쪽으로 좁혀서 진행한다.

### 아직 안 한 것
- 실제 서버 타이머 시작/정지 로직
- 턴 시작 시각/만료 시각을 game state에 넣는 구조
- 시작 구호 종료 직후 첫 턴부터 타이머가 시작되는 서버 흐름
- 시간 초과 시 자동 패배 처리
- 눈치게임 / 번데기 게임의 실제 규칙 구현
- 모바일 기준 남은 시간 UI 표시

### 다음 창 1순위 작업
다음 창에서는 **실제 서버 타이머를 바로 길게 넣지 말고**, 먼저 아래 2단계를 작은 단위로 진행한다.

1. 최신 `server/src/games/types.ts` 확인
2. 최신 369 엔진 파일 확인
3. `gameState`에 아래 필드 추가 설계 검토
   - `turnStartedAt`
   - `turnDeadlineAt`
   - 필요하면 `turnTimeLimitMs`
4. 서버가 턴 전환 시 새 마감 시각을 계산하는 최소 구조 추가
5. 그 다음 단계에서 timeout 스케줄러 또는 타이머 매니저 방식 결정

### 현재 판단
지금은 **타이머를 억지로 바로 넣는 단계가 아니라, 제한시간 설정을 서버 authoritative 구조로 고정하는 단계**다.
이 순서를 지켜야 나중에 눈치게임/번데기까지 같은 방식으로 확장할 때 안 꼬인다.

---

## 16. 다음 창 작업 원칙 재확인 (2026-03-18)

다음 창에서도 아래 순서를 그대로 유지한다.

1. 최신 GitHub 저장소 구조 먼저 확인
2. 최신 EXECUTION_PLAN 기준으로 현재 단계 파악
3. 사용자가 붙여준 최신 파일 기준으로만 판단
4. 확인 안 된 파일은 절대 추측하지 않고 요청
5. 수정안은 반드시 unified diff 형식으로 제공
6. 초보자 기준으로 설명
7. 한 번에 많이 수정하지 않고 작은 단위로 진행
8. 실제 플레이 기준은 스마트폰, Windows는 개발/테스트용으로만 판단
9. 시간 판정은 항상 서버 기준으로 유지
10. AudioService는 placeholder 유지, Windows MVP는 무음 + 시각 피드백 전략 유지


---

## 17. Progress Update (2026-03-19)

### 이번 창에서 완료된 것
- 서버 authoritative 턴 타이머 구조의 핵심 뼈대를 추가했다.
- `GameState`에 턴 시간 관련 필드(`turnStartedAt`, `turnDeadlineAt`)를 도입하는 방향으로 정리했다.
- 369 엔진 기준으로 게임 시작 시점과 턴 전환 시점에 deadline을 계산하는 구조를 반영했다.
- 서버에서 timeout을 감시하고, 제한시간 초과 시 `game:over`를 보내는 흐름을 확인했다.
- 실제 안드로이드 폰 연결 테스트에 성공했다.
- `adb reverse tcp:3000 tcp:3000` 기반 로컬 서버 연결 방식으로 모바일 테스트가 가능함을 확인했다.
- 369 화면에 남은 시간 텍스트와 progress bar가 표시되는 단계까지는 확인했다.
- 시스템 키패드 대신 화면 내부 숫자패드 입력 구조로 전환하는 방향을 확정했다.
- 369는 숫자패드 + 제출 버튼 유지, 번데기는 즉시 입력형이 더 적합하다는 판단을 정리했다.

### 이번 창에서 확인된 문제
- 369 게임 화면 UI는 아직 미완성이다.
- 현재 369 화면은 모바일 기준 overflow가 반복 발생하고 있다.
- 상단 정보 영역과 하단 입력 영역의 비율이 안정적으로 잡히지 않았다.
- “한 화면 안에서 상단 게임상황 / 하단 입력패드” 구조가 아직 완성되지 않았다.
- 참가자 쪽 게임 종료 다이얼로그의 “로비로 돌아가기” 버튼이 안정적으로 동작하지 않는다.
- 긴 대화 중 반복 diff 적용 과정에서 `main.dart`에 잔여 코드와 문법 꼬임이 발생했다.

### 이번 창에서 확정된 UX 방향
#### 공통 방향
- 실제 기준은 스마트폰이다.
- 스크롤을 올리고 내리며 입력하는 구조는 허용하지 않는다.
- 게임 화면은 문서형 화면이 아니라 즉시 반응하는 게임형 화면이어야 한다.

#### 369 게임
- 숫자는 화면 내부 숫자패드로 입력한다.
- 시스템 키보드는 사용하지 않는다.
- 두 자리 이상 숫자를 고려해 `숫자 제출` 버튼은 유지한다.
- 남은 시간은 progress bar로 시각화한다.
- 다만 0.5초 제한시간은 모바일 UX상 현실적으로 매우 불리할 수 있으므로, 다음 창에서 규칙/UI 정책을 다시 검토한다.

#### 번데기 게임
- 입력값이 `뻔` / `데기` 두 가지뿐이므로 즉시 입력형 버튼 구조가 적합하다.
- 0.5초 제한시간도 게임 성격상 의미가 있다.

### 다음 창 1순위 작업
1. 최신 `main.dart`를 기준으로 369 화면 UI를 다시 안정화한다.
2. 목표는 “상단 게임상황 / 하단 입력패드”가 한 화면에 항상 보이는 모바일 고정형 레이아웃이다.
3. overflow를 없애고, 하단 숫자패드와 제출/박수 버튼이 첫 화면에 항상 보이도록 한다.
4. 참가자의 “로비로 돌아가기” 버튼 동작을 안정적으로 고친다.
5. 이 단계에서는 참가자 원형 배치 같은 큰 UI 개편보다, 먼저 현재 369 화면을 모바일에서 usable 상태로 만드는 데 집중한다.

### 다음 창 이후에 이어갈 큰 방향
- 369 화면 안정화 후 참가자 원형 배치 UI를 검토한다.
- 상단에는 참가자 캐릭터/닉네임/현재 턴 강조를 배치한다.
- 중앙에는 최근 액션(숫자/박수)을 보여주는 공간을 둔다.
- 2~8인 우선을 기준으로 설계하고, 10인은 추후 확장 옵션으로 본다.

### 현재 상태 요약
- 서버 타이머: 핵심 동작 확인 완료
- 모바일 실기 테스트: 성공
- 369 화면 UI: 미완성, 다음 창 최우선 수정 대상
- 번데기/눈치 화면 고도화: 아직 본격 착수 전


---

## 14. UI 안정화 진행 결과 업데이트 (2026-03-21)

### 이번 창에서 확인된 전제 재정리
- 실제 플레이 대상은 스마트폰이다.
- Windows는 개발/테스트용이다.
- `AudioService`는 placeholder 유지한다.
- Windows MVP 오디오는 무음 + 시각 피드백 강화 전략을 유지한다.
- 턴 시간 판정은 반드시 서버가 담당한다.

### 이번 창에서 완료된 사항
#### 1) 서버 authoritative 타이머 동작 재확인
- 369 게임에서 서버 기준 턴 타이머가 동작하는 것을 다시 확인했다.
- timeout 시 `game:over` 흐름이 실제 기기 기준으로 확인되었다.
- 안드로이드 폰 연결 및 실기 테스트 성공을 다시 확인했다.

#### 2) 369 게임 화면 시각 피드백 강화
- 남은 시간 텍스트 표시 추가 완료
- progress bar 표시 추가 완료
- 상단 게임상황 / 하단 입력패드 구조로 정리 진행
- 모바일 화면에서 overflow를 줄이는 방향으로 레이아웃 안정화 진행

#### 3) `main.dart` 경고 수정 완료
이번 창에서 `main.dart` 기준으로 다음 경고들을 해결했다.
- `onPressed` required 오류
- `child` required 오류
- positional argument 오류
- 괄호 누락 오류
- `TextStyle` 내부 잘못된 `style:` 중첩 오류

즉, 이번 창 기준 `main.dart`의 주요 문법 경고는 모두 정리되었다.

#### 4) 홈 화면 하단 버튼 가시성 개선
- 홈 화면의 `로비 입장` 버튼이 하단 시스템 영역에 묻히지 않도록 조정했다.
- `SafeArea` 반영으로 스마트폰 하단 내비게이션 바와 겹침을 줄였다.
- 아직 최종적으로는 `bottomNavigationBar` 고정 방식이 더 안정적일 수 있으므로 다음 창에서 최신 파일 기준으로 최종 반영 여부를 확인한다.

#### 5) 로비 화면 공간 최적화
- 참가자 목록 표시를 더 얇은 형태로 조정했다.
- 게임 선택 버튼을 한 줄 구조로 정리했다.
- 턴 제한시간 선택 영역까지 포함해 스크롤 발생을 줄이는 방향으로 조정했다.
- 다만 작은 화면/참가자 수 증가 시 스크롤이 완전히 사라질지는 추가 확인이 필요하다.

#### 6) 369 입력 패드 축소 및 usable 상태 확보
- 기존 3x4 형태의 큰 숫자패드를 축소했다.
- 현재는 5칸 x 2줄 (`12345 / 67890`) 구조로 정리되었다.
- 숫자 버튼 사이즈는 현재 수준이 적절하다고 판단되었다.
- 숫자 제출 버튼과 박수 입력 버튼이 한 화면 안에 같이 보이는 usable 상태에 도달했다.

### 현재 UI 상태 판단
#### 홈 화면
- 거의 usable 상태
- `로비 입장` 버튼은 이전보다 잘 보이지만, 다음 창에서 더 안정적인 고정 방식으로 마무리할 수 있다.

#### 게임 로비
- usable 상태
- 다음 창에서 아래 한 줄은 제거하는 방향이 적절하다고 정리되었다.
  - `선택된 게임: 369 게임`
- 이 줄은 정보 중복이며 세로 공간만 차지한다.

#### 369 게임 화면
- usable 상태 도달
- 숫자 버튼 크기는 현재 수준 유지가 적절하다.
- 상단 정보 / 타이머 / 진행 bar / 입력패드 구조는 현재 방향이 맞다.
- 참가자용 게임 종료 후 `로비로 돌아가기` 동작은 다음 창에서 최신 파일 기준으로 다시 점검한다.

### 이번 창 기준 미반영 / 다음 창 준비 사항
#### 1) 로비 중복 문구 제거
다음 창에서 우선 제거할 후보:
- `선택된 게임: 369 게임`

#### 2) 홈 화면 하단 버튼 최종 고정 방식 검토
후보:
- `bottomNavigationBar` 사용

#### 3) 369 고급 룰 확장 준비
사용자가 제안한 369 고급 룰은 다음과 같다.

- **1단계 게임**: 369 차례에 박수 입력
- **2단계 게임**: 369 차례 박수 입력 + 10,20,30... 십단위 차례에 만세 입력
- **3단계 게임**: 369 차례 박수 + 십단위 차례 만세 입력 + 3의 배수 차례에 박수 입력

이 기능은 아직 이번 창에서 구현하지 않았다.
이유:
- 클라이언트 버튼 추가뿐 아니라
- 서버 `moveType` 확장,
- 엔진 규칙 판정,
- 로비의 난이도 선택 UI,
- 게임 시작 payload 전달 구조
까지 함께 확인해야 하기 때문이다.

즉, 이 부분은 **반드시 서버 파일 확인 후** 작은 단위 diff로 진행한다.

### 다음 창 우선순위 (2026-03-21 기준)
#### 최우선
1. 최신 `main.dart` 기준으로 홈 화면 하단 버튼 구조 최종 마무리
2. 게임 로비에서 `선택된 게임: ...` 문구 제거
3. 참가자 게임 종료 후 `로비로 돌아가기` 동작 재점검

#### 그 다음
4. `만세 입력` 추가 가능 여부 확인
5. 난이도 선택 UI 설계 시작
6. 서버 엔진이 새 `moveType`을 받을 수 있는지 확인

### 다음 창에서 먼저 확인할 파일
고급 룰 확장을 시작하려면 아래 최신 파일 확인이 필요하다.
- `app/flutter_app/lib/main.dart`
- `server/src/games/types.ts`
- `server/src/games/engines/ThreeSixNineEngine.ts`
- 필요 시 `server/src/index.ts`

### 다음 창 작업 원칙 재확인 (2026-03-21)
1. 최신 GitHub 저장소 구조 먼저 확인
2. 최신 EXECUTION_PLAN 기준으로 현재 단계 파악
3. 사용자가 붙여준 최신 파일 기준으로만 수정
4. 확인 안 된 파일은 절대 추측하지 않고 요청
5. 수정안은 반드시 unified diff 형식으로 제공
6. 초보자 기준으로 설명
7. 한 번에 많이 수정하지 말 것
8. 스마트폰 실사용 기준으로 UI 판단
