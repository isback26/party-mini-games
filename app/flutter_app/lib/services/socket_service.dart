import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as io;

typedef SocketAckCallback = void Function(dynamic response);

class SocketService {
  io.Socket? _socket;

  io.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  void connect({
    Function()? onConnected,
    Function()? onDisconnected,
    Function(dynamic error)? onConnectError,
  }) {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      'http://192.168.45.110:3000',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setTimeout(10000)
          .build(),
    );

    _socket!.onConnect((_) {
      log('✅ Socket connected: ${_socket!.id}');
      onConnected?.call();
    });

    _socket!.onDisconnect((_) {
      log('❌ Socket disconnected');
      onDisconnected?.call();
    });

    _socket!.onConnectError((data) {
      log('⚠️ Connect error: ${data.toString()}');
      onConnectError?.call(data);
    });

    _socket!.onError((data) {
      log('⚠️ Socket error: ${data.toString()}');
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void emitWithAck(
    String event,
    dynamic data,
    Function(dynamic response) callback,
  ) {
    _socket?.emitWithAck(event, data, ack: callback);
  }

  void submitGameInput({
    required String roomCode,
    required String moveType,
    int? value,
    String? text,
    String inputMode = 'touch',
    String? recognizedText,
    required SocketAckCallback callback,
  }) {
    final payload = <String, dynamic>{
      'roomCode': roomCode.trim().toUpperCase(),
      'moveType': moveType,
      'inputMode': inputMode,
    };

    if (value != null) payload['value'] = value;
    if (text != null && text.trim().isNotEmpty) payload['text'] = text.trim();
    if (recognizedText != null && recognizedText.trim().isNotEmpty) {
      payload['recognizedText'] = recognizedText.trim();
    }

    emitWithAck('game:submit', payload, callback);
  }

  void dispose() {
    disconnect();
  }
}
