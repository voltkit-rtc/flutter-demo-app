import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../types.dart';

class ApiError implements Exception {
  const ApiError(this.message, this.status, this.code);

  final String message;
  final int status;
  final String code;

  @override
  String toString() => 'ApiError($code): $message';
}

/// The backend's REST API, exactly as the React Native demo calls it.
class Api {
  final http.Client _http = http.Client();
  String? _sessionToken;

  // ignore: avoid_setters_without_getters
  set sessionToken(String? token) => _sessionToken = token;

  Future<dynamic> _request(String method, String path, [Object? body]) async {
    final uri = Uri.parse('$apiUrl/v1$path');
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (_sessionToken != null) 'Authorization': 'Bearer $_sessionToken',
    };
    final http.Response res;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      res = await http.Response.fromStream(await _http.send(request).timeout(const Duration(seconds: 12)));
    } on TimeoutException {
      throw const ApiError('Could not reach the server. Check your connection.', 0, 'network');
    } on SocketException {
      throw const ApiError('Could not reach the server. Check your connection.', 0, 'network');
    } on http.ClientException {
      throw const ApiError('Could not reach the server. Check your connection.', 0, 'network');
    } on HandshakeException {
      throw const ApiError('Could not reach the server. Check your connection.', 0, 'network');
    }

    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      // A proxy's error page: handled below by its status.
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = data is Map ? data['error'] : null;
      throw ApiError(
        error is Map && error['message'] is String ? error['message'] as String : 'Something went wrong. Try again.',
        res.statusCode,
        error is Map && error['code'] is String ? error['code'] as String : 'unknown',
      );
    }
    return data;
  }

  Future<Json> _json(String method, String path, [Object? body]) async => (await _request(method, path, body)) as Json;

  Future<({String token, Guest guest})> createGuest(String name, String avatar) async {
    final j = await _json('POST', '/guests', {'name': name, 'avatar': avatar, 'ageConfirmed': true});
    return (token: j['token'] as String, guest: Guest.fromJson(j['guest'] as Json));
  }

  Future<Guest> me() async => Guest.fromJson((await _json('GET', '/me'))['guest'] as Json);
  Future<Guest> updateMe({String? name, String? avatar, Frame? frame}) async => Guest.fromJson((await _json('PATCH', '/me', {
        'name': ?name,
        'avatar': ?avatar,
        'frame': ?frame,
      }))['guest'] as Json);
  Future<Guest> topUp() async => Guest.fromJson((await _json('POST', '/me/coins/topup'))['guest'] as Json);
  Future<void> deleteMe() => _request('DELETE', '/me');

  Future<List<GuestPublic>> blocks() async =>
      ((await _json('GET', '/blocks'))['guests'] as List).map((e) => GuestPublic.fromJson(e as Json)).toList();
  Future<void> block(String id) => _request('POST', '/blocks/$id');
  Future<void> unblock(String id) => _request('DELETE', '/blocks/$id');
  Future<void> report(String target, String reason, [String? roomId]) =>
      _request('POST', '/reports', {'target': target, 'reason': reason, 'roomId': ?roomId});

  Future<List<Room>> rooms() async => ((await _json('GET', '/rooms'))['rooms'] as List).map((e) => Room.fromJson(e as Json)).toList();
  Future<RoomSession> createRoom({
    required RoomType type,
    required String title,
    required String theme,
    required int seats,
    required SeatMode seatMode,
    required RoomLayout layout,
  }) async =>
      RoomSession.fromJson(await _json('POST', '/rooms', {
        'type': type,
        'title': title,
        'theme': theme,
        'seats': seats,
        'seatMode': seatMode,
        'layout': layout,
      }));
  Future<RoomSession> joinRoom(String id) async => RoomSession.fromJson(await _json('POST', '/rooms/$id/join'));
  Future<Credentials> refreshRoomToken(String id) async =>
      Credentials.fromJson((await _json('POST', '/rooms/$id/token'))['credentials'] as Json);
  Future<void> endRoom(String id) => _request('POST', '/rooms/$id/end');
  Future<void> banFromRoom(String id, String identity) => _request('POST', '/rooms/$id/bans', {'identity': identity});

  Future<List<Gift>> gifts() async => ((await _json('GET', '/gifts'))['gifts'] as List).map((e) => Gift.fromJson(e as Json)).toList();
  Future<Guest> sendGift(String roomId, String giftId, String to, int count) async =>
      Guest.fromJson((await _json('POST', '/rooms/$roomId/gifts', {'giftId': giftId, 'to': to, 'count': count}))['guest'] as Json);

  Future<ChatChannel> loungeToken() async => ChatChannel.fromJson(await _json('POST', '/chat/lounge/token'));
  Future<List<ConversationSummary>> conversations() async =>
      ((await _json('GET', '/conversations'))['conversations'] as List).map((e) => ConversationSummary.fromJson(e as Json)).toList();
  Future<ConversationSummary> startConversation(String peerId) async =>
      ConversationSummary.fromJson((await _json('POST', '/conversations', {'peerId': peerId}))['conversation'] as Json);
  Future<({List<DirectMessage> messages, ChatChannel chat})> conversation(String id) async {
    final j = await _json('GET', '/conversations/$id');
    return (
      messages: (j['messages'] as List).map((e) => DirectMessage.fromJson(e as Json)).toList(),
      chat: ChatChannel.fromJson(j['chat'] as Json),
    );
  }

  Future<DirectMessage> sendDirect(String id, String text) async =>
      DirectMessage.fromJson((await _json('POST', '/conversations/$id/messages', {'text': text}))['message'] as Json);
  Future<void> markRead(String id) => _request('POST', '/conversations/$id/read');

  Future<Stats> stats() async => Stats.fromJson(await _json('GET', '/stats'));
  Future<Rates?> rates() async {
    final rates = (await _json('GET', '/voltkit'))['rates'];
    return rates == null ? null : Rates.fromJson(rates as Json);
  }
}

final api = Api();
