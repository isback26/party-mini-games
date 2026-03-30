import 'dart:async';
import 'package:flutter/material.dart';
import 'services/socket_service.dart';
import 'services/audio_service.dart';

void main() {
  runApp(const PartyMiniGamesApp());
}

class PartyMiniGamesApp extends StatelessWidget {
  const PartyMiniGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Party Mini Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> games = const ['369 게임', '눈치게임', '번데기 게임'];
  final TextEditingController nicknameController = TextEditingController();
  final SocketService socketService = SocketService();

  String connectionText = '서버 연결 전';

  @override
  void initState() {
    super.initState();

    socketService.connect(
      onConnected: () {
        if (!mounted) return;
        setState(() {
          connectionText = '서버 연결됨';
        });
      },
      onDisconnected: () {
        if (!mounted) return;
        setState(() {
          connectionText = '서버 연결 안 됨';
        });
      },
      onConnectError: (_) {
        if (!mounted) return;
        setState(() {
          connectionText = '서버 연결 실패';
        });
      },
    );
  }

  @override
  void dispose() {
    nicknameController.dispose();
    super.dispose();
  }

  void onLobbyEnterPressed() {
    final nickname = nicknameController.text.trim();

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('닉네임을 입력해주세요.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LobbyScreen(nickname: nickname, socketService: socketService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('파티 미니게임'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              double titleFontSize = 20;
              if (width < 360) {
                titleFontSize = 16;
              } else if (width < 420) {
                titleFontSize = 18;
              }

              return Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    '모임에서 바로 즐기는 실시간 미니게임',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    connectionText,
                    style: TextStyle(
                      fontSize: 14,
                      color: socketService.isConnected
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nicknameController,
                    decoration: InputDecoration(
                      labelText: '닉네임 입력',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '지원 예정 게임',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: games.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            dense: true,
                            title: Text(games[index]),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${games[index]} 준비 중')),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onLobbyEnterPressed,
                      child: const Text('로비 입장'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class LobbyScreen extends StatefulWidget {
  final String nickname;
  final SocketService socketService;

  const LobbyScreen({
    super.key,
    required this.nickname,
    required this.socketService,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController roomCodeController = TextEditingController();

  static const Map<String, String> gameLabels = {
    'three_six_nine': '369 게임',
    'nunchi': '눈치게임',
    'beondegi': '번데기 게임',
  };

  static const Map<String, List<int>> turnTimeOptionsByGame = {
    'three_six_nine': [500, 1000, 3000, 5000],
    'nunchi': [3000, 5000, 10000],
    'beondegi': [500, 1000, 3000, 5000],
  };

  static const Map<String, String> threeSixNineDifficultyLabels = {
    'easy': '쉬움',
    'normal': '보통',
    'hard': '어려움',
  };

  String? currentRoomCode;
  List<dynamic> players = [];
  String? hostSocketId;
  String selectedGame = 'three_six_nine';
  String selectedDifficulty = 'easy';
  int? selectedTurnTimeLimitMs = 3000;
  String roomStatus = 'waiting';
  bool isLoading = false;
  String statusMessage = '로비에 입장했습니다.';
  String? startedGameLabel;

  @override
  void initState() {
    super.initState();

    widget.socketService.off('room:update');
    widget.socketService.off('game:started');
    widget.socketService.on('room:update', _handleRoomUpdate);
    widget.socketService.on('game:started', _handleGameStarted);
  }

  @override
  void dispose() {
    widget.socketService.off('room:update');
    widget.socketService.off('game:started');
    roomCodeController.dispose();
    super.dispose();
  }

  void _handleRoomUpdate(dynamic data) {
    if (!mounted) return;

    final roomCode = data['code']?.toString();
    final nextPlayers = (data['players'] as List?) ?? [];
    final nextHostSocketId = data['hostSocketId']?.toString();
    final nextSelectedGame = data['selectedGame']?.toString() ?? selectedGame;
    final nextRoomStatus = data['status']?.toString() ?? 'waiting';
    final nextTurnTimeLimitMs = data['settings']?['turnTimeLimitMs'] as int?;
    final nextDifficulty =
        data['settings']?['difficulty']?.toString() ?? selectedDifficulty;

    setState(() {
      currentRoomCode = roomCode;
      players = nextPlayers;
      hostSocketId = nextHostSocketId;
      selectedGame = nextSelectedGame;
      selectedDifficulty = nextDifficulty;
      selectedTurnTimeLimitMs = nextTurnTimeLimitMs;
      roomStatus = nextRoomStatus;
      isLoading = false;
      statusMessage = '대기방 정보가 업데이트되었습니다.';
    });
  }

  void _handleGameStarted(dynamic data) {
    if (!mounted) return;

    final gameType = data['gameType']?.toString() ?? selectedGame;
    final gameState = data['gameState'];

    setState(() {
      startedGameLabel = gameLabels[gameType] ?? gameType;
      roomStatus = 'playing';
      statusMessage = '${startedGameLabel ?? "게임"} 시작됨';
    });

    if (gameType == 'three_six_nine') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ThreeSixNineGameScreen(
            nickname: widget.nickname,
            socketService: widget.socketService,
            roomCode: currentRoomCode ?? '',
            players: players,
            initialGameState: gameState,
          ),
        ),
      );
    } else if (gameType == 'nunchi') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NunchiGameScreen(
            nickname: widget.nickname,
            socketService: widget.socketService,
            roomCode: currentRoomCode ?? '',
            players: players,
            initialGameState: gameState,
          ),
        ),
      );
    }
  }

  Future<void> _createRoom() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
      statusMessage = '방을 만드는 중...';
    });

    widget.socketService.emitWithAck(
      'room:create',
      {
        'nickname': widget.nickname,
        'turnTimeLimitMs': selectedTurnTimeLimitMs,
        'difficulty': selectedDifficulty,
      },
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage =
                response?['message']?.toString() ?? '방 만들기에 실패했습니다.';
          });
          return;
        }

        setState(() {
          final room = response['room'] as Map<String, dynamic>?;
          currentRoomCode =
              room?['code']?.toString() ?? response['roomCode']?.toString();
          players = (room?['players'] as List?) ?? [];
          hostSocketId = room?['hostSocketId']?.toString();
          selectedGame = room?['selectedGame']?.toString() ?? selectedGame;
          selectedTurnTimeLimitMs =
              room?['settings']?['turnTimeLimitMs'] as int?;
          selectedDifficulty =
              room?['settings']?['difficulty']?.toString() ??
              selectedDifficulty;
          isLoading = false;
          statusMessage = '방이 생성되었습니다.';
        });
      },
    );
  }

  Future<void> _joinRoom() async {
    if (isLoading) return;

    final roomCode = roomCodeController.text.trim().toUpperCase();

    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('참가할 방 코드를 입력해주세요.')));
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = '방에 참가하는 중...';
    });

    widget.socketService.emitWithAck(
      'room:join',
      {'roomCode': roomCode, 'nickname': widget.nickname},
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage = response?['message']?.toString() ?? '방 참가에 실패했습니다.';
          });
          return;
        }

        setState(() {
          final room = response['room'] as Map<String, dynamic>?;
          currentRoomCode = room?['code']?.toString() ?? roomCode;
          hostSocketId = room?['hostSocketId']?.toString();
          selectedGame = room?['selectedGame']?.toString() ?? selectedGame;
          selectedTurnTimeLimitMs =
              room?['settings']?['turnTimeLimitMs'] as int?;
          selectedDifficulty =
              room?['settings']?['difficulty']?.toString() ??
              selectedDifficulty;
          players = (room?['players'] as List?) ?? [];
          isLoading = false;
          statusMessage = '방에 참가했습니다.';
        });
      },
    );
  }

  Future<void> _selectGame(String gameType) async {
    if (currentRoomCode == null || isLoading) return;

    setState(() {
      isLoading = true;
      statusMessage = '게임을 선택하는 중...';
    });

    widget.socketService.emitWithAck(
      'room:select_game',
      {'roomCode': currentRoomCode, 'gameType': gameType},
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage =
                response?['message']?.toString() ?? '게임 선택에 실패했습니다.';
          });
          return;
        }

        setState(() {
          selectedGame = response['selectedGame']?.toString() ?? gameType;
          final room = response['room'] as Map<String, dynamic>?;
          selectedDifficulty =
              room?['settings']?['difficulty']?.toString() ??
              selectedDifficulty;
          selectedDifficulty = gameType == 'three_six_nine'
              ? (room?['settings']?['difficulty']?.toString() ??
                    selectedDifficulty)
              : 'easy';
          selectedTurnTimeLimitMs =
              room?['settings']?['turnTimeLimitMs'] as int?;
          isLoading = false;
          statusMessage = '게임이 선택되었습니다.';
        });
      },
    );
  }

  Future<void> _updateTurnTimeLimit(int turnTimeLimitMs) async {
    if (currentRoomCode == null || isLoading) return;

    setState(() {
      isLoading = true;
      statusMessage = '제한시간을 변경하는 중...';
    });

    widget.socketService.emitWithAck(
      'room:update_settings',
      {
        'roomCode': currentRoomCode,
        'turnTimeLimitMs': turnTimeLimitMs,
        'difficulty': selectedDifficulty,
      },
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage =
                response?['message']?.toString() ?? '제한시간 변경에 실패했습니다.';
          });
          return;
        }

        setState(() {
          final room = response['room'] as Map<String, dynamic>?;
          selectedTurnTimeLimitMs =
              room?['settings']?['turnTimeLimitMs'] as int?;
          isLoading = false;
          statusMessage = '제한시간이 변경되었습니다.';
        });
      },
    );
  }

  Future<void> _updateThreeSixNineDifficulty(String difficulty) async {
    if (currentRoomCode == null || isLoading) return;

    setState(() {
      isLoading = true;
      statusMessage = '난이도를 변경하는 중...';
    });

    widget.socketService.emitWithAck(
      'room:update_settings',
      {
        'roomCode': currentRoomCode,
        'turnTimeLimitMs': selectedTurnTimeLimitMs,
        'difficulty': difficulty,
      },
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage =
                response?['message']?.toString() ?? '난이도 변경에 실패했습니다.';
          });
          return;
        }

        setState(() {
          selectedDifficulty = difficulty;
          isLoading = false;
          statusMessage = '난이도가 변경되었습니다.';
        });
      },
    );
  }

  String _turnTimeLabel(int ms) {
    if (ms == 500) return '0.5초';
    if (ms == 1000) return '1초';
    return '${ms ~/ 1000}초';
  }

  Future<void> _startGame() async {
    if (currentRoomCode == null || isLoading) return;

    setState(() {
      isLoading = true;
      statusMessage = '게임을 시작하는 중...';
    });

    widget.socketService.emitWithAck(
      'game:start',
      {'roomCode': currentRoomCode},
      (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isLoading = false;
            statusMessage =
                response?['message']?.toString() ?? '게임 시작에 실패했습니다.';
          });
          return;
        }

        setState(() {
          isLoading = false;
          roomStatus = 'playing';
          startedGameLabel =
              gameLabels[response['gameType']?.toString() ?? selectedGame] ??
              selectedGame;
          statusMessage = '${startedGameLabel ?? "게임"} 시작됨';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inRoom = currentRoomCode != null && currentRoomCode!.isNotEmpty;
    final mySocketId = widget.socketService.socket?.id;
    final isHost = mySocketId != null && hostSocketId == mySocketId;
    final currentTimeOptions =
        turnTimeOptionsByGame[selectedGame] ?? const <int>[];

    return Scaffold(
      appBar: AppBar(title: const Text('게임 로비'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '닉네임: ${widget.nickname}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(statusMessage, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '내 역할: ${isHost ? "방장" : "참가자"}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!inRoom) ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _createRoom,
                    child: const Text('방 만들기'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: '방 코드 입력',
                    hintText: '예: ABC123',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _joinRoom,
                    child: const Text('방 참가하기'),
                  ),
                ),
              ] else ...[
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '대기방',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '방 코드: $currentRoomCode',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '참가자 목록',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(height: 8),
                        if (players.isEmpty)
                          const Text('아직 참가자가 없습니다.')
                        else
                          ...players.map((player) {
                            final nickname =
                                player['nickname']?.toString() ?? '이름 없음';
                            final playerIsHost =
                                player['socketId']?.toString() == hostSocketId;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.person, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nickname,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    playerIsHost ? '방장' : '참가자',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const SizedBox(height: 12),
                        const Text(
                          '게임 선택',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: gameLabels.entries.map((entry) {
                            final isSelected = selectedGame == entry.key;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: entry.key == 'beondegi' ? 0 : 8,
                                ),
                                child: ChoiceChip(
                                  label: SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      entry.value,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected:
                                      (!isHost || roomStatus == 'playing')
                                      ? null
                                      : (_) => _selectGame(entry.key),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (selectedGame == 'three_six_nine') ...[
                          const SizedBox(height: 14),
                          const Text(
                            '369 난이도',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: threeSixNineDifficultyLabels.entries.map((
                              entry,
                            ) {
                              final isSelected =
                                  selectedDifficulty == entry.key;
                              return ChoiceChip(
                                label: Text(entry.value),
                                selected: isSelected,
                                onSelected: (!isHost || roomStatus == 'playing')
                                    ? null
                                    : (_) => _updateThreeSixNineDifficulty(
                                        entry.key,
                                      ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 14),
                        const Text(
                          '턴 제한시간',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: currentTimeOptions.map((ms) {
                            final isSelected = selectedTurnTimeLimitMs == ms;
                            return ChoiceChip(
                              label: Text(_turnTimeLabel(ms)),
                              selected: isSelected,
                              onSelected: (!isHost || roomStatus == 'playing')
                                  ? null
                                  : (_) => _updateTurnTimeLimit(ms),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedTurnTimeLimitMs == null
                              ? '제한시간을 선택해주세요.'
                              : '현재 제한시간: ${_turnTimeLabel(selectedTurnTimeLimitMs!)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (selectedGame == 'three_six_nine') ...[
                          const SizedBox(height: 6),
                          Text(
                            '현재 난이도: ${threeSixNineDifficultyLabels[selectedDifficulty] ?? selectedDifficulty}',
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                (!isHost ||
                                    roomStatus == 'playing' ||
                                    players.length < 2 ||
                                    selectedTurnTimeLimitMs == null)
                                ? null
                                : _startGame,
                            child: Text(
                              roomStatus == 'playing' ? '게임 진행 중' : '게임 시작',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          players.length < 2
                              ? '게임 시작은 최소 2명부터 가능합니다.'
                              : selectedTurnTimeLimitMs == null
                              ? '게임을 시작하기 전에 턴 제한시간을 먼저 선택해주세요.'
                              : isHost
                              ? '방장이 게임과 제한시간을 선택하고 시작할 수 있습니다.'
                              : '방장이 게임을 시작할 때까지 기다려주세요.',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (startedGameLabel != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '현재 진행 상태: ${startedGameLabel!} 시작됨',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (isLoading) const Center(child: CircularProgressIndicator()),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('뒤로 가기'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class ThreeSixNineGameScreen extends StatefulWidget {
  final String nickname;
  final SocketService socketService;
  final String roomCode;
  final List<dynamic> players;
  final dynamic initialGameState;

  const ThreeSixNineGameScreen({
    super.key,
    required this.nickname,
    required this.socketService,
    required this.roomCode,
    required this.players,
    required this.initialGameState,
  });

  @override
  State<ThreeSixNineGameScreen> createState() => _ThreeSixNineGameScreenState();
}

class NunchiGameScreen extends StatefulWidget {
  final String nickname;
  final SocketService socketService;
  final String roomCode;
  final List<dynamic> players;
  final dynamic initialGameState;

  const NunchiGameScreen({
    super.key,
    required this.nickname,
    required this.socketService,
    required this.roomCode,
    required this.players,
    required this.initialGameState,
  });

  @override
  State<NunchiGameScreen> createState() => _NunchiGameScreenState();
}

class _ParticipantSeatBoard extends StatelessWidget {
  final List<dynamic> players;
  final String? currentTurnSocketId;
  final String? lastSubmittedSocketId;
  final List<dynamic>? aliveSocketIds;
  final bool showAliveState;

  const _ParticipantSeatBoard({
    required this.players,
    required this.currentTurnSocketId,
    required this.lastSubmittedSocketId,
    this.aliveSocketIds,
    this.showAliveState = false,
  });

  bool _isAlive(String? socketId) {
    if (!showAliveState || socketId == null) {
      return true;
    }
    return aliveSocketIds?.contains(socketId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(players.length, (index) {
          final player = players[index];
          final socketId = player['socketId']?.toString();
          final nickname = player['nickname']?.toString() ?? '이름 없음';
          final isCurrent =
              currentTurnSocketId != null && socketId == currentTurnSocketId;
          final isLast =
              lastSubmittedSocketId != null &&
              socketId == lastSubmittedSocketId;
          final isAlive = _isAlive(socketId);

          Color backgroundColor = Colors.white;
          Color borderColor = Colors.grey.shade300;

          if (isLast) {
            backgroundColor = Colors.amber.shade100;
            borderColor = Colors.orange.shade400;
          } else if (isCurrent) {
            backgroundColor = Colors.green.shade100;
            borderColor = Colors.green.shade400;
          } else if (!isAlive) {
            backgroundColor = Colors.grey.shade300;
            borderColor = Colors.grey.shade500;
          }

          String statusLabel = '${index + 1}번';
          if (isLast) {
            statusLabel = '방금 입력';
          } else if (isCurrent) {
            statusLabel = '현재 차례';
          } else if (showAliveState) {
            statusLabel = isAlive ? '생존' : '탈출/탈락';
          }

          return Container(
            width: 108,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _NunchiGameScreenState extends State<NunchiGameScreen> {
  dynamic gameState;
  String _typedNumber = '';
  String feedbackMessage = '눈치게임 준비 중입니다.';
  bool isSubmitting = false;
  Timer? _turnTimer;
  double _turnTimeProgress = 1.0;
  int _remainingTurnMs = 0;
  int _countdownRemainingMs = 0;
  bool _isGameOverDialogOpen = false;

  @override
  void initState() {
    super.initState();
    gameState = widget.initialGameState;
    _syncTurnTimer(gameState);

    widget.socketService.off('game:state');
    widget.socketService.off('game:over');
    widget.socketService.on('game:state', _handleGameState);
    widget.socketService.on('game:over', _handleGameOver);
  }

  @override
  void dispose() {
    widget.socketService.off('game:state');
    widget.socketService.off('game:over');
    _turnTimer?.cancel();
    super.dispose();
  }

  void _syncTurnTimer(dynamic nextGameState) {
    _turnTimer?.cancel();

    final phase = nextGameState?['phase']?.toString();
    final turnStartedAt = nextGameState?['turnStartedAt'] as int?;
    final turnDeadlineAt = nextGameState?['turnDeadlineAt'] as int?;
    final countdownEndsAt =
        nextGameState?['metadata']?['countdownEndsAt'] as int?;

    if (phase == 'waiting_start' && countdownEndsAt != null) {
      void updateCountdown() {
        final now = DateTime.now().millisecondsSinceEpoch;
        final remainingMs = (countdownEndsAt - now).clamp(0, 4000);

        if (!mounted) return;
        setState(() {
          _countdownRemainingMs = remainingMs;
          _turnTimeProgress = 0;
          _remainingTurnMs = 0;
        });
      }

      updateCountdown();
      _turnTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        updateCountdown();
      });
      return;
    }

    if (phase != 'playing' || turnStartedAt == null || turnDeadlineAt == null) {
      if (!mounted) return;
      setState(() {
        _countdownRemainingMs = 0;
        _turnTimeProgress = 0;
        _remainingTurnMs = 0;
      });
      return;
    }

    void updateTick() {
      final now = DateTime.now().millisecondsSinceEpoch;
      final totalMs = (turnDeadlineAt - turnStartedAt).clamp(1, 1 << 30);
      final remainingMs = (turnDeadlineAt - now).clamp(0, totalMs);
      final progress = remainingMs / totalMs;

      if (!mounted) return;
      setState(() {
        _remainingTurnMs = remainingMs;
        _countdownRemainingMs = 0;
        _turnTimeProgress = progress.clamp(0.0, 1.0);
      });
    }

    updateTick();
    _turnTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      updateTick();
    });
  }

  void _handleGameState(dynamic data) {
    if (!mounted) return;

    final previousPhase = gameState?['phase']?.toString();
    final nextPhase = data?['phase']?.toString() ?? 'waiting_start';

    if (previousPhase == 'waiting_start' && nextPhase == 'playing') {
      AudioService.playTurnStart();
    }

    _syncTurnTimer(data);
    setState(() {
      gameState = data;
      isSubmitting = false;
      _typedNumber = '';
      feedbackMessage =
          data?['metadata']?['lastActionMessage']?.toString() ??
          '상태가 업데이트되었습니다.';
    });
  }

  void _handleGameOver(dynamic data) {
    if (!mounted || _isGameOverDialogOpen) return;

    AudioService.playGameOver();
    _isGameOverDialogOpen = true;

    setState(() {
      _turnTimer?.cancel();
      gameState = data?['gameState'];
      feedbackMessage = data?['message']?.toString() ?? '게임이 종료되었습니다.';
      isSubmitting = false;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('게임 종료'),
          content: Text(feedbackMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('로비로 돌아가기'),
            ),
          ],
        );
      },
    ).then((_) {
      _isGameOverDialogOpen = false;
    });
  }

  String _countdownLabel() {
    if (_countdownRemainingMs > 3000) return '3';
    if (_countdownRemainingMs > 2000) return '2';
    if (_countdownRemainingMs > 1000) return '1';
    return '시작';
  }

  String _formatRemainingTurnTime(int ms) {
    if (ms <= 0) return '0.0초';
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(1)}초';
  }

  String _nicknameFromSocketId(String? socketId) {
    if (socketId == null) return '알 수 없음';

    for (final player in widget.players) {
      if (player['socketId']?.toString() == socketId) {
        return player['nickname']?.toString() ?? '알 수 없음';
      }
    }
    return '알 수 없음';
  }

  Widget _buildLastActionHighlightPanel({
    required String phase,
    required String lastSubmittedDisplayText,
    required String? lastSubmittedSocketId,
  }) {
    final hasLastInput =
        phase != 'waiting_start' &&
        lastSubmittedSocketId != null &&
        lastSubmittedDisplayText != '-';

    final nickname = _nicknameFromSocketId(lastSubmittedSocketId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: hasLastInput ? Colors.amber.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasLastInput ? Colors.orange.shade300 : Colors.grey.shade300,
          width: hasLastInput ? 1.6 : 1.0,
        ),
        boxShadow: hasLastInput
            ? [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: hasLastInput
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '방금 입력',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$nickname  →  $lastSubmittedDisplayText',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : const Text(
              '아직 입력된 숫자가 없습니다.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
    );
  }

  Future<void> _submitTypedNumber(int value) async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    widget.socketService.submitGameInput(
      roomCode: widget.roomCode,
      moveType: 'number',
      value: value,
      callback: (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;
        if (!ok) {
          setState(() {
            isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response?['message']?.toString() ?? '숫자 제출에 실패했습니다.',
              ),
            ),
          );
        }
      },
    );
  }

  int _expectedNumberDigitLength() {
    final expectedNumber = gameState?['metadata']?['expectedNumber'] as int?;
    if (expectedNumber == null) {
      return 1;
    }
    return expectedNumber.toString().length;
  }

  void _appendDigit(String digit) {
    if (isSubmitting) return;
    if (!RegExp(r'^\d$').hasMatch(digit)) return;

    final expectedDigits = _expectedNumberDigitLength();
    final nextTyped = _typedNumber == '0' ? digit : '$_typedNumber$digit';

    setState(() {
      _typedNumber = nextTyped;
    });

    if (nextTyped.length == expectedDigits) {
      final value = int.tryParse(nextTyped);
      if (value != null) {
        _submitTypedNumber(value);
      }
    }
  }

  Widget _buildNumberPadButton({
    required String label,
    required VoidCallback? onTap,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildNumberPadKey(String digit, bool enabled) {
    return _buildNumberPadButton(
      label: digit,
      onTap: enabled ? () => _appendDigit(digit) : null,
    );
  }

  Widget _buildBottomInputPanel({
    required bool canUseNumberPad,
    required bool isCountdownLocked,
    required String typedNumberText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isCountdownLocked ? 0.55 : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCountdownLocked
                    ? Colors.grey.shade200
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCountdownLocked
                      ? Colors.grey.shade400
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 48,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isCountdownLocked
                          ? Colors.grey.shade50
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      isCountdownLocked ? '시작 준비 중' : typedNumberText,
                      style: TextStyle(
                        fontSize: _typedNumber.length >= 6 ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: isCountdownLocked
                            ? Colors.grey.shade500
                            : _typedNumber.isEmpty
                            ? Colors.grey.shade500
                            : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 130,
                    child: GridView.count(
                      crossAxisCount: 5,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.65,
                      children: [
                        _buildNumberPadKey('1', canUseNumberPad),
                        _buildNumberPadKey('2', canUseNumberPad),
                        _buildNumberPadKey('3', canUseNumberPad),
                        _buildNumberPadKey('4', canUseNumberPad),
                        _buildNumberPadKey('5', canUseNumberPad),
                        _buildNumberPadKey('6', canUseNumberPad),
                        _buildNumberPadKey('7', canUseNumberPad),
                        _buildNumberPadKey('8', canUseNumberPad),
                        _buildNumberPadKey('9', canUseNumberPad),
                        _buildNumberPadKey('0', canUseNumberPad),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mySocketId = widget.socketService.socket?.id;
    final phase = gameState?['phase']?.toString() ?? 'waiting_start';
    final expectedNumber =
        gameState?['metadata']?['expectedNumber'] as int? ?? 1;
    final targetNumber = gameState?['metadata']?['targetNumber'] as int? ?? 1;
    final lastSubmittedDisplayText =
        gameState?['metadata']?['lastSubmittedDisplayText']?.toString() ?? '-';
    final lastSubmittedSocketId =
        gameState?['metadata']?['lastSubmittedSocketId']?.toString();
    final aliveSocketIds =
        (gameState?['metadata']?['aliveSocketIds'] as List?) ?? const [];
    final pendingSubmitterSocketIds =
        (gameState?['metadata']?['pendingSubmitterSocketIds'] as List?) ??
        const [];
    final submittedNumbers =
        (gameState?['metadata']?['submittedNumbers'] as List?) ?? const [];

    final isAlive = mySocketId != null && aliveSocketIds.contains(mySocketId);
    final isPending =
        mySocketId != null && pendingSubmitterSocketIds.contains(mySocketId);
    final isCountdownLocked = phase == 'waiting_start';
    final canUseNumberPad =
        phase == 'playing' && isAlive && !isPending && !isSubmitting;
    final typedNumberText = _typedNumber.isEmpty ? '입력 없음' : _typedNumber;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('눈치게임'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase == 'waiting_start'
                          ? '곧 시작됩니다'
                          : '현재 숫자: $expectedNumber / 목표 숫자: $targetNumber',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phase == 'waiting_start'
                          ? '카운트다운 후 아무나 먼저 1을 누르세요.'
                          : '숫자를 잘못 누르면 즉시 실패합니다.',
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: phase == 'playing' ? _turnTimeProgress : 0,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      phase == 'waiting_start'
                          ? '카운트다운: ${_countdownLabel()}'
                          : '남은 시간: ${_formatRemainingTurnTime(_remainingTurnMs)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '직전 숫자: $lastSubmittedDisplayText',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '성공 숫자 기록: ${submittedNumbers.isEmpty ? "-" : submittedNumbers.join(", ")}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      feedbackMessage,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildLastActionHighlightPanel(
                phase: phase,
                lastSubmittedDisplayText: lastSubmittedDisplayText,
                lastSubmittedSocketId: lastSubmittedSocketId,
              ),
              const SizedBox(height: 10),
              _ParticipantSeatBoard(
                players: widget.players,
                currentTurnSocketId: null,
                lastSubmittedSocketId: lastSubmittedSocketId,
                aliveSocketIds: aliveSocketIds,
                showAliveState: true,
              ),
              const SizedBox(height: 10),
              Flexible(
                child: _buildBottomInputPanel(
                  canUseNumberPad: canUseNumberPad,
                  isCountdownLocked: isCountdownLocked,
                  typedNumberText: typedNumberText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreeSixNineGameScreenState extends State<ThreeSixNineGameScreen> {
  dynamic gameState;
  String _typedNumber = '';
  int _pendingClapCount = 0;
  String statusMessage = '369 게임 준비 중입니다.';
  String feedbackMessage = '시작 구호가 끝나면 입력이 시작됩니다.';
  bool isSubmitting = false;
  String? _lastTurnSocketId;
  Timer? _turnTimer;
  double _turnTimeProgress = 1.0;
  int _remainingTurnMs = 0;
  bool _isGameOverDialogOpen = false;
  int _countdownRemainingMs = 0;

  @override
  void initState() {
    super.initState();
    gameState = widget.initialGameState;
    _lastTurnSocketId = gameState?['currentTurnSocketId']?.toString();

    _syncTurnTimer(gameState);
    final initialPhase = gameState?['phase']?.toString() ?? 'waiting_start';
    final mySocketId = widget.socketService.socket?.id;
    final isMyInitialTurn =
        mySocketId != null &&
        _lastTurnSocketId != null &&
        mySocketId == _lastTurnSocketId;

    if (initialPhase == 'waiting_start') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          feedbackMessage = '3, 2, 1, 시작 카운트다운 후 입력이 시작됩니다.';
        });
      });
    } else if (isMyInitialTurn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AudioService.playTurnStart();
        if (!mounted) return;
        setState(() {
          feedbackMessage = '지금 당신 차례입니다. 입력해주세요.';
        });
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          feedbackMessage = '상대방 차례입니다. 화면을 보고 기다려주세요.';
        });
      });
    }

    widget.socketService.off('game:state');
    widget.socketService.off('game:over');
    widget.socketService.on('game:state', _handleGameState);
    widget.socketService.on('game:over', _handleGameOver);
  }

  @override
  void dispose() {
    widget.socketService.off('game:state');
    widget.socketService.off('game:over');
    _turnTimer?.cancel();
    super.dispose();
  }

  void _syncTurnTimer(dynamic nextGameState) {
    _turnTimer?.cancel();

    final phase = nextGameState?['phase']?.toString();
    final turnStartedAt = nextGameState?['turnStartedAt'] as int?;
    final turnDeadlineAt = nextGameState?['turnDeadlineAt'] as int?;
    final countdownEndsAt =
        nextGameState?['metadata']?['countdownEndsAt'] as int?;

    if (phase == 'waiting_start' && countdownEndsAt != null) {
      void updateCountdown() {
        final now = DateTime.now().millisecondsSinceEpoch;
        final remainingMs = (countdownEndsAt - now).clamp(0, 4000);

        if (!mounted) return;
        setState(() {
          _countdownRemainingMs = remainingMs;
          _turnTimeProgress = 0;
          _remainingTurnMs = 0;
        });
      }

      updateCountdown();
      _turnTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        updateCountdown();
      });
      return;
    }

    if (phase != 'playing' || turnStartedAt == null || turnDeadlineAt == null) {
      if (!mounted) return;
      setState(() {
        _countdownRemainingMs = 0;
        _turnTimeProgress = 0;
        _remainingTurnMs = 0;
      });
      return;
    }

    void updateTick() {
      final now = DateTime.now().millisecondsSinceEpoch;
      final totalMs = (turnDeadlineAt - turnStartedAt).clamp(1, 1 << 30);
      final remainingMs = (turnDeadlineAt - now).clamp(0, totalMs);
      final progress = remainingMs / totalMs;

      if (!mounted) return;
      setState(() {
        _remainingTurnMs = remainingMs;
        _countdownRemainingMs = 0;
        _turnTimeProgress = progress.clamp(0.0, 1.0);
      });
    }

    updateTick();
    _turnTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      updateTick();
    });
  }

  String _formatRemainingTurnTime(int ms) {
    if (ms <= 0) return '0.0초';
    final seconds = ms / 1000;
    return '${seconds.toStringAsFixed(1)}초';
  }

  Color _turnBarColor() {
    if (_turnTimeProgress <= 0.2) {
      return Colors.red;
    }
    if (_turnTimeProgress <= 0.5) {
      return Colors.orange;
    }
    return Colors.green;
  }

  String _turnTimerLabel(bool isMyTurn, String phase) {
    if (phase == 'waiting_start') {
      return '시작 준비 중';
    }

    if (phase != 'playing') {
      return '게임 종료';
    }

    if (_remainingTurnMs <= 0) {
      return isMyTurn ? '입력 시간 종료' : '상대 입력 시간 종료';
    }

    return isMyTurn
        ? '내 남은 시간: ${_formatRemainingTurnTime(_remainingTurnMs)}'
        : '상대 남은 시간: ${_formatRemainingTurnTime(_remainingTurnMs)}';
  }

  String _countdownLabel() {
    if (_countdownRemainingMs > 3000) return '3';
    if (_countdownRemainingMs > 2000) return '2';
    if (_countdownRemainingMs > 1000) return '1';
    return '시작';
  }

  String _topRightDisplayText(String phase, String lastSubmittedDisplayText) {
    if (phase == 'waiting_start') {
      return _countdownLabel();
    }
    return lastSubmittedDisplayText;
  }

  Color _topRightDisplayColor(String phase) {
    if (phase == 'waiting_start') {
      final countdownText = _countdownLabel();
      if (countdownText == '시작') {
        return Colors.green;
      }
      return Colors.red;
    }
    return Colors.black;
  }

  Widget _buildTopGamePanel({
    required bool isMyTurn,
    required String phase,
    required String lastSubmittedDisplayText,
    required dynamic currentPlayerNickname,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      '현재 턴: ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${currentPlayerNickname ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  phase == 'waiting_start'
                      ? '곧 게임이 시작됩니다.'
                      : isMyTurn
                      ? '지금은 당신의 턴입니다.'
                      : '상대 턴입니다.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: phase == 'waiting_start'
                        ? Colors.blue
                        : (isMyTurn ? Colors.green : Colors.orange),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _turnTimerLabel(isMyTurn, phase),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _turnBarColor(),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _turnTimeProgress,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(_turnBarColor()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _topRightDisplayText(phase, lastSubmittedDisplayText),
                style: TextStyle(
                  color: _topRightDisplayColor(phase),
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _nextStarterMessage() {
    final loserSocketId = gameState?['metadata']?['loserSocketId']?.toString();
    if (loserSocketId == null || loserSocketId.isEmpty) {
      return '다음 게임 시작 플레이어를 확인할 수 없습니다.';
    }

    final nickname = _nicknameBySocketId(loserSocketId);
    return '다음 게임은 $nickname님 부터 시작입니다.';
  }

  Widget _buildBottomInputPanel({
    required bool canSubmit,
    required bool canSubmitNumber,
    required bool isCountdownLocked,
    required String typedNumberText,
    required bool canUseNumberPad,
    required bool canUseClapButton,
    required String clapButtonLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isCountdownLocked ? 0.55 : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCountdownLocked
                    ? Colors.grey.shade200
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCountdownLocked
                      ? Colors.grey.shade400
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 48,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isCountdownLocked
                          ? Colors.grey.shade50
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      isCountdownLocked ? '시작 준비 중' : typedNumberText,
                      style: TextStyle(
                        fontSize: _typedNumber.length >= 6 ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: isCountdownLocked
                            ? Colors.grey.shade500
                            : _typedNumber.isEmpty
                            ? Colors.grey.shade500
                            : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: GridView.count(
                          crossAxisCount: 5,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.65,
                          children: [
                            _buildNumberPadKey('1', canUseNumberPad),
                            _buildNumberPadKey('2', canUseNumberPad),
                            _buildNumberPadKey('3', canUseNumberPad),
                            _buildNumberPadKey('4', canUseNumberPad),
                            _buildNumberPadKey('5', canUseNumberPad),
                            _buildNumberPadKey('6', canUseNumberPad),
                            _buildNumberPadKey('7', canUseNumberPad),
                            _buildNumberPadKey('8', canUseNumberPad),
                            _buildNumberPadKey('9', canUseNumberPad),
                            _buildNumberPadKey('0', canUseNumberPad),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: canUseClapButton
                                    ? _handleClapTap
                                    : null,
                                child: Text(clapButtonLabel),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: canSubmit ? _submitManse : null,
                                child: const Text('만세 입력 🙌'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberPadButton(
                              label: '←',
                              onTap: canUseNumberPad ? _backspaceDigit : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNumberPadButton(
                              label: '전체삭제',
                              onTap: canUseNumberPad ? _clearTypedNumber : null,
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleGameState(dynamic data) {
    if (!mounted) return;

    final mySocketId = widget.socketService.socket?.id;
    final nextTurnSocketId = data?['currentTurnSocketId']?.toString();
    final wasMyTurn =
        mySocketId != null &&
        _lastTurnSocketId != null &&
        _lastTurnSocketId == mySocketId;
    final previousPhase = gameState?['phase']?.toString();
    final nextPhase = data?['phase']?.toString() ?? 'waiting_start';
    final isMyTurnNow =
        mySocketId != null &&
        nextTurnSocketId != null &&
        nextTurnSocketId == mySocketId;

    if (previousPhase == 'waiting_start' &&
        nextPhase == 'playing' &&
        isMyTurnNow) {
      AudioService.playTurnStart();
    } else if (!wasMyTurn && isMyTurnNow && nextPhase == 'playing') {
      AudioService.playTurnStart();
    }

    _syncTurnTimer(data);
    setState(() {
      final lastActionMessage =
          data?['metadata']?['lastActionMessage']?.toString() ??
          '상태가 업데이트되었습니다.';

      gameState = data;
      statusMessage = lastActionMessage;
      if (nextPhase == 'waiting_start') {
        feedbackMessage = '카운트다운이 끝나면 첫 번째 플레이어부터 시작합니다.';
      } else if (previousPhase == 'waiting_start' && nextPhase == 'playing') {
        if (isMyTurnNow) {
          feedbackMessage = '시작! 지금 당신 차례입니다.';
        } else {
          feedbackMessage = '시작! 첫 번째 플레이어의 입력을 기다려주세요.';
        }
      } else if (isMyTurnNow) {
        feedbackMessage = '지금 당신 차례입니다. 서둘러 입력해주세요.';
      } else if (wasMyTurn && !isMyTurnNow) {
        feedbackMessage = '입력이 전달되었습니다. 다음 플레이어를 기다려주세요.';
      } else {
        feedbackMessage = lastActionMessage;
      }

      _pendingClapCount = 0;
      isSubmitting = false;
    });

    _lastTurnSocketId = nextTurnSocketId;
  }

  void _handleGameOver(dynamic data) {
    if (!mounted) return;

    if (_isGameOverDialogOpen) {
      return;
    }

    AudioService.playGameOver();

    setState(() {
      _turnTimer?.cancel();
      gameState = data?['gameState'];
      _pendingClapCount = 0;
      statusMessage = data?['message']?.toString() ?? '게임이 종료되었습니다.';
      feedbackMessage = statusMessage;
      isSubmitting = false;
    });

    _syncTurnTimer(data?['gameState']);
    _isGameOverDialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final nextStarterMessage = _nextStarterMessage();

        return AlertDialog(
          title: const Text('게임 종료'),
          content: Text('$statusMessage\n\n$nextStarterMessage'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('로비로 돌아가기'),
            ),
          ],
        );
      },
    ).then((_) {
      _isGameOverDialogOpen = false;
    });
  }

  String _nicknameBySocketId(String? socketId) {
    if (socketId == null) return '알 수 없음';

    for (final player in widget.players) {
      if (player['socketId']?.toString() == socketId) {
        return player['nickname']?.toString() ?? '알 수 없음';
      }
    }
    return '알 수 없음';
  }

  Future<void> _submitGameInput({
    required String moveType,
    int? value,
    String? text,
    String inputMode = 'touch',
    String? recognizedText,
    required String failureMessage,
    VoidCallback? onSuccess,
  }) async {
    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    widget.socketService.submitGameInput(
      roomCode: widget.roomCode,
      moveType: moveType,
      value: value,
      text: text,
      inputMode: inputMode,
      recognizedText: recognizedText,
      callback: (response) {
        if (!mounted) return;

        final ok = response != null && response['ok'] == true;

        if (!ok) {
          setState(() {
            isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response?['message']?.toString() ?? failureMessage),
            ),
          );
          return;
        }

        onSuccess?.call();
      },
    );
  }

  Future<void> _submitParsedNumber(int value) async {
    await _submitGameInput(
      moveType: 'number',
      value: value,
      failureMessage: '숫자 제출에 실패했습니다.',
      onSuccess: () {
        _typedNumber = '';
        setState(() {
          feedbackMessage = '숫자 입력 성공!';
        });
        AudioService.playThreeSixNineCue(value);
      },
    );
  }

  int _expectedNumberDigitLength() {
    final expectedNumber = gameState?['metadata']?['expectedNumber'] as int?;
    if (expectedNumber == null) {
      return 1;
    }
    return expectedNumber.toString().length;
  }

  void _appendDigit(String digit) {
    if (isSubmitting) return;
    if (!RegExp(r'^\d$').hasMatch(digit)) return;

    final expectedDigits = _expectedNumberDigitLength();
    final nextTyped = _typedNumber == '0' ? digit : '$_typedNumber$digit';

    setState(() {
      _typedNumber = nextTyped;
    });

    if (nextTyped.length == expectedDigits) {
      final value = int.tryParse(nextTyped);
      if (value != null) {
        _submitParsedNumber(value);
      }
    }
  }

  void _backspaceDigit() {
    if (isSubmitting || _typedNumber.isEmpty) return;

    setState(() {
      _typedNumber = _typedNumber.substring(0, _typedNumber.length - 1);
    });
  }

  void _clearTypedNumber() {
    if (isSubmitting || _typedNumber.isEmpty) return;

    setState(() {
      _typedNumber = '';
    });
  }

  int _expectedClapCount() {
    final expectedDisplayText =
        gameState?['metadata']?['expectedDisplayText']?.toString() ?? '';
    final clapCount = expectedDisplayText
        .split('')
        .where((char) => char == '👏')
        .length;
    return clapCount > 0 ? clapCount : 1;
  }

  Widget _buildNumberPadButton({
    required String label,
    required VoidCallback? onTap,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildNumberPadKey(String digit, bool enabled) {
    return _buildNumberPadButton(
      label: digit,
      onTap: enabled ? () => _appendDigit(digit) : null,
    );
  }

  Future<void> _submitClapCount(int clapCount) async {
    final clapText = '👏' * clapCount;

    await _submitGameInput(
      moveType: 'clap',
      text: clapText,
      failureMessage: '박수 제출에 실패했습니다.',
      onSuccess: () {
        setState(() {
          feedbackMessage = '박수 $clapCount번 입력 성공!';
        });
        AudioService.playClap();
      },
    );
  }

  Future<void> _handleClapTap() async {
    if (isSubmitting) return;
    final expectedClapCount = _expectedClapCount();
    final nextClapCount = _pendingClapCount + 1;

    if (nextClapCount < expectedClapCount) {
      AudioService.playClap();
      setState(() {
        _pendingClapCount = nextClapCount;
        feedbackMessage = '박수 $nextClapCount/$expectedClapCount 입력 중...';
      });
      return;
    }

    await _submitClapCount(expectedClapCount);
  }

  Future<void> _submitManse() async {
    await _submitGameInput(
      moveType: 'manse',
      text: '🙌',
      failureMessage: '만세 제출에 실패했습니다.',
      onSuccess: () {
        setState(() {
          feedbackMessage = '만세 입력 성공!';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mySocketId = widget.socketService.socket?.id;
    final typedNumberText = _typedNumber.isEmpty ? '입력 없음' : _typedNumber;

    final currentTurnSocketId = gameState?['currentTurnSocketId']?.toString();
    final lastSubmittedSocketId =
        gameState?['metadata']?['lastSubmittedSocketId']?.toString();
    final isMyTurn = mySocketId != null && mySocketId == currentTurnSocketId;
    final lastSubmittedDisplayText =
        gameState?['metadata']?['lastSubmittedDisplayText']?.toString() ?? '-';
    final phase = gameState?['phase']?.toString() ?? 'playing';
    final isCountdownLocked = phase == 'waiting_start';
    final canSubmit = isMyTurn && phase == 'playing' && !isSubmitting;
    final canSubmitNumber = canSubmit && _typedNumber.isNotEmpty;
    final canUseNumberPad = canSubmit;
    final canUseClapButton = canSubmit;
    const clapButtonLabel = '박수 입력 👏';
    final currentPlayerNickname = _nicknameBySocketId(currentTurnSocketId);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('369 게임'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildTopGamePanel(
                isMyTurn: isMyTurn,
                phase: phase,
                lastSubmittedDisplayText: lastSubmittedDisplayText,
                currentPlayerNickname: currentPlayerNickname,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  feedbackMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              _ParticipantSeatBoard(
                players: widget.players,
                currentTurnSocketId: currentTurnSocketId,
                lastSubmittedSocketId: lastSubmittedSocketId,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _buildBottomInputPanel(
                  canSubmit: canSubmit,
                  canSubmitNumber: canSubmitNumber,
                  isCountdownLocked: isCountdownLocked,
                  typedNumberText: typedNumberText,
                  canUseNumberPad: canUseNumberPad,
                  canUseClapButton: canUseClapButton,
                  clapButtonLabel: clapButtonLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
