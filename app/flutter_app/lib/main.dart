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
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                '모임에서 바로 즐기는 실시간 미니게임',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                connectionText,
                style: TextStyle(
                  fontSize: 14,
                  color: socketService.isConnected ? Colors.green : Colors.red,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  String? currentRoomCode;
  List<dynamic> players = [];
  String? hostSocketId;
  String selectedGame = 'three_six_nine';
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

    setState(() {
      currentRoomCode = roomCode;
      players = nextPlayers;
      hostSocketId = nextHostSocketId;
      selectedGame = nextSelectedGame;
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
      {'nickname': widget.nickname, 'turnTimeLimitMs': selectedTurnTimeLimitMs},
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
      {'roomCode': currentRoomCode, 'turnTimeLimitMs': turnTimeLimitMs},
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
    final currentGameLabel = gameLabels[selectedGame] ?? selectedGame;
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

class _ThreeSixNineGameScreenState extends State<ThreeSixNineGameScreen> {
  dynamic gameState;
  String _typedNumber = '';
  String statusMessage = '369 게임이 시작되었습니다.';
  String feedbackMessage = '게임이 시작되었습니다. 내 차례를 기다려주세요.';
  bool isSubmitting = false;
  String? _lastTurnSocketId;
  Timer? _turnTimer;
  double _turnTimeProgress = 1.0;
  int _remainingTurnMs = 0;
  bool _isGameOverDialogOpen = false;

  @override
  void initState() {
    super.initState();
    gameState = widget.initialGameState;
    _lastTurnSocketId = gameState?['currentTurnSocketId']?.toString();

    _syncTurnTimer(gameState);
    final mySocketId = widget.socketService.socket?.id;
    final isMyInitialTurn =
        mySocketId != null &&
        _lastTurnSocketId != null &&
        mySocketId == _lastTurnSocketId;

    if (isMyInitialTurn) {
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

    if (phase != 'playing' || turnStartedAt == null || turnDeadlineAt == null) {
      if (!mounted) return;
      setState(() {
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

  Widget _buildTopGamePanel({
    required bool isMyTurn,
    required String phase,
    required String expectedDisplayText,
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
                  isMyTurn ? '지금은 당신의 턴입니다.' : '상대 턴입니다.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isMyTurn ? Colors.green : Colors.orange,
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
                expectedDisplayText,
                style: const TextStyle(
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

  Widget _buildBottomInputPanel({
    required bool canSubmit,
    required bool canSubmitNumber,
    required String typedNumberText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 48,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Text(
                    typedNumberText,
                    style: TextStyle(
                      fontSize: _typedNumber.length >= 6 ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: _typedNumber.isEmpty
                          ? Colors.grey.shade500
                          : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 5,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.65,
                          children: [
                            _buildNumberPadKey('1', canSubmit),
                            _buildNumberPadKey('2', canSubmit),
                            _buildNumberPadKey('3', canSubmit),
                            _buildNumberPadKey('4', canSubmit),
                            _buildNumberPadKey('5', canSubmit),
                            _buildNumberPadKey('6', canSubmit),
                            _buildNumberPadKey('7', canSubmit),
                            _buildNumberPadKey('8', canSubmit),
                            _buildNumberPadKey('9', canSubmit),
                            _buildNumberPadKey('0', canSubmit),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberPadButton(
                              label: '←',
                              onTap: canSubmit ? _backspaceDigit : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNumberPadButton(
                              label: '전체삭제',
                              onTap: canSubmit ? _clearTypedNumber : null,
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: canSubmitNumber ? _submitNumber : null,
            child: const Text('숫자 제출'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: canSubmit ? _submitClap : null,
            child: const Text('박수 입력 👏'),
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
    final isMyTurnNow =
        mySocketId != null &&
        nextTurnSocketId != null &&
        nextTurnSocketId == mySocketId;

    if (!wasMyTurn && isMyTurnNow) {
      AudioService.playTurnStart();
    }

    _syncTurnTimer(data);
    setState(() {
      final lastActionMessage =
          data?['metadata']?['lastActionMessage']?.toString() ??
          '상태가 업데이트되었습니다.';

      gameState = data;
      statusMessage = lastActionMessage;
      if (isMyTurnNow) {
        feedbackMessage = '지금 당신 차례입니다. 서둘러 입력해주세요.';
      } else if (wasMyTurn && !isMyTurnNow) {
        feedbackMessage = '입력이 전달되었습니다. 다음 플레이어를 기다려주세요.';
      } else {
        feedbackMessage = lastActionMessage;
      }

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
      statusMessage = data?['message']?.toString() ?? '게임이 종료되었습니다.';
      feedbackMessage = '게임 종료! 결과를 확인해주세요.';
      isSubmitting = false;
    });

    _syncTurnTimer(data?['gameState']);
    _isGameOverDialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('게임 종료'),
          content: Text(statusMessage),
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

  void _appendDigit(String digit) {
    if (isSubmitting) return;
    if (!RegExp(r'^\d$').hasMatch(digit)) return;

    setState(() {
      if (_typedNumber == '0') {
        _typedNumber = digit;
      } else {
        _typedNumber += digit;
      }
    });
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

  Future<void> _submitNumber() async {
    final value = int.tryParse(_typedNumber.trim());

    if (value == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('숫자를 정확히 입력해주세요.')));
      return;
    }

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

  Future<void> _submitClap() async {
    await _submitGameInput(
      moveType: 'clap',
      text: '👏',
      failureMessage: '박수 제출에 실패했습니다.',
      onSuccess: () {
        setState(() {
          feedbackMessage = '짝! 박수 입력 성공!';
        });
        AudioService.playClap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mySocketId = widget.socketService.socket?.id;
    final typedNumberText = _typedNumber.isEmpty ? '입력 없음' : _typedNumber;

    final currentTurnSocketId = gameState?['currentTurnSocketId']?.toString();
    final isMyTurn = mySocketId != null && mySocketId == currentTurnSocketId;
    final expectedDisplayText =
        gameState?['metadata']?['expectedDisplayText']?.toString() ?? '-';
    final phase = gameState?['phase']?.toString() ?? 'playing';
    final canSubmit = isMyTurn && phase == 'playing' && !isSubmitting;
    final canSubmitNumber = canSubmit && _typedNumber.isNotEmpty;
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
                expectedDisplayText: expectedDisplayText,
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
              Expanded(
                child: _buildBottomInputPanel(
                  canSubmit: canSubmit,
                  canSubmitNumber: canSubmitNumber,
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
