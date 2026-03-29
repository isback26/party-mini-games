import {
  GameEngine,
  GameRoom,
  GameState,
  GameSubmitPayload,
  GameSubmitResult,
  ThreeSixNineDifficulty,
  ThreeSixNineMoveType,
} from "../types";

type ThreeSixNineMetadata = {
  introMessage: string;
  countdownStartedAt: number | null;
  countdownEndsAt: number | null;
  difficulty: ThreeSixNineDifficulty;
  expectedNumber: number;
  clapNumbers: number[];
  expectedMoveType: ThreeSixNineMoveType;
  expectedDisplayText: string;
  lastSubmittedDisplayText: string;
  lastActionMessage: string;
  loserSocketId?: string;
  loserNickname?: string;
};

export class ThreeSixNineEngine implements GameEngine {
  readonly gameType = "three_six_nine" as const;

  createInitialState(room: GameRoom): GameState<ThreeSixNineMetadata> {
    const difficulty = this.normalizeDifficulty(room.settings.difficulty);
    const expectedNumber = 1;
    const expectedMove = this.getExpectedMove(expectedNumber, difficulty);
    const countdownStartedAt = Date.now();
    const countdownEndsAt = countdownStartedAt + 4000;

    return {
      gameType: this.gameType,
      roomCode: room.code,
      phase: "waiting_start",
      currentTurnSocketId: room.players[0]?.socketId ?? null,
      turnStartedAt: null,
      turnDeadlineAt: null,
      round: 1,
      metadata: {
        introMessage: "삼육구, 삼육구",
        countdownStartedAt,
        countdownEndsAt,
        difficulty,
        expectedNumber,
        clapNumbers: [3, 6, 9],
        expectedMoveType: expectedMove.moveType,
        expectedDisplayText: expectedMove.displayText,
        lastSubmittedDisplayText: "-",
        lastActionMessage: "게임이 시작되었습니다.",
      },
    };
  }

submitTurn(
    room: GameRoom,
    gameState: GameState,
    payload: GameSubmitPayload
  ): GameSubmitResult {
    const metadata = this.normalizeMetadata(gameState.metadata);
    const difficulty = metadata.difficulty;
    const expectedNumber = Number(metadata.expectedNumber ?? 1);
    const expectedMove = this.getExpectedMove(expectedNumber, difficulty);
    const currentPlayer =
      room.players.find((player) => player.socketId === payload.playerSocketId)?.nickname ??
      "알 수 없음";
    const submittedDisplayText = this.getSubmittedDisplayText(payload);

    const isCorrect =
      expectedMove.moveType === "clap"
        ? payload.moveType === "clap" &&
          this.countSubmittedClaps(payload.text) === expectedMove.clapCount
        : expectedMove.moveType === "manse"
          ? payload.moveType === "manse"
        : payload.moveType === "number" && Number(payload.value) === expectedNumber;

    if (!isCorrect) {
      return {
        isCorrect: false,
        isFinished: true,
        message: `${currentPlayer} 님이 "${submittedDisplayText}"를 입력했습니다. 정답은 "${expectedMove.displayText}"인데 틀렸습니다. 게임 종료!`,
        gameState: {
          ...gameState,
          phase: "finished",
          metadata: {
            ...metadata,
            difficulty,
            expectedNumber,
            expectedMoveType: expectedMove.moveType,
            expectedDisplayText: expectedMove.displayText,
            lastSubmittedDisplayText: submittedDisplayText,
            lastActionMessage: `${currentPlayer} 님이 "${submittedDisplayText}"를 입력했습니다. 정답은 "${expectedMove.displayText}"인데 틀렸습니다.`,
            loserSocketId: payload.playerSocketId,
            loserNickname: currentPlayer,
          },
        },
      };
    }

    const nextExpectedNumber = expectedNumber + 1;
    const nextExpectedMove = this.getExpectedMove(nextExpectedNumber, difficulty);
    const nextTurnSocketId = this.getNextPlayerSocketId(room, payload.playerSocketId);
    const nextTurnStartedAt = Date.now();
    const nextTurnDeadlineAt =
      room.settings.turnTimeLimitMs != null
        ? nextTurnStartedAt + room.settings.turnTimeLimitMs
        : null;

    return {
      isCorrect: true,
      isFinished: false,
      message:
        expectedMove.moveType === "clap"
          ? `${currentPlayer} 님이 ${expectedMove.displayText} 입력 성공`
          : expectedMove.moveType === "manse"
            ? `${currentPlayer} 님이 만세 입력 성공`
          : `${currentPlayer} 님이 ${expectedNumber} 입력 성공`,
      gameState: {
        ...gameState,
        round: Number(gameState.round ?? 1) + 1,
        turnStartedAt: nextTurnStartedAt,
        turnDeadlineAt: nextTurnDeadlineAt,
        currentTurnSocketId: nextTurnSocketId,
        metadata: {
          ...metadata,
          difficulty,
          expectedNumber: nextExpectedNumber,
          expectedMoveType: nextExpectedMove.moveType,
          expectedDisplayText: nextExpectedMove.displayText,
          lastSubmittedDisplayText: submittedDisplayText,
          lastActionMessage:
            expectedMove.moveType === "clap"
              ? `${currentPlayer} 님이 ${expectedMove.displayText} 입력 성공`
              : expectedMove.moveType === "manse"
                ? `${currentPlayer} 님이 만세 입력 성공`
              : `${currentPlayer} 님이 ${expectedNumber} 입력 성공`,
        },
      },
    };
  }

  private normalizeMetadata(
    metadata: Record<string, unknown>
  ): ThreeSixNineMetadata {
    const expectedNumber = Number(metadata.expectedNumber ?? 1);
    const difficulty = this.normalizeDifficulty(metadata.difficulty);
    const expectedMove = this.getExpectedMove(expectedNumber, difficulty);

    return {
      introMessage:
        typeof metadata.introMessage === "string" ? metadata.introMessage : "삼육구, 삼육구",
      countdownStartedAt:
        typeof metadata.countdownStartedAt === "number" ? metadata.countdownStartedAt : null,
      countdownEndsAt:
        typeof metadata.countdownEndsAt === "number" ? metadata.countdownEndsAt : null,
      difficulty,
      expectedNumber,
      clapNumbers: Array.isArray(metadata.clapNumbers)
        ? (metadata.clapNumbers as number[])
        : [3, 6, 9],
      expectedMoveType:
        metadata.expectedMoveType === "number" ||
        metadata.expectedMoveType === "clap" ||
        metadata.expectedMoveType === "manse"
          ? metadata.expectedMoveType
          : expectedMove.moveType,
      expectedDisplayText:
        typeof metadata.expectedDisplayText === "string"
          ? metadata.expectedDisplayText
          : expectedMove.displayText,
      lastSubmittedDisplayText:
        typeof metadata.lastSubmittedDisplayText === "string"
          ? metadata.lastSubmittedDisplayText
          : "-",
      lastActionMessage:
        typeof metadata.lastActionMessage === "string"
          ? metadata.lastActionMessage
          : "게임이 시작되었습니다.",
      loserSocketId:
        typeof metadata.loserSocketId === "string" ? metadata.loserSocketId : undefined,
      loserNickname:
        typeof metadata.loserNickname === "string" ? metadata.loserNickname : undefined,
    };
  }

  private getNextPlayerSocketId(
    room: GameRoom,
    currentSocketId: string | null
  ): string | null {
    if (!currentSocketId || room.players.length === 0) {
      return room.players[0]?.socketId ?? null;
    }

    const currentIndex = room.players.findIndex(
      (player) => player.socketId === currentSocketId
    );

    if (currentIndex === -1) {
      return room.players[0]?.socketId ?? null;
    }

    const nextIndex = (currentIndex + 1) % room.players.length;
    return room.players[nextIndex]?.socketId ?? null;
  }

  private countClaps(num: number): number {
    return num
      .toString()
      .split("")
      .filter((digit) => digit === "3" || digit === "6" || digit === "9").length;
  }

  private countSubmittedClaps(text?: string): number {
    if (typeof text !== "string" || text.trim().length === 0) {
      return 1;
    }

    const clapCount = [...text].filter((char) => char === "👏").length;

    return clapCount > 0 ? clapCount : 1;
  }

  private getSubmittedDisplayText(payload: GameSubmitPayload): string {
    if (payload.moveType === "number") {
      if (typeof payload.value === "number" && Number.isFinite(payload.value)) {
        return String(payload.value);
      }
      return typeof payload.text === "string" && payload.text.trim().length > 0
        ? payload.text.trim()
        : "?";
    }

    if (payload.moveType === "clap") {
      return typeof payload.text === "string" && payload.text.trim().length > 0
        ? payload.text
        : "👏";
    }

    if (payload.moveType === "manse") return "🙌";
    return typeof payload.text === "string" && payload.text.trim().length > 0 ? payload.text : "?";
  }

  private normalizeDifficulty(value: unknown): ThreeSixNineDifficulty {
    if (value === "normal" || value === "hard") {
      return value;
    }
    return "easy";
  }

  private getExpectedMove(
    num: number,
    difficulty: ThreeSixNineDifficulty
  ): { moveType: ThreeSixNineMoveType; displayText: string; clapCount: number } {
    if (difficulty === "normal" || difficulty === "hard") {
      if (num % 10 === 0) {
        return {
          moveType: "manse",
          displayText: "만세",
          clapCount: 0,
        };
      }
    }

    const clapCount = this.countClaps(num);

    if (clapCount > 0) {
      return {
        moveType: "clap",
        displayText: "👏".repeat(clapCount),
        clapCount,
      };
    }

    if (difficulty === "hard" && num % 3 === 0) {
      return {
        moveType: "clap",
        displayText: "👏",
        clapCount: 1,
      };
    }

    return {
      moveType: "number",
      displayText: String(num),
      clapCount: 0,
    };
  }
}
