import express from "express";
import { createGameEngine } from "./games/createGameEngine";
import {
  GameState,
  GameRoom,
  GameType,
  TurnTimeLimitMs,
  ThreeSixNineDifficulty,
  isAllowedTurnTimeLimitMs,
  isAllowedThreeSixNineDifficulty,
} from "./games/types";
import cors from "cors";
import { createServer } from "http";
import { Server } from "socket.io";

const app = express();
const httpServer = createServer(app);

const io = new Server(httpServer, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("Party Mini Games Server is running.");
});

const allowedGameTypes: GameType[] = ["three_six_nine", "nunchi", "beondegi"];

const rooms = new Map<string, GameRoom>();
const roomGameStates = new Map<string, GameState>();

type GameSubmitEventPayload = {
  roomCode: string;
  moveType: string;
  value?: number;
  text?: string;
  inputMode?: "touch" | "voice";
  recognizedText?: string;
};

type RoomCreateEventPayload = {
  nickname: string;
  turnTimeLimitMs?: TurnTimeLimitMs | null;
  difficulty?: ThreeSixNineDifficulty;
};

type RoomUpdateSettingsEventPayload = {
  roomCode: string;
  turnTimeLimitMs?: TurnTimeLimitMs;
  difficulty?: ThreeSixNineDifficulty;
};

const TURN_TIMEOUT_CHECK_INTERVAL_MS = 100;
const GAME_START_COUNTDOWN_MS = 4000;

function finishGameState(
  gameState: GameState,
  metadataPatch: Record<string, unknown>
): GameState {
  return {
    ...gameState,
    phase: "finished",
    currentTurnSocketId: null,
    turnStartedAt: null,
    turnDeadlineAt: null,
    metadata: {
      ...gameState.metadata,
      ...metadataPatch,
    },
  };
}

function attachStartCountdownMetadata(gameState: GameState): GameState {
  if (gameState.phase !== "waiting_start") {
    return gameState;
  }

  const hasCountdownEndsAt =
    typeof gameState.metadata?.countdownEndsAt === "number";

  if (hasCountdownEndsAt) {
    return gameState;
  }

  const countdownStartedAt = Date.now();
  const countdownEndsAt = countdownStartedAt + GAME_START_COUNTDOWN_MS;

  return {
    ...gameState,
    metadata: {
      ...gameState.metadata,
      countdownStartedAt,
      countdownEndsAt,
      lastActionMessage:
        typeof gameState.metadata?.lastActionMessage === "string"
          ? gameState.metadata.lastActionMessage
          : "시작 구호가 끝나면 첫 번째 플레이어부터 입력합니다.",
    },
  };
}

function buildTimeoutFinishedState(gameState: GameState): GameState {
  return {
    ...gameState,
    phase: "finished",
    currentTurnSocketId: null,
    turnStartedAt: null,
    turnDeadlineAt: null,
  };
}

function getPlayerNickname(room: GameRoom, socketId: string | null): string {
  if (!socketId) {
    return "알 수 없는 플레이어";
  }

  return (
    room.players.find((player) => player.socketId === socketId)?.nickname ??
    "알 수 없는 플레이어"
  );
}

function resetTurnTimer(
  gameState: GameState,
  turnTimeLimitMs: number | null
): GameState {
  const turnStartedAt = Date.now();
  const turnDeadlineAt =
    turnTimeLimitMs != null ? turnStartedAt + turnTimeLimitMs : null;

  return {
    ...gameState,
    turnStartedAt,
    turnDeadlineAt,
  };
}

function beginPlayingPhase(
  gameState: GameState,
  turnTimeLimitMs: number | null
): GameState {
  const turnStartedAt = Date.now();
  const turnDeadlineAt =
    turnTimeLimitMs != null ? turnStartedAt + turnTimeLimitMs : null;

  return {
    ...gameState,
    phase: "playing",
    turnStartedAt,
    turnDeadlineAt,
    metadata: {
      ...gameState.metadata,
      countdownStartedAt: null,
      countdownEndsAt: null,
      lastActionMessage:
        gameState.gameType === "nunchi"
          ? "시작! 살아있는 사람 누구나 먼저 숫자를 누르세요."
          : "시작! 첫 번째 플레이어가 입력해주세요.",
    },
  };
}

function finalizeNunchiPendingWindow(
  room: GameRoom,
  gameState: GameState
): { gameState: GameState; isFinished: boolean; message: string } {
  const pendingNumber =
    typeof gameState.metadata?.pendingNumber === "number"
      ? gameState.metadata.pendingNumber
      : null;
  const pendingSubmissions = Array.isArray(gameState.metadata?.pendingSubmissions)
    ? (gameState.metadata.pendingSubmissions as Array<{
        socketId: string;
        nickname: string;
        submittedAt: number;
      }>)
    : [];
  const aliveSocketIds = Array.isArray(gameState.metadata?.aliveSocketIds)
    ? (gameState.metadata.aliveSocketIds as string[])
    : [];
  const submittedNumbers = Array.isArray(gameState.metadata?.submittedNumbers)
    ? ([...gameState.metadata.submittedNumbers] as number[])
    : [];
  const expectedNumber =
    typeof gameState.metadata?.expectedNumber === "number"
      ? gameState.metadata.expectedNumber
      : 1;

  if (pendingNumber == null || pendingSubmissions.length === 0) {
    return {
      gameState,
      isFinished: false,
      message:
        gameState.metadata?.lastActionMessage?.toString() ??
        "눈치게임 상태가 유지되었습니다.",
    };
  }

  const uniqueSocketIds = [...new Set(pendingSubmissions.map((item) => item.socketId))];

  if (uniqueSocketIds.length >= 2) {
    const loserNicknames = uniqueSocketIds.map((socketId) =>
      getPlayerNickname(room, socketId)
    );
    const message = `${pendingNumber}을(를) 0.5초 안에 동시에 눌러 ${loserNicknames.join(", ")}님이 탈락했습니다.`;

    return {
      gameState: finishGameState(gameState, {
        loserSocketIds: uniqueSocketIds,
        loserSocketId: uniqueSocketIds[0] ?? null,
        loserNicknames,
        loserNickname: loserNicknames[0] ?? null,
        pendingNumber: null,
        pendingWindowEndsAt: null,
        pendingSubmissions: [],
        pendingSubmitterSocketIds: [],
        lastSubmittedDisplayText: pendingNumber.toString(),
        lastActionMessage: message,
      }),
      isFinished: true,
      message,
    };
  }

  const successSocketId = uniqueSocketIds[0];
  const successNickname = getPlayerNickname(room, successSocketId);
  const nextAliveSocketIds = aliveSocketIds.filter(
    (socketId) => socketId !== successSocketId
  );
  const nextSubmittedNumbers = [...submittedNumbers, pendingNumber];

  if (nextAliveSocketIds.length <= 1) {
    const loserSocketId = nextAliveSocketIds[0] ?? null;
    const loserNickname = getPlayerNickname(room, loserSocketId);
    const message = `${successNickname}님이 ${pendingNumber} 성공! 마지막까지 남은 ${loserNickname}님이 탈락했습니다.`;

    return {
      gameState: finishGameState(gameState, {
        aliveSocketIds: nextAliveSocketIds,
        submittedNumbers: nextSubmittedNumbers,
        expectedNumber: expectedNumber + 1,
        loserSocketIds: loserSocketId ? [loserSocketId] : [],
        loserSocketId,
        loserNicknames: loserSocketId ? [loserNickname] : [],
        loserNickname: loserSocketId ? loserNickname : null,
        pendingNumber: null,
        pendingWindowEndsAt: null,
        pendingSubmissions: [],
        pendingSubmitterSocketIds: [],
        lastSubmittedDisplayText: pendingNumber.toString(),
        lastActionMessage: message,
      }),
      isFinished: true,
      message,
    };
  }

  const nextState = resetTurnTimer(
    {
      ...gameState,
      currentTurnSocketId: null,
      round: gameState.round + 1,
      metadata: {
        ...gameState.metadata,
        aliveSocketIds: nextAliveSocketIds,
        submittedNumbers: nextSubmittedNumbers,
        expectedNumber: expectedNumber + 1,
        pendingNumber: null,
        pendingWindowEndsAt: null,
        pendingSubmissions: [],
        pendingSubmitterSocketIds: [],
        lastSubmittedDisplayText: pendingNumber.toString(),
        lastActionMessage: `${successNickname}님이 ${pendingNumber} 성공! 다음 숫자는 ${expectedNumber + 1}입니다.`,
      },
    },
    room.settings.turnTimeLimitMs
  );

  return {
    gameState: nextState,
    isFinished: false,
    message:
      nextState.metadata?.lastActionMessage?.toString() ??
      `${successNickname}님이 ${pendingNumber} 성공!`,
  };
}

function generateRoomCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let result = "";
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

function buildStartOrderedRoom(room: GameRoom, previousGameState?: GameState): GameRoom {
  const loserSocketId =
    typeof previousGameState?.metadata?.loserSocketId === "string"
      ? previousGameState.metadata.loserSocketId
      : null;

  if (!loserSocketId) {
    return room;
  }

  const loserIndex = room.players.findIndex(
    (player) => player.socketId === loserSocketId
  );

  if (loserIndex <= 0) {
    return room;
  }

  return {
    ...room,
    players: [
      ...room.players.slice(loserIndex),
      ...room.players.slice(0, loserIndex),
    ],
  };
}

io.on("connection", (socket) => {
  console.log(`User connected: ${socket.id}`);

  socket.on("room:create", (payload: RoomCreateEventPayload, callback) => {
    try {
      const nickname = payload?.nickname?.trim();
      const requestedTurnTimeLimitMs = payload?.turnTimeLimitMs ?? null;
      const requestedDifficulty = payload?.difficulty ?? "easy";

      if (!nickname) {
        callback({ ok: false, message: "닉네임을 입력해주세요." });
        return;
      }

      if (
        requestedTurnTimeLimitMs !== null &&
        !isAllowedTurnTimeLimitMs("three_six_nine", requestedTurnTimeLimitMs)
      ) {
        callback({
          ok: false,
          message: "369 게임 제한시간 옵션이 올바르지 않습니다.",
        });
        return;
      }

      if (!isAllowedThreeSixNineDifficulty(requestedDifficulty)) {
        callback({
          ok: false,
          message: "369 게임 난이도 옵션이 올바르지 않습니다.",
        });
        return;
      }

      let code = generateRoomCode();
      while (rooms.has(code)) {
        code = generateRoomCode();
      }

      const room: GameRoom = {
        code,
        hostSocketId: socket.id,
        selectedGame: "three_six_nine",
        settings: {
          turnTimeLimitMs: requestedTurnTimeLimitMs,
          difficulty: requestedDifficulty,
        },
        status: "waiting",
        players: [
          {
            socketId: socket.id,
            nickname,
          },
        ],
      };

      rooms.set(code, room);
      socket.join(code);

      console.log(`[ROOM CREATED] ${code} / host=${nickname}`);

      callback({
        ok: true,
        roomCode: code,
        room,
      });

      io.to(code).emit("room:update", room);
    } catch (error) {
      callback({ ok: false, message: "방 생성 중 오류가 발생했습니다." });
    }
  });

  socket.on(
    "room:join",
    (payload: { nickname: string; roomCode: string }, callback) => {
      try {
        const nickname = payload?.nickname?.trim();
        const roomCode = payload?.roomCode?.trim().toUpperCase();

        if (!nickname) {
          callback({ ok: false, message: "닉네임을 입력해주세요." });
          return;
        }

        if (!roomCode) {
          callback({ ok: false, message: "방 코드를 입력해주세요." });
          return;
        }

        const room = rooms.get(roomCode);

        if (!room) {
          callback({ ok: false, message: "존재하지 않는 방입니다." });
          return;
        }

        const alreadyJoined = room.players.some(
          (player) => player.socketId === socket.id
        );

        if (!alreadyJoined) {
          room.players.push({
            socketId: socket.id,
            nickname,
          });
        }

        socket.join(roomCode);

        console.log(`[ROOM JOIN] ${roomCode} / user=${nickname}`);

        callback({
          ok: true,
          room,
        });

        io.to(roomCode).emit("room:update", room);
      } catch (error) {
        callback({ ok: false, message: "방 입장 중 오류가 발생했습니다." });
      }
    }
  );

  socket.on(
    "room:select_game",
    (
      payload: { roomCode: string; gameType: GameType },
      callback: (response: Record<string, unknown>) => void
    ) => {
      try {
        const roomCode = payload?.roomCode?.trim().toUpperCase();
        const gameType = payload?.gameType;

        if (!roomCode) {
          callback({ ok: false, message: "방 코드가 필요합니다." });
          return;
        }

        const room = rooms.get(roomCode);

        if (!room) {
          callback({ ok: false, message: "존재하지 않는 방입니다." });
          return;
        }

        if (room.hostSocketId !== socket.id) {
          callback({ ok: false, message: "방장만 게임을 선택할 수 있습니다." });
          return;
        }

        if (!allowedGameTypes.includes(gameType)) {
          callback({ ok: false, message: "지원하지 않는 게임입니다." });
          return;
        }

        room.selectedGame = gameType;

        if (
        room.settings.turnTimeLimitMs !== null &&
        !isAllowedTurnTimeLimitMs(gameType, room.settings.turnTimeLimitMs)
      ) {
        room.settings.turnTimeLimitMs = null;
      }

        callback({
          ok: true,
          selectedGame: room.selectedGame,
          room,
        });

        io.to(roomCode).emit("room:update", room);
      } catch (error) {
        callback({ ok: false, message: "게임 선택 중 오류가 발생했습니다." });
      }
    }
  );

  socket.on(
    "room:update_settings",
    (
      payload: RoomUpdateSettingsEventPayload,
      callback: (response: Record<string, unknown>) => void
    ) => {
      try {
        const roomCode = payload?.roomCode?.trim().toUpperCase();
        const turnTimeLimitMs = payload?.turnTimeLimitMs;
        const difficulty = payload?.difficulty;

        if (!roomCode) {
          callback({ ok: false, message: "방 코드가 필요합니다." });
          return;
        }

        const room = rooms.get(roomCode);
        if (!room) {
          callback({ ok: false, message: "존재하지 않는 방입니다." });
          return;
        }

        if (room.hostSocketId !== socket.id) {
          callback({ ok: false, message: "방장만 설정을 변경할 수 있습니다." });
          return;
        }

        if (room.status !== "waiting") {
          callback({
            ok: false,
            message: "게임 진행 중에는 설정을 변경할 수 없습니다.",
          });
          return;
        }

        if (
          turnTimeLimitMs != null &&
          !isAllowedTurnTimeLimitMs(room.selectedGame, turnTimeLimitMs)
        ) {
          callback({
            ok: false,
            message: "선택한 게임에서 사용할 수 없는 제한시간입니다.",
          });
          return;
        }

        if (
          difficulty != null &&
          room.selectedGame === "three_six_nine" &&
          !isAllowedThreeSixNineDifficulty(difficulty)
        ) {
          callback({
            ok: false,
            message: "369 게임에서 사용할 수 없는 난이도입니다.",
          });
          return;
        }

        room.settings.turnTimeLimitMs = turnTimeLimitMs ?? room.settings.turnTimeLimitMs;
        room.settings.difficulty = difficulty ?? room.settings.difficulty;

        callback({
          ok: true,
          room,
        });
        io.to(roomCode).emit("room:update", room);
      } catch (error) {
        callback({ ok: false, message: "방 설정 변경 중 오류가 발생했습니다." });
      }
    }
  );

  socket.on(
    "game:start",
    (
      payload: { roomCode: string },
      callback: (response: Record<string, unknown>) => void
    ) => {
      try {
        const roomCode = payload?.roomCode?.trim().toUpperCase();

        if (!roomCode) {
          callback({ ok: false, message: "방 코드가 필요합니다." });
          return;
        }

        const room = rooms.get(roomCode);

        if (!room) {
          callback({ ok: false, message: "존재하지 않는 방입니다." });
          return;
        }

        if (room.hostSocketId !== socket.id) {
          callback({ ok: false, message: "방장만 게임을 시작할 수 있습니다." });
          return;
        }

        if (room.players.length < 2) {
          callback({ ok: false, message: "최소 2명 이상 있어야 시작할 수 있습니다." });
          return;
        }

        if (room.settings.turnTimeLimitMs === null) {
          callback({ ok: false, message: "턴 제한시간을 먼저 선택해주세요." });
          return;
        }

        const engine = createGameEngine(room.selectedGame);
        const previousGameState = roomGameStates.get(roomCode);
        const orderedRoom = buildStartOrderedRoom(room, previousGameState);
        const gameState = attachStartCountdownMetadata(
          engine.createInitialState(orderedRoom)
        );

        room.status = "playing";
        roomGameStates.set(roomCode, gameState);

        callback({
          ok: true,
          gameType: room.selectedGame,
          countdownMs: GAME_START_COUNTDOWN_MS,
          difficulty: room.settings.difficulty,
          turnTimeLimitMs: room.settings.turnTimeLimitMs,
          gameState,
        });

        io.to(roomCode).emit("room:update", room);
        io.to(roomCode).emit("game:state", gameState);
        io.to(roomCode).emit("game:started", {
          roomCode: room.code,
          gameType: room.selectedGame,
          countdownMs: GAME_START_COUNTDOWN_MS,
          difficulty: room.settings.difficulty,
          turnTimeLimitMs: room.settings.turnTimeLimitMs,
          gameState,
        });
      } catch (error) {
        callback({ ok: false, message: "게임 시작 중 오류가 발생했습니다." });
      }
    }
  );

  socket.on(
    "game:submit",
    (
      payload: GameSubmitEventPayload,
      callback: (response: Record<string, unknown>) => void
    ) => {
      try {
        const roomCode = payload?.roomCode?.trim().toUpperCase();
        const moveType = payload?.moveType;
        const value = payload?.value;
        const text = payload?.text;
        const inputMode = payload?.inputMode;
        const recognizedText = payload?.recognizedText;

        if (!roomCode) {
          callback({ ok: false, message: "방 코드가 필요합니다." });
          return;
        }

        if (!moveType || typeof moveType !== "string") {
          callback({ ok: false, message: "moveType이 필요합니다." });
          return;
        }

        const room = rooms.get(roomCode);

        if (!room) {
          callback({ ok: false, message: "존재하지 않는 방입니다." });
          return;
        }

        if (room.status !== "playing") {
          callback({ ok: false, message: "현재 진행 중인 게임이 없습니다." });
          return;
        }

        const gameState = roomGameStates.get(roomCode);

        if (!gameState) {
          callback({ ok: false, message: "게임 상태를 찾을 수 없습니다." });
          return;
        }

        if (
          room.selectedGame !== "nunchi" &&
          gameState.currentTurnSocketId !== socket.id
        ) {
          callback({ ok: false, message: "지금은 당신의 턴이 아닙니다." });
          return;
        }

        const engine = createGameEngine(room.selectedGame);
        const submitResult = engine.submitTurn(room, gameState, {
          playerSocketId: socket.id,
          moveType,
          value,
          text,
          inputMode,
          recognizedText,
        });

        roomGameStates.set(roomCode, submitResult.gameState);

        if (submitResult.isFinished) {
          room.status = "waiting";

          callback({
            ok: true,
            correct: false,
            gameState: submitResult.gameState,
          });

          io.to(roomCode).emit("room:update", room);
          io.to(roomCode).emit("game:state", submitResult.gameState);
          io.to(roomCode).emit("game:over", {
            roomCode,
            gameType: room.selectedGame,
            gameState: submitResult.gameState,
            message: submitResult.message,
          });
          return;
        }

        callback({
          ok: true,
          correct: true,
          gameState: submitResult.gameState,
        });

        io.to(roomCode).emit("game:state", submitResult.gameState);
      } catch (error) {
        callback({ ok: false, message: "입력 처리 중 오류가 발생했습니다." });
      }
    }
  );

  socket.on("disconnect", () => {
    console.log(`User disconnected: ${socket.id}`);

    for (const [roomCode, room] of rooms.entries()) {
      const originalLength = room.players.length;
      room.players = room.players.filter((player) => player.socketId !== socket.id);

      if (room.players.length !== originalLength) {
        if (room.players.length === 0) {
          rooms.delete(roomCode);
          roomGameStates.delete(roomCode);
          console.log(`[ROOM REMOVED] ${roomCode}`);
        } else {
          if (room.hostSocketId === socket.id) {
            room.hostSocketId = room.players[0].socketId;
          }
          const gameState = roomGameStates.get(roomCode);
          if (room.status === "playing" && room.players.length < 2) {
            room.status = "waiting";
          }
          if (room.status === "waiting" && gameState) {
            const stoppedState: GameState = {
              ...gameState,
              currentTurnSocketId: room.players[0]?.socketId ?? null,
              turnStartedAt: null,
              turnDeadlineAt: null,
            };
            roomGameStates.set(roomCode, stoppedState);
            io.to(roomCode).emit("game:state", stoppedState);
          } else if (gameState?.currentTurnSocketId === socket.id) {
            const reassignedState = resetTurnTimer(
              {
                ...gameState,
                currentTurnSocketId: room.players[0]?.socketId ?? null,
              },
              room.settings.turnTimeLimitMs
            );
            roomGameStates.set(roomCode, reassignedState);
            io.to(roomCode).emit("game:state", reassignedState);
          }
          io.to(roomCode).emit("room:update", room);
        }
      }
    }
  });
});

setInterval(() => {
  const now = Date.now();

  for (const [roomCode, room] of rooms.entries()) {
    if (room.status !== "playing") {
      continue;
    }

    const gameState = roomGameStates.get(roomCode);
    if (!gameState) {
      continue;
    }

    if (gameState.phase === "waiting_start") {
      const countdownEndsAt =
        typeof gameState.metadata?.countdownEndsAt === "number"
          ? gameState.metadata.countdownEndsAt
          : null;

      if (countdownEndsAt == null) {
        continue;
      }

      if (now >= countdownEndsAt) {
        const playingState = beginPlayingPhase(
          gameState,
          room.settings.turnTimeLimitMs
        );
        if (playingState.gameType === "nunchi") {
          playingState.metadata = {
            ...playingState.metadata,
            lastActionMessage: "시작! 살아있는 사람 누구나 먼저 숫자를 누르세요.",
          };
        }
        roomGameStates.set(roomCode, playingState);
        io.to(roomCode).emit("game:state", playingState);
      }
      continue;
    }

    if (gameState.gameType === "nunchi" && gameState.phase === "playing") {
      const pendingWindowEndsAt =
        typeof gameState.metadata?.pendingWindowEndsAt === "number"
          ? gameState.metadata.pendingWindowEndsAt
          : null;

      if (pendingWindowEndsAt != null) {
        if (now >= pendingWindowEndsAt) {
          const finalized = finalizeNunchiPendingWindow(room, gameState);

          if (finalized.isFinished) {
            room.status = "waiting";
            roomGameStates.set(roomCode, finalized.gameState);
            io.to(roomCode).emit("room:update", room);
            io.to(roomCode).emit("game:state", finalized.gameState);
            io.to(roomCode).emit("game:over", {
              roomCode,
              gameType: room.selectedGame,
              gameState: finalized.gameState,
              message: finalized.message,
            });
          } else {
            roomGameStates.set(roomCode, finalized.gameState);
            io.to(roomCode).emit("game:state", finalized.gameState);
          }
        }
        continue;
      }
    }

    if (gameState.phase !== "playing" || gameState.turnDeadlineAt == null) {
      continue;
    }

    if (now < gameState.turnDeadlineAt) {
      continue;
    }

    const timeoutLoserNickname = getPlayerNickname(
      room,
      gameState.currentTurnSocketId
    );
    if (gameState.gameType === "nunchi") {
      const aliveSocketIds = Array.isArray(gameState.metadata?.aliveSocketIds)
        ? (gameState.metadata.aliveSocketIds as string[])
        : [];
      const expectedNumber =
        typeof gameState.metadata?.expectedNumber === "number"
          ? gameState.metadata.expectedNumber
          : 1;
      const loserNicknames = aliveSocketIds.map((socketId) =>
        getPlayerNickname(room, socketId)
      );
      const message =
        loserNicknames.length > 0
          ? `제한시간 안에 아무도 ${expectedNumber}을(를) 누르지 못해 ${loserNicknames.join(", ")}님이 탈락했습니다.`
          : "제한시간 안에 아무도 입력하지 못했습니다.";

      const finishedState = finishGameState(gameState, {
        loserSocketIds: aliveSocketIds,
        loserSocketId: aliveSocketIds[0] ?? null,
        loserNicknames,
        loserNickname: loserNicknames[0] ?? null,
        lastSubmittedSocketId: null,
        pendingNumber: null,
        pendingWindowEndsAt: null,
        pendingSubmissions: [],
        pendingSubmitterSocketIds: [],
        lastActionMessage: message,
      });

      room.status = "waiting";
      roomGameStates.set(roomCode, finishedState);

      io.to(roomCode).emit("room:update", room);
      io.to(roomCode).emit("game:state", finishedState);
      io.to(roomCode).emit("game:over", {
        roomCode,
        gameType: room.selectedGame,
        gameState: finishedState,
        message,
      });
      continue;
    }

    const loserNickname = getPlayerNickname(room, gameState.currentTurnSocketId);
    const finishedState: GameState = {
      ...buildTimeoutFinishedState(gameState),
      metadata: {
        ...gameState.metadata,
        loserSocketId: gameState.currentTurnSocketId,
        loserNickname: timeoutLoserNickname,
        lastActionMessage: `${timeoutLoserNickname}님이 제한시간을 초과했습니다.`,
      },
    };

    room.status = "waiting";
    roomGameStates.set(roomCode, finishedState);

    io.to(roomCode).emit("room:update", room);
    io.to(roomCode).emit("game:state", finishedState);
    io.to(roomCode).emit("game:over", {
      roomCode,
      gameType: room.selectedGame,
      gameState: finishedState,
      message: `${timeoutLoserNickname}님이 제한시간을 초과했습니다.`,
    });
  }
}, TURN_TIMEOUT_CHECK_INTERVAL_MS);

const PORT = 3000;

httpServer.listen(PORT, "0.0.0.0", () => {
  console.log(`Server listening on http://0.0.0.0:${PORT}`);
});