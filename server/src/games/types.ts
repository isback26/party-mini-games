export type GameType = "three_six_nine" | "nunchi" | "beondegi";

export type TurnTimeLimitMs = 500 | 1000 | 3000 | 5000 | 10000;

export const TURN_TIME_LIMIT_OPTIONS_BY_GAME: Record<
  GameType,
  readonly TurnTimeLimitMs[]
> = {
  three_six_nine: [500, 1000, 3000, 5000],
  nunchi: [3000, 5000, 10000],
  beondegi: [500, 1000, 3000, 5000],
};

export type GameRoomSettings = {
  turnTimeLimitMs: TurnTimeLimitMs | null;
};

export function isAllowedTurnTimeLimitMs(
  gameType: GameType,
  value: unknown
): value is TurnTimeLimitMs {
  return (
    typeof value === "number" &&
    TURN_TIME_LIMIT_OPTIONS_BY_GAME[gameType].includes(value as TurnTimeLimitMs)
  );
}

export type GamePlayer = {
  socketId: string;
  nickname: string;
};

export type GameRoom = {
  code: string;
  hostSocketId: string;
  selectedGame: GameType;
  settings: GameRoomSettings;
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
