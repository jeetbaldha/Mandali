import 'package:flutter/material.dart';

import '../core/game_client.dart';
import '../core/theme/brand.dart';
import '../ui/widgets.dart';
import 'solo_controller.dart';

class SoloSetupScreen extends StatefulWidget {
  final SoloController controller;
  const SoloSetupScreen({super.key, required this.controller});
  @override
  State<SoloSetupScreen> createState() => _SoloSetupScreenState();
}

class _SoloSetupScreenState extends State<SoloSetupScreen> {
  int step = 0, count = 4, seconds = 15;
  String kind = 'TEEN_PATTI';
  final balance = TextEditingController(text: '1000');
  final stake = TextEditingController(text: '20');
  final small = TextEditingController(text: '10');
  final big = TextEditingController(text: '20');
  String? error;
  bool loading = false;
  @override
  void dispose() {
    balance.dispose();
    stake.dispose();
    small.dispose();
    big.dispose();
    super.dispose();
  }

  Future<void> start() async {
    final points = int.tryParse(balance.text),
        ante = int.tryParse(stake.text),
        sb = int.tryParse(small.text),
        bb = int.tryParse(big.text);
    if (points == null ||
        points < 1 ||
        points > 1000000000 ||
        (kind == 'TEEN_PATTI' &&
            (ante == null || ante < 1 || ante > 100000 || points < ante)) ||
        (kind == 'POKER' &&
            (sb == null ||
                bb == null ||
                sb < 1 ||
                sb > 100000 ||
                bb < sb * 2 ||
                bb > 200000 ||
                points < bb))) {
      setState(
        () => error = 'Enter whole virtual points. Balance must cover the opening stake; big blind must be at least twice the small blind.',
      );
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final Json settings = {
        'kind': kind,
        'playerCount': count,
        'startingBalance': points,
        'decisionSeconds': seconds,
        'reviewSeconds': 15,
        if (kind == 'TEEN_PATTI') 'stake': ante,
        if (kind == 'POKER') ...{'smallBlind': sb, 'bigBlind': bb},
      };
      await widget.controller.start(settings);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget number(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your practice table')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: BrandMark(size: 52),
            ),
            Text(
              'SOLO / PRACTICE    ${step + 1} / 3',
              style: const TextStyle(color: gold, letterSpacing: 2),
            ),
            if (step == 0) ...[
              const SectionTitle(
                'What would you like to play?',
                subtitle: 'A private session with game-controlled participants. An internet connection is required.',
              ),
              for (final item in [
                (
                  'TEEN_PATTI',
                  'Teen Patti / 3 Patti',
                  'Three cards. Blind or seen. A little nerve.',
                ),
                (
                  'POKER',
                  'Poker',
                  'Texas Hold’em · two hole cards and a shared board.',
                ),
              ])
                Panel(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      kind == item.$1
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: gold,
                    ),
                    title: Text(item.$2),
                    subtitle: Text(item.$3),
                    onTap: () => setState(() => kind = item.$1),
                  ),
                ),
              if (kind == 'POKER')
                const ListTile(
                  title: Text('POKER FORMAT'),
                  subtitle: Text('Texas Hold’em · No Limit'),
                ),
            ],
            if (step == 1) ...[
              const SectionTitle(
                'How many players would you like at the table?',
                subtitle: 'You take one seat. We’ll fill the rest.',
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var n = 2; n <= 10; n++)
                    ChoiceChip(
                      label: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('$n players'),
                      ),
                      selected: count == n,
                      onSelected: (_) => setState(() => count = n),
                    ),
                ],
              ),
            ],
            if (step == 2) ...[
              const SectionTitle(
                'Make yourself comfortable.',
                subtitle: 'Choose your starting virtual balance. Points have no cash value.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in [500, 1000, 2000, 5000])
                    ChoiceChip(
                      label: Text('$n'),
                      selected: balance.text == '$n',
                      onSelected: (_) => setState(() => balance.text = '$n'),
                    ),
                  ActionChip(
                    label: const Text('Custom'),
                    onPressed: () => setState(() => balance.clear()),
                  ),
                ],
              ),
              number(balance, 'VIRTUAL BALANCE'),
              if (kind == 'TEEN_PATTI') ...[
                number(stake, 'Boot / opening blind stake'),
                const Text(
                  '3 cards each · seen stake is twice blind · no sideshow. Show is available with two players remaining. A-K-Q ranks above A-2-3. Equal Show hands favor the non-requester.',
                ),
              ] else ...[
                number(small, 'Small blind (virtual points)'),
                number(big, 'Big blind (virtual points)'),
                const Text(
                  'No-Limit Texas Hold’em · all-ins and side pots. Add points between hands. Best five cards win; no voting.',
                ),
              ],
              const SizedBox(height: 16),
              const Text('DECISION TIMER'),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in [10, 15])
                    ChoiceChip(
                      label: Text('$n seconds'),
                      selected: seconds == n,
                      onSelected: (_) => setState(() => seconds = n),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Exhausted practice participants receive a recorded virtual refill between hands. Your balance is always under your control.',
                ),
              ),
            ],
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 24),
            GameButton(
              onPressed: loading
                  ? null
                  : step < 2
                  ? () => setState(() => step++)
                  : start,
              child: Text(
                loading
                    ? 'Preparing your table…'
                    : step < 2
                    ? 'Continue →'
                    : 'Start game →',
              ),
            ),
            if (step > 0)
              TextButton(
                onPressed: loading ? null : () => setState(() => step--),
                child: const Text('Back'),
              ),
            const SizedBox(height: 16),
            const Text(
              'VIRTUAL POINTS ONLY · NO CASH VALUE',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
