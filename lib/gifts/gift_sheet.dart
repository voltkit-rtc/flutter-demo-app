import 'package:flutter/material.dart';

import '../api/client.dart';
import '../app_assets.dart';
import '../components/ui.dart';
import '../icons.dart';
import '../rtc/room_engine.dart';
import '../state/session.dart';
import '../theme.dart';
import '../types.dart';
import '../util/format.dart';
import '../util/toast.dart';

const _counts = [1, 5, 10];

List<Gift>? _catalog;
Future<List<Gift>> loadCatalog() async => _catalog ??= await api.gifts();

class GiftSheet extends StatefulWidget {
  const GiftSheet({super.key, required this.room, required this.people, this.initialTo});

  final Room room;
  final List<Member> people;
  final String? initialTo;

  @override
  State<GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<GiftSheet> {
  var _gifts = _catalog ?? const <Gift>[];
  String? _selected;
  late String? _to = widget.initialTo;
  var _count = 1;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    loadCatalog().then((gifts) {
      if (mounted) setState(() => _gifts = gifts);
    }, onError: (Object _) => toast('Could not load the gifts', ToastKind.error));
  }

  Future<void> _send(Gift gift, Member target, Session session) async {
    setState(() => _busy = true);
    try {
      session.setGuest(await api.sendGift(widget.room.id, gift.id, target.identity, _count));
      if (mounted) Navigator.pop(context);
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _topUp(Session session) async {
    try {
      session.setGuest(await api.topUp());
      toast('Demo coins added', ToastKind.success);
    } on ApiError catch (err) {
      toast(err.message, ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final guest = session.guest;
    final people = widget.people;
    Member? target;
    for (final p in people) {
      if (p.identity == _to) target = p;
    }
    target ??= people.isEmpty ? null : people.first;
    Gift? gift;
    for (final g in _gifts) {
      if (g.id == _selected) gift = g;
    }
    gift ??= _gifts.isEmpty ? null : _gifts.first;
    final cost = (gift?.price ?? 0) * _count;
    final short = guest.coins < cost;
    // Whole numbers, inside the sheet's own border: four must always fit on a row.
    final cell = ((MediaQuery.sizeOf(context).width - 36 - 2 - 8 * 3) / 4).floorToDouble();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const T('Send a gift', variant: V.heading),
              Tap(
                id: 'topup',
                label: 'Get more demo coins',
                onTap: () => _topUp(session),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: C.glass, borderRadius: BorderRadius.circular(R.pill)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: gapped(4, horizontal: true, [
                      const Icon(Ion.logoBitcoin, size: 15, color: C.gold),
                      T(compact(guest.coins), variant: V.small, color: C.gold),
                      const Icon(Ion.addCircle, size: 17, color: C.gold),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const T('Demo coins only. They are free, have no value and cannot be bought or cashed out.', variant: V.tiny, color: C.textFaint),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = people[i];
                final mine = p.identity == guest.id;
                final on = target?.identity == p.identity;
                return Tap(
                  id: mine ? 'gift-to-me' : 'gift-to-${p.identity}',
                  label: 'Send to ${mine ? 'yourself' : p.name}',
                  onTap: () => setState(() => _to = p.identity),
                  child: Container(
                    padding: const EdgeInsets.only(left: 4, right: 10),
                    decoration: BoxDecoration(
                      color: on ? const Color(0x33D946EF) : C.glass,
                      borderRadius: BorderRadius.circular(R.pill),
                      border: Border.all(color: on ? C.magenta : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Avatar(avatar: p.avatar, size: 24),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: T(mine ? '${p.name} (you)' : p.name, variant: V.tiny, lines: 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in _gifts)
                Builder(
                  builder: (context) {
                    final on = gift?.id == g.id;
                    return Tap(
                      id: 'gift-${g.id}',
                      label: '${g.name}, ${g.price} demo coins',
                      onTap: () => setState(() => _selected = g.id),
                      child: Container(
                        width: cell,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? const Color(0x1AFFD765) : C.glass,
                          borderRadius: BorderRadius.circular(R.md),
                          border: Border.all(color: on ? C.gold : Colors.transparent),
                        ),
                        child: Column(
                          children: gapped(2, [
                            Asset(giftIconAsset(g.icon), width: 54, height: 54, fit: BoxFit.contain),
                            T(g.name, variant: V.tiny, lines: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Ion.logoBitcoin, size: 10, color: C.gold),
                                const SizedBox(width: 2),
                                T(compact(g.price), variant: V.tiny, color: C.gold),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ...gapped(4, horizontal: true, [
                for (final c in _counts)
                  Tap(
                    label: 'Send $c',
                    onTap: () => setState(() => _count = c),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _count == c ? C.purple : C.glass),
                      child: T('×$c', variant: V.small),
                    ),
                  ),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                  id: 'gift-send',
                  label: short ? 'Not enough coins' : 'Send · ${compact(cost)}',
                  disabled: short || target == null || gift == null,
                  loading: _busy,
                  onTap: () {
                    if (gift != null && target != null) _send(gift, target, session);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
