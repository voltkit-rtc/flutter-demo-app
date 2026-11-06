import 'package:voltkit_rtc/voltkit_rtc.dart' show Role;

/// `none`, `lion` or `wolf`.
typedef Frame = String;

/// `video` or `audio`.
typedef RoomType = String;

/// `open` or `request`.
typedef SeatMode = String;

/// `stage` or `grid`.
typedef RoomLayout = String;

typedef Json = Map<String, dynamic>;

Role roleFrom(Object? value) => switch (value) {
      'host' => Role.host,
      'cohost' => Role.cohost,
      'moderator' => Role.moderator,
      _ => Role.viewer,
    };

class GuestPublic {
  const GuestPublic({required this.id, required this.name, required this.avatar, required this.frame});

  final String id;
  final String name;
  final String avatar;
  final Frame frame;

  factory GuestPublic.fromJson(Json j) => GuestPublic(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Guest',
        avatar: j['avatar'] as String? ?? 'a01',
        frame: j['frame'] as String? ?? 'none',
      );
}

class Guest extends GuestPublic {
  const Guest({
    required super.id,
    required super.name,
    required super.avatar,
    required super.frame,
    required this.coins,
    required this.giftsReceived,
    required this.blocked,
    required this.restricted,
  });

  final int coins;
  final int giftsReceived;
  final List<String> blocked;
  final bool restricted;

  factory Guest.fromJson(Json j) => Guest(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Guest',
        avatar: j['avatar'] as String? ?? 'a01',
        frame: j['frame'] as String? ?? 'none',
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        giftsReceived: (j['giftsReceived'] as num?)?.toInt() ?? 0,
        blocked: ((j['blocked'] as List?) ?? const []).map((e) => e.toString()).toList(),
        restricted: j['restricted'] as bool? ?? false,
      );
}

class Room {
  const Room({
    required this.id,
    required this.type,
    required this.title,
    required this.theme,
    required this.seats,
    required this.seatMode,
    required this.layout,
    required this.host,
    required this.status,
    required this.viewers,
    required this.giftCoins,
  });

  final String id;
  final RoomType type;
  final String title;
  final String theme;
  final int seats;
  final SeatMode seatMode;
  final RoomLayout layout;
  final GuestPublic host;
  final String status;
  final int viewers;
  final int giftCoins;

  bool get isVideo => type == 'video';

  factory Room.fromJson(Json j) => Room(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'video',
        title: j['title'] as String? ?? '',
        theme: j['theme'] as String? ?? 'royal',
        seats: (j['seats'] as num?)?.toInt() ?? 4,
        seatMode: j['seatMode'] as String? ?? 'request',
        layout: j['layout'] as String? ?? 'stage',
        host: GuestPublic.fromJson(j['host'] as Json),
        status: j['status'] as String? ?? 'live',
        viewers: (j['viewers'] as num?)?.toInt() ?? 0,
        giftCoins: (j['giftCoins'] as num?)?.toInt() ?? 0,
      );
}

class Credentials {
  const Credentials({required this.token, required this.wsUrl, required this.role});

  final String token;
  final String wsUrl;
  final Role role;

  factory Credentials.fromJson(Json j) =>
      Credentials(token: j['token'] as String, wsUrl: j['wsUrl'] as String, role: roleFrom(j['role']));
}

class RoomSession {
  const RoomSession(this.room, this.credentials);

  final Room room;
  final Credentials credentials;

  factory RoomSession.fromJson(Json j) => RoomSession(Room.fromJson(j['room'] as Json), Credentials.fromJson(j['credentials'] as Json));
}

class Gift {
  const Gift({required this.id, required this.name, required this.price, required this.tier, required this.svgaUrl, required this.icon});

  final String id;
  final String name;
  final int price;
  final String tier;
  final String svgaUrl;
  final String icon;

  factory Gift.fromJson(Json j) => Gift(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        price: (j['price'] as num?)?.toInt() ?? 0,
        tier: j['tier'] as String? ?? 'basic',
        svgaUrl: j['svgaUrl'] as String? ?? '',
        icon: j['icon'] as String? ?? 'heart',
      );
}

class ConversationLast {
  const ConversationLast({required this.text, required this.at});

  final String text;
  final String at;
}

class ConversationSummary {
  const ConversationSummary({required this.id, required this.peer, required this.last, required this.unread});

  final String id;
  final GuestPublic peer;
  final ConversationLast? last;
  final int unread;

  factory ConversationSummary.fromJson(Json j) {
    final last = j['last'] as Json?;
    return ConversationSummary(
      id: j['id'] as String,
      peer: GuestPublic.fromJson(j['peer'] as Json),
      last: last == null ? null : ConversationLast(text: last['text'] as String? ?? '', at: last['at'] as String? ?? ''),
      unread: (j['unread'] as num?)?.toInt() ?? 0,
    );
  }
}

class DirectMessage {
  const DirectMessage({required this.id, required this.from, required this.text, required this.at});

  final String id;
  final String from;
  final String text;
  final String at;

  factory DirectMessage.fromJson(Json j) => DirectMessage(
        id: j['id'] as String,
        from: j['from'] as String? ?? '',
        text: j['text'] as String? ?? '',
        at: j['at'] as String? ?? '',
      );
}

class ChatChannel {
  const ChatChannel({required this.token, required this.wsUrl});

  final String token;
  final String wsUrl;

  factory ChatChannel.fromJson(Json j) => ChatChannel(token: j['token'] as String, wsUrl: j['wsUrl'] as String);
}

class MatchFound {
  const MatchFound({required this.callId, required this.token, required this.wsUrl, required this.peer});

  final String callId;
  final String token;
  final String wsUrl;
  final GuestPublic peer;

  factory MatchFound.fromJson(Json j) => MatchFound(
        callId: j['callId'] as String,
        token: j['token'] as String,
        wsUrl: j['wsUrl'] as String,
        peer: GuestPublic.fromJson((j['peer'] as Map).cast<String, dynamic>()),
      );
}

class Rates {
  const Rates({required this.audio, required this.video, required this.unit});

  final String? audio;
  final String? video;
  final String unit;

  factory Rates.fromJson(Json j) => Rates(
        audio: j['audio']?.toString(),
        video: j['video']?.toString(),
        unit: j['unit'] as String? ?? '',
      );
}

class Stats {
  const Stats({required this.liveRooms, required this.online, required this.waiting});

  final int liveRooms;
  final int online;
  final int waiting;

  factory Stats.fromJson(Json j) => Stats(
        liveRooms: (j['liveRooms'] as num?)?.toInt() ?? 0,
        online: (j['online'] as num?)?.toInt() ?? 0,
        waiting: (j['waiting'] as num?)?.toInt() ?? 0,
      );
}
