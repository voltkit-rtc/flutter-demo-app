import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../app_assets.dart';
import '../components/ui.dart';
import '../icons.dart';
import '../rtc/consent.dart';
import '../state/session.dart';
import '../theme.dart';
import '../types.dart';
import '../util/routes.dart';
import '../util/toast.dart';
import 'room_screen.dart';

const _seats = {
  'video': [4, 6, 9],
  'audio': [8, 10, 15],
};

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.on, required this.onTap, this.id});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final String? id;

  @override
  Widget build(BuildContext context) => Tap(
        id: id,
        label: label,
        selected: on,
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: on ? C.purple : C.glass, borderRadius: BorderRadius.circular(R.pill)),
          child: Center(widthFactor: 1, child: T(label, variant: V.small, color: on ? C.white : C.textDim)),
        ),
      );
}

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.type});

  final RoomType? type;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  late RoomType _type = widget.type ?? 'video';
  late final _title = TextEditingController(text: "${SessionScope.read(context).guest.name}'s room");
  var _theme = 'royal';
  late int _seatCount = _seats[_type]![1];
  SeatMode _seatMode = 'request';
  RoomLayout _layout = 'stage';
  var _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _pickType(RoomType next) => setState(() {
        _type = next;
        _seatCount = _seats[next]![1];
      });

  Future<void> _goLive() async {
    final title = _title.text.trim();
    if (title.length < 3) return toast('Give your room a title of at least 3 characters.', ToastKind.error);
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      if (!await askMediaConsent(_type)) return;
      final session = await api.createRoom(type: _type, title: title, theme: _theme, seats: _seatCount, seatMode: _seatMode, layout: _layout);
      unawaited(navigator.pushReplacement(fadeRoute(RoomScreen(roomId: session.room.id, initial: session))));
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: T(text, variant: V.small, color: C.textDim),
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Backdrop(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          padding: EdgeInsets.fromLTRB(16, media.padding.top + 8, 16, math.max(media.viewInsets.bottom, media.padding.bottom) + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBtn(id: 'create-close', size: 40, icon: Ion.chevronBack, label: 'Back', onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 10),
                  const T('Start a room', variant: V.title),
                ],
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: gapped(10, horizontal: true, [
                    for (final t in const ['video', 'audio'])
                      Expanded(
                        child: Tap(
                          id: 'create-type-$t',
                          label: '$t room',
                          selected: _type == t,
                          onTap: () => _pickType(t),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 112),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(R.lg),
                              gradient: diagonal(_type == t ? (t == 'video' ? G.video : G.audio) : G.panel),
                              border: Border.all(color: C.glassBorder, width: hairline(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: gapped(3, [
                                Icon(t == 'video' ? Ion.videocam : Ion.mic, size: 26, color: C.white),
                                T(t == 'video' ? 'Video room' : 'Audio room', variant: V.heading),
                                T(t == 'video' ? 'Cards for you and co-hosts' : 'A throne and numbered seats', variant: V.tiny, color: const Color(0xBFFFFFFF)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              _label('Title'),
              Field(id: 'create-title', controller: _title, maxLength: 48, hint: 'What is this room about?'),
              _label('Backdrop'),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: themeKeys.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final key = themeKeys[i];
                    return Tap(
                      label: '$key backdrop',
                      selected: _theme == key,
                      onTap: () => setState(() => _theme = key),
                      child: Container(
                        width: 76,
                        height: 100,
                        clipBehavior: Clip.antiAlias,
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(R.md),
                          border: Border.all(color: _theme == key ? C.gold : Colors.transparent, width: 2),
                        ),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(R.md)),
                        child: Asset(coverAsset(key), width: 76, height: 100),
                      ),
                    );
                  },
                ),
              ),
              _label(_type == 'video' ? 'Video cards, including yours' : 'Seats on stage'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in _seats[_type]!) _Option(id: 'create-seats-$n', label: '$n', on: _seatCount == n, onTap: () => setState(() => _seatCount = n)),
                ],
              ),
              if (_type == 'video') ...[
                _label('Layout'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Option(label: 'Stage', on: _layout == 'stage', onTap: () => setState(() => _layout = 'stage')),
                    _Option(label: 'Grid', on: _layout == 'grid', onTap: () => setState(() => _layout = 'grid')),
                  ],
                ),
              ],
              _label('Who gets on stage'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Option(id: 'create-mode-request', label: 'I approve each person', on: _seatMode == 'request', onTap: () => setState(() => _seatMode = 'request')),
                  _Option(id: 'create-mode-open', label: 'Anyone can take a seat', on: _seatMode == 'open', onTap: () => setState(() => _seatMode = 'open')),
                ],
              ),
              const SizedBox(height: 22),
              GradientButton(id: 'create-go', label: _type == 'video' ? 'Go live' : 'Open the room', icon: Ion.radio, loading: _busy, onTap: () => unawaited(_goLive())),
              const SizedBox(height: 18),
              const PoweredBy(),
            ],
          ),
        ),
      ),
    );
  }
}
