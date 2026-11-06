import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/client.dart';
import '../api/socket.dart';
import '../types.dart';

const _tokenKey = 'guest-session';

enum SessionStatus { loading, offline, guestNeeded, ready }

class Session extends ChangeNotifier {
  Session() {
    load();
  }

  static const storage = FlutterSecureStorage();

  SessionStatus status = SessionStatus.loading;
  Guest? _guest;

  /// The signed-in guest, for screens that only exist once there is one.
  Guest get guest => _guest!;
  Guest? get guestOrNull => _guest;

  void _set(SessionStatus next) {
    status = next;
    notifyListeners();
  }

  Future<void> load() async {
    _set(SessionStatus.loading);
    final String? token;
    try {
      token = await storage.read(key: _tokenKey);
    } catch (_) {
      // A key the phone can no longer read, after a restore: a new guest is the way out.
      await storage.deleteAll();
      return _set(SessionStatus.guestNeeded);
    }
    if (token == null) return _set(SessionStatus.guestNeeded);
    api.sessionToken = token;
    try {
      _guest = await api.me();
      liveSocket.connect(token);
      _set(SessionStatus.ready);
    } on ApiError catch (err) {
      if (err.status == 401) {
        await storage.delete(key: _tokenKey);
        api.sessionToken = null;
        _set(SessionStatus.guestNeeded);
      } else {
        // The identity is still good: this is only the network.
        _set(SessionStatus.offline);
      }
    }
  }

  Future<void> start(String name, String avatar) async {
    final created = await api.createGuest(name, avatar);
    await storage.write(key: _tokenKey, value: created.token);
    api.sessionToken = created.token;
    _guest = created.guest;
    liveSocket.connect(created.token);
    _set(SessionStatus.ready);
  }

  void setGuest(Guest guest) {
    _guest = guest;
    notifyListeners();
  }

  Future<void> refresh() async => setGuest(await api.me());

  Future<void> forget() async {
    await storage.delete(key: _tokenKey);
    api.sessionToken = null;
    liveSocket.disconnect();
    _guest = null;
    _set(SessionStatus.guestNeeded);
  }
}

class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child}) : super(notifier: session);

  /// Rebuilds the caller when the guest changes.
  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// For a handler: no rebuilds.
  static Session read(BuildContext context) => context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
