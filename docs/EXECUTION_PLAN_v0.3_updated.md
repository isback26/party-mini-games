# EXECUTION_PLAN_v0.3

## 1. 프로젝트 개요

프로젝트명: Party Mini Games

목표:
친구들끼리 방을 만들고 실시간으로 미니게임을 즐길 수 있는 멀티플레이 파티 게임 앱 MVP를 만든다.

현재 우선순위:
1. 로비/대기방 흐름 안정화
2. 369 게임 MVP 완성
3. 게임 진행 상태와 판정 로직 서버화
4. Flutter 게임 화면 분리
5. 멀티플레이 테스트 안정화

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

### 2순위
369 화면 입력 구조를 공통화 가능한지 검토한다.

예:
- 버튼 입력
- 박수 입력
- 이후 음성 입력

### 3순위
눈치 / 번데기 엔진 실제 규칙 구현은 그 다음 단계에서 진행한다.

---

## 7. 다음 창 작업 원칙 재확인

다음 창에서도 반드시 아래 원칙을 유지한다.

1. 최신 GitHub 저장소 구조 먼저 확인
2. 최신 EXECUTION_PLAN 기준으로 현재 단계 파악
3. 사용자가 붙여준 최신 파일 기준으로만 수정
4. 확인 안 된 파일은 절대 추측하지 않고 요청
5. 수정안은 반드시 unified diff 형식으로 제공
6. 초보자 기준으로 단계별 설명 유지
