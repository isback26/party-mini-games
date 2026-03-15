import {
  GameEngine,
  GameRoom,
  GameState,
  GameSubmitPayload,
  GameSubmitResult,
} from "../types";

type ThreeSixNineMoveType = "number" | "clap";

type ThreeSixNineMetadata = {
  introMessage: string;
  expectedNumber: number;
  clapNumbers: number[];
  expectedMoveType: ThreeSixNineMoveType;
  expectedDisplayText: string;
  lastActionMessage: string;
  loserSocketId?: string;
  loserNickname?: string;
};

export class ThreeSixNineEngine implements GameEngine {
  readonly gameType = "three_six_nine" as const;

  createInitialState(room: GameRoom): GameState<ThreeSixNineMetadata> {
    const expectedNumber = 1;
    const expectedMove = this.getExpectedMove(expectedNumber);

    return {
      gameType: this.gameType,
      roomCode: room.code,
      phase: "playing",
      currentTurnSocketId: room.players[0]?.socketId ?? null,
      round: 1,
      metadata: {
        introMessage: "삼육구, 삼육구",
        expectedNumber,
        clapNumbers: [3, 6, 9],
        expectedMoveType: expectedMove.moveType,
        expectedDisplayText: expectedMove.displayText,
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
    const expectedNumber = Number(metadata.expectedNumber ?? 1);
    const expectedMove = this.getExpectedMove(expectedNumber);
    const currentPlayer =
      room.players.find((player) => player.socketId === payload.playerSocketId)?.nickname ??
      "알 수 없음";

    const isCorrect =
      expectedMove.moveType === "clap"
        ? payload.moveType === "clap"
        : payload.moveType === "number" && Number(payload.value) === expectedNumber;

    if (!isCorrect) {
      return {
        isCorrect: false,
        isFinished: true,
        message: `${currentPlayer} 님이 틀렸습니다. 게임 종료!`,
        gameState: {
          ...gameState,
          phase: "finished",
          metadata: {
            ...metadata,
            expectedNumber,
            expectedMoveType: expectedMove.moveType,
            expectedDisplayText: expectedMove.displayText,
            lastActionMessage: `${currentPlayer} 님이 틀렸습니다.`,
            loserSocketId: payload.playerSocketId,
            loserNickname: currentPlayer,
          },
        },
      };
    }

    const nextExpectedNumber = expectedNumber + 1;
    const nextExpectedMove = this.getExpectedMove(nextExpectedNumber);
    const nextTurnSocketId = this.getNextPlayerSocketId(room, payload.playerSocketId);

    return {
      isCorrect: true,
      isFinished: false,
      message:
        expectedMove.moveType === "clap"
          ? `${currentPlayer} 님이 ${expectedMove.displayText} 입력 성공`
          : `${currentPlayer} 님이 ${expectedNumber} 입력 성공`,
      gameState: {
        ...gameState,
        round: Number(gameState.round ?? 1) + 1,
        currentTurnSocketId: nextTurnSocketId,
        metadata: {
          ...metadata,
          expectedNumber: nextExpectedNumber,
          expectedMoveType: nextExpectedMove.moveType,
          expectedDisplayText: nextExpectedMove.displayText,
          lastActionMessage:
            expectedMove.moveType === "clap"
              ? `${currentPlayer} 님이 ${expectedMove.displayText} 입력 성공`
              : `${currentPlayer} 님이 ${expectedNumber} 입력 성공`,
        },
      },
    };
  }

  private normalizeMetadata(
    metadata: Record<string, unknown>
  ): ThreeSixNineMetadata {
    const expectedNumber = Number(metadata.expectedNumber ?? 1);
    const expectedMove = this.getExpectedMove(expectedNumber);

    return {
      introMessage:
        typeof metadata.introMessage === "string" ? metadata.introMessage : "삼육구, 삼육구",
      expectedNumber,
      clapNumbers: Array.isArray(metadata.clapNumbers)
        ? (metadata.clapNumbers as number[])
        : [3, 6, 9],
      expectedMoveType:
        metadata.expectedMoveType === "number" || metadata.expectedMoveType === "clap"
          ? metadata.expectedMoveType
          : expectedMove.moveType,
      expectedDisplayText:
        typeof metadata.expectedDisplayText === "string"
          ? metadata.expectedDisplayText
          : expectedMove.displayText,
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

  private getExpectedMove(
    num: number
  ): { moveType: ThreeSixNineMoveType; displayText: string } {
    const clapCount = this.countClaps(num);

    if (clapCount > 0) {
      return {
        moveType: "clap",
        displayText: "👏".repeat(clapCount),
      };
    }

    return {
      moveType: "number",
      displayText: String(num),
    };
  }
}
