import {
  GameEngine,
  GameRoom,
  GameState,
  GameSubmitPayload,
  GameSubmitResult,
} from "../types";

type NunchiPendingSubmission = {
  socketId: string;
  nickname: string;
  submittedAt: number;
};

export class NunchiGameEngine implements GameEngine {
  readonly gameType = "nunchi" as const;

  createInitialState(room: GameRoom): GameState {
    const aliveSocketIds = room.players.map((player) => player.socketId);
    const targetNumber = Math.max(room.players.length - 1, 1);

    return {
      gameType: this.gameType,
      roomCode: room.code,
      phase: "waiting_start",
      currentTurnSocketId: null,
      turnStartedAt: null,
      turnDeadlineAt: null,
      round: 1,
      metadata: {
        introMessage: "시작!!",
        countdownStartedAt: null,
        countdownEndsAt: null,
        lastActionMessage: "시작!! 카운트다운 후 참가자 누구나 먼저 1을 누르세요.",
        lastSubmittedDisplayText: "-",
        lastSubmittedSocketId: null,
        submittedNumbers: [],
        aliveSocketIds,
        expectedNumber: 1,
        targetNumber,
        pendingWindowMs: 500,
        pendingNumber: null,
        pendingWindowEndsAt: null,
        pendingSubmissions: [],
        pendingSubmitterSocketIds: [],
      },
    };
  }

  private buildFinishedState(
    room: GameRoom,
    gameState: GameState,
    loserSocketIds: string[],
    message: string
  ): GameState {
    const loserNicknames = loserSocketIds.map((socketId) => {
      return (
        room.players.find((player) => player.socketId === socketId)?.nickname ??
        "알 수 없는 플레이어"
      );
    });

    return {
      ...gameState,
      phase: "finished",
      currentTurnSocketId: null,
      turnStartedAt: null,
      turnDeadlineAt: null,
      metadata: {
        ...gameState.metadata,
        loserSocketIds,
        loserSocketId: loserSocketIds[0] ?? null,
        loserNicknames,
        loserNickname: loserNicknames[0] ?? null,
        lastSubmittedSocketId: loserSocketIds[0] ?? null,
        pendingNumber: null,
        pendingWindowEndsAt: null,
        pendingSubmissions: [],
        pendingSubmitterSocketIds: [],
        lastActionMessage: message,
      },
    };
  }

  submitTurn(
    room: GameRoom,
    gameState: GameState,
    payload: GameSubmitPayload
  ): GameSubmitResult {
    if (gameState.phase !== "playing") {
      return {
        gameState,
        isCorrect: false,
        isFinished: false,
        message: "아직 게임이 시작되지 않았습니다.",
      };
    }

    const aliveSocketIds = Array.isArray(gameState.metadata?.aliveSocketIds)
      ? (gameState.metadata.aliveSocketIds as string[])
      : [];
    const expectedNumber =
      typeof gameState.metadata?.expectedNumber === "number"
        ? gameState.metadata.expectedNumber
        : 1;
    const pendingNumber =
      typeof gameState.metadata?.pendingNumber === "number"
        ? gameState.metadata.pendingNumber
        : null;
    const pendingSubmitterSocketIds = Array.isArray(
      gameState.metadata?.pendingSubmitterSocketIds
    )
      ? ([...gameState.metadata.pendingSubmitterSocketIds] as string[])
      : [];
    const pendingSubmissions = Array.isArray(gameState.metadata?.pendingSubmissions)
      ? ([...gameState.metadata.pendingSubmissions] as NunchiPendingSubmission[])
      : [];

    const playerNickname =
      room.players.find((player) => player.socketId === payload.playerSocketId)
        ?.nickname ?? "알 수 없는 플레이어";

    if (!aliveSocketIds.includes(payload.playerSocketId)) {
      return {
        gameState,
        isCorrect: false,
        isFinished: false,
        message: "이미 탈락했거나 성공한 플레이어는 입력할 수 없습니다.",
      };
    }

    if (payload.moveType !== "number" || typeof payload.value !== "number") {
      const finishedState = this.buildFinishedState(
        room,
        gameState,
        [payload.playerSocketId],
        `${playerNickname}님이 잘못된 입력을 해서 탈락했습니다.`
      );
      return {
        gameState: finishedState,
        isCorrect: false,
        isFinished: true,
        message: `${playerNickname}님이 잘못된 입력을 해서 탈락했습니다.`,
      };
    }

    const submittedValue = Math.trunc(payload.value);
    if (!Number.isFinite(submittedValue) || submittedValue <= 0) {
      const finishedState = this.buildFinishedState(
        room,
        gameState,
        [payload.playerSocketId],
        `${playerNickname}님이 잘못된 숫자를 입력해서 탈락했습니다.`
      );
      return {
        gameState: finishedState,
        isCorrect: false,
        isFinished: true,
        message: `${playerNickname}님이 잘못된 숫자를 입력해서 탈락했습니다.`,
      };
    }

    if (submittedValue !== expectedNumber) {
      const finishedState = this.buildFinishedState(
        room,
        gameState,
        [payload.playerSocketId],
        `${playerNickname}님이 ${expectedNumber} 대신 ${submittedValue}을(를) 눌러 탈락했습니다.`
      );
      return {
        gameState: finishedState,
        isCorrect: false,
        isFinished: true,
        message: `${playerNickname}님이 ${expectedNumber} 대신 ${submittedValue}을(를) 눌러 탈락했습니다.`,
      };
    }

    if (pendingSubmitterSocketIds.includes(payload.playerSocketId)) {
      return {
        gameState,
        isCorrect: false,
        isFinished: false,
        message: "이미 같은 숫자 입력 판정 대기 중입니다.",
      };
    }

    const now = Date.now();

    if (pendingNumber === expectedNumber) {
      const nextPendingSubmissions = [
        ...pendingSubmissions,
        {
          socketId: payload.playerSocketId,
          nickname: playerNickname,
          submittedAt: now,
        },
      ];

      const nextGameState: GameState = {
        ...gameState,
        metadata: {
          ...gameState.metadata,
          pendingSubmissions: nextPendingSubmissions,
          pendingSubmitterSocketIds: [
            ...pendingSubmitterSocketIds,
            payload.playerSocketId,
          ],
          lastSubmittedDisplayText: submittedValue.toString(),
          lastSubmittedSocketId: payload.playerSocketId,
          lastActionMessage: `${playerNickname}님이 ${submittedValue} 입력, 동시 입력 판정 중...`,
        },
      };

      return {
        gameState: nextGameState,
        isCorrect: true,
        isFinished: false,
        message: `${playerNickname}님이 ${submittedValue} 입력, 동시 입력 판정 중...`,
      };
    }

    const nextGameState: GameState = {
      ...gameState,
      metadata: {
        ...gameState.metadata,
        pendingNumber: submittedValue,
        pendingWindowEndsAt:
          now + ((gameState.metadata?.pendingWindowMs as number | undefined) ?? 500),
        pendingSubmissions: [
          {
            socketId: payload.playerSocketId,
            nickname: playerNickname,
            submittedAt: now,
          },
        ],
        pendingSubmitterSocketIds: [payload.playerSocketId],
        lastSubmittedDisplayText: submittedValue.toString(),
        lastSubmittedSocketId: payload.playerSocketId,
        lastActionMessage: `${playerNickname}님이 ${submittedValue} 입력, 0.5초 동시 입력 판정 중...`,
      },
    };

    return {
      gameState: nextGameState,
      isCorrect: true,
      isFinished: false,
      message: `${playerNickname}님이 ${submittedValue} 입력, 0.5초 동시 입력 판정 중...`,
    };
  }
}
