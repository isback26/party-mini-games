import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as io;

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
      'http://localhost:3000',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
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
      log('⚠️ Connect error: $data');
      onConnectError?.call(data);
    });

    _socket!.onError((data) {
      log('⚠️ Socket error: $data');
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

  void dispose() {
    disconnect();
  }
}
