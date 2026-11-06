import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';

typedef SocketHandler = void Function(dynamic payload);

/// The backend's own live connection, for what happens outside any room: the 1v1 line, room list updates and inbox
/// notices. Everything inside a room goes over VoltKit instead.
class LiveSocket {
  io.Socket? _socket;
  final _handlers = <String, Set<SocketHandler>>{};

  void connect(String token) {
    _socket?.dispose();
    final socket = io.io(
      apiUrl,
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).setReconnectionDelayMax(8000).enableForceNew().disableAutoConnect().build(),
    );
    _socket = socket;
    for (final event in _handlers.keys) {
      _bind(socket, event);
    }
    socket.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void _bind(io.Socket socket, String event) {
    socket.on(event, (payload) {
      for (final handler in [...?_handlers[event]]) {
        handler(payload);
      }
    });
  }

  /// Listens until the returned function is called, across reconnects and a new session.
  void Function() on(String event, SocketHandler handler) {
    final first = !_handlers.containsKey(event);
    (_handlers[event] ??= {}).add(handler);
    final socket = _socket;
    if (first && socket != null) _bind(socket, event);
    return () => _handlers[event]?.remove(handler);
  }

  void emit(String event, [Object? data]) => _socket?.emit(event, data);
}

final liveSocket = LiveSocket();
