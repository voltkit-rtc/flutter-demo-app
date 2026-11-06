import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FlutterVersion;
import 'package:voltkit_rtc/voltkit_rtc.dart' show sdkVersion;

import '../api/client.dart';
import '../app_assets.dart';
import '../components/ui.dart';
import '../config.dart';
import '../icons.dart';
import '../state/session.dart';
import '../theme.dart';
import '../types.dart';
import '../util/format.dart';
import '../util/routes.dart';
import '../util/toast.dart';
import 'voltkit_screen.dart';

const _appVersion = '1.0.0';

const _frameOptions = [('none', 'None'), ('lion', 'Golden Lion'), ('wolf', 'Silver Wolf')];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _update({String? name, String? avatar, Frame? frame}) async {
    final session = SessionScope.read(context);
    try {
      session.setGuest(await api.updateMe(name: name, avatar: avatar, frame: frame));
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    }
  }

  Future<void> _topUp() async {
    final session = SessionScope.read(context);
    try {
      session.setGuest(await api.topUp());
      toast('Demo coins added', ToastKind.success);
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    }
  }

  Future<void> _deleteAll() async {
    final session = SessionScope.read(context);
    try {
      await api.deleteMe();
      await session.forget();
    } on ApiError {
      toast('That did not work. Try again.', ToastKind.error);
    }
  }

  void _pickAvatar() => showSheet<void>(
        context,
        title: 'Pick an avatar',
        builder: (sheet) => SingleChildScrollView(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: [
              for (final key in avatarKeys)
                Tap(
                  label: 'Avatar $key',
                  onTap: () {
                    Navigator.pop(sheet);
                    unawaited(_update(avatar: key));
                  },
                  child: Avatar(avatar: key, size: 68),
                ),
            ],
          ),
        ),
      );

  void _editName(String current) => showSheet<void>(
        context,
        title: 'Your name',
        builder: (sheet) => _NameSheet(initial: current, onSave: (name) => _update(name: name)),
      );

  void _confirmDelete() => showSheet<void>(
        context,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const T('Delete everything?', variant: V.title),
            const SizedBox(height: 10),
            const T('This guest, their coins and their direct messages are removed for good. Live rooms you host end.', color: C.textDim),
            const SizedBox(height: 16),
            GradientButton(
              id: 'profile-delete-yes',
              label: 'Delete my data',
              colors: G.danger,
              onTap: () {
                Navigator.pop(sheet);
                unawaited(_deleteAll());
              },
            ),
            const SizedBox(height: 10),
            GhostButton(label: 'Keep it', onTap: () => Navigator.pop(sheet)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final guest = SessionScope.of(context).guest;
    return Backdrop(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: gapped(12, [
            Column(
              children: [
                Tap(
                  id: 'profile-avatar',
                  label: 'Change avatar',
                  onTap: _pickAvatar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Avatar(avatar: guest.avatar, frame: guest.frame, size: 92),
                  ),
                ),
                const SizedBox(height: 4),
                Tap(
                  id: 'profile-name',
                  label: 'Change name',
                  onTap: () => _editName(guest.name),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      T(guest.name, variant: V.title),
                      const SizedBox(width: 7),
                      const Icon(Ion.pencil, size: 15, color: C.textDim),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const T('Guest on this phone', variant: V.tiny, color: C.textFaint),
              ],
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const T('Demo coins', variant: V.small, color: C.textDim),
                            T(grouped(guest.coins), id: 'coin-balance', variant: V.display, color: C.gold),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GradientButton(id: 'profile-topup', label: 'Get more', icon: Ion.add, dark: true, colors: G.gold, onTap: () => unawaited(_topUp())),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const T('Free and fictional. For trying gifts only: they have no value and cannot be bought or cashed out.', variant: V.tiny, color: C.textFaint),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const T('Avatar frame', variant: V.small, color: C.textDim),
                  const SizedBox(height: 8),
                  Row(
                    children: gapped(8, horizontal: true, [
                      for (final (id, label) in _frameOptions)
                        Expanded(
                          child: Tap(
                            id: 'frame-$id',
                            label: '$label frame',
                            selected: guest.frame == id,
                            onTap: () => unawaited(_update(frame: id)),
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: C.glass,
                                borderRadius: BorderRadius.circular(R.md),
                                border: Border.all(color: guest.frame == id ? C.gold : Colors.transparent),
                              ),
                              child: Column(
                                children: [
                                  SizedBox(height: 66, child: Center(child: Avatar(avatar: guest.avatar, frame: id, size: 36))),
                                  T(label, variant: V.tiny, lines: 1),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  const T('A frame shows on your seat, and plays an entrance effect when you join a room.', variant: V.tiny, color: C.textFaint),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.only(top: 6), child: T('Settings', variant: V.small, color: C.textDim)),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  SheetRow(
                    id: 'profile-blocked',
                    icon: Ion.banOutline,
                    label: 'Blocked people',
                    onTap: () => unawaited(Navigator.of(context).push(slideRoute(const BlockedScreen()))),
                  ),
                  SheetRow(id: 'profile-delete', icon: Ion.trashOutline, danger: true, label: 'Delete my data', hint: 'Removes this guest and their messages', onTap: _confirmDelete),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.only(top: 6), child: T('About this app', variant: V.small, color: C.textDim)),
            const Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(Voltkit.demoLine, variant: V.heading),
                  SizedBox(height: 4),
                  T(
                    'Everything live in here runs on VoltKit RTC: rooms, calls, chat and gifts. Want the same experience in your own app? You can build it with VoltKit.',
                    variant: V.small,
                    color: C.textDim,
                  ),
                  SizedBox(height: 12),
                  BuiltWith(alignment: WrapAlignment.start),
                ],
              ),
            ),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  SheetRow(id: 'about-build', icon: Ion.rocketOutline, gold: true, label: 'Build this into your app', hint: 'Video, voice, chat and gifts with Flutter', onTap: () => unawaited(openUrl(Voltkit.flutterPage))),
                  SheetRow(id: 'about-site', icon: Ion.globeOutline, label: 'Go to voltkit.in', hint: 'All of VoltKit RTC', onTap: () => unawaited(openUrl(Voltkit.site))),
                  SheetRow(id: 'about-docs', icon: Icons.flutter_dash, label: 'Flutter SDK docs', hint: 'Install, rooms, quality and errors', onTap: () => unawaited(openUrl(Voltkit.flutterDocs))),
                  SheetRow(id: 'about-quickstart', icon: Ion.flashOutline, label: 'Quickstart', hint: 'From sign-up to a working call', onTap: () => unawaited(openUrl(Voltkit.quickstart))),
                  SheetRow(
                    id: 'profile-voltkit',
                    icon: Ion.informationCircleOutline,
                    label: 'What this demo shows',
                    onTap: () => unawaited(Navigator.of(context).push(slideRoute(const VoltKitScreen()))),
                  ),
                ],
              ),
            ),
            T(
              'Version $_appVersion  ·  Flutter ${FlutterVersion.version ?? ''}  ·  VoltKit SDK $sdkVersion',
              id: 'about-versions',
              variant: V.tiny,
              color: C.textFaint,
              align: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial, required this.onSave});

  final String initial;
  final Future<void> Function(String name) onSave;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _name = TextEditingController(text: widget.initial);
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    await widget.onSave(_name.text.trim());
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Field(id: 'profile-name-input', controller: _name, maxLength: 24, autofocus: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          GradientButton(id: 'profile-name-save', label: 'Save', loading: _saving, disabled: _name.text.trim().length < 2, onTap: () => unawaited(_save())),
        ],
      );
}

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  List<GuestPublic>? _people;

  @override
  void initState() {
    super.initState();
    api.blocks().then((list) => mounted ? setState(() => _people = list) : null, onError: (Object _) => mounted ? setState(() => _people = []) : null);
  }

  Future<void> _unblock(String id) async {
    final session = SessionScope.read(context);
    try {
      await api.unblock(id);
      await session.refresh();
    } on ApiError {
      // Still listed next time, if it did not go through.
    }
    if (mounted) setState(() => _people = _people?.where((p) => p.id != id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    return Scaffold(
      body: Backdrop(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, MediaQuery.paddingOf(context).top + 8, 14, 0),
              child: Row(
                children: [
                  IconBtn(size: 38, icon: Ion.chevronBack, label: 'Back', onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 10),
                  const T('Blocked people', variant: V.title),
                ],
              ),
            ),
            Expanded(
              child: people != null && people.isEmpty
                  ? const Padding(padding: EdgeInsets.only(top: 46), child: T('Nobody is blocked.', color: C.textDim, align: TextAlign.center))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: people?.length ?? 0,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = people![i];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: C.glass, borderRadius: BorderRadius.circular(R.md)),
                          child: Row(
                            children: [
                              Avatar(avatar: item.avatar, size: 42),
                              const SizedBox(width: 10),
                              Expanded(child: T(item.name, variant: V.medium, lines: 1)),
                              const SizedBox(width: 10),
                              Tap(
                                label: 'Unblock ${item.name}',
                                onTap: () => unawaited(_unblock(item.id)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(color: C.glassStrong, borderRadius: BorderRadius.circular(R.pill)),
                                  child: const T('Unblock', variant: V.tiny),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
