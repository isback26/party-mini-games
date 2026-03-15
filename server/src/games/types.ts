export type GameType = "three_six_nine" | "nunchi" | "beondegi";

export type GamePlayer = {
  socketId: string;
  nickname: string;
};

export type GameRoom = {
  code: string;
  hostSocketId: string;
  selectedGame: GameType;
  players: GamePlayer[];
  status: "waiting" | "playing";
};

export type GameState<TMetadata extends Record<string, unknown> = Record<string, unknown>> = {
  gameType: GameType;
  roomCode: string;
  phase: "waiting_start" | "playing" | "finished";
  currentTurnSocketId: string | null;
  round: number;
  metadata: TMetadata;
};

export type GameSubmitInputMode = "touch" | "voice";

export type GameSubmitPayload = {
  playerSocketId: string;
  moveType: string;
  value?: number;
  text?: string;
  inputMode?: GameSubmitInputMode;
  recognizedText?: string;
};

export type GameSubmitResult = {
  gameState: GameState;
  isCorrect: boolean;
  isFinished: boolean;
  message: string;
};

export interface GameEngine {
  readonly gameType: GameType;
  createInitialState(room: GameRoom): GameState;
  submitTurn(
    room: GameRoom,
    gameState: GameState,
    payload: GameSubmitPayload
  ): GameSubmitResult;
}
