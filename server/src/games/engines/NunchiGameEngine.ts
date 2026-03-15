import { GameEngine, GameRoom, GameState } from "../types";

export class NunchiGameEngine implements GameEngine {
  readonly gameType = "nunchi" as const;

  createInitialState(room: GameRoom): GameState {
    return {
      gameType: this.gameType,
      roomCode: room.code,
      phase: "playing",
      currentTurnSocketId: null,
      round: 1,
      metadata: {
        introMessage: "시작!!",
        submittedNumbers: [],
      },
    };
  }
}