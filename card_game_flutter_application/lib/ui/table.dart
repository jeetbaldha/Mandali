import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/controllers/game_controller.dart';
import '../solo/action_panel.dart';
import 'live_turn_clock.dart';
import 'player_avatar.dart';
import '../core/voice_controller.dart';
import 'widgets.dart';
import 'motion.dart';
import 'table_effects.dart';

class GameTable extends StatefulWidget {
  final GameController client;
  final VoiceController? voice;
  final VoidCallback? onLeave;
  final Future<void> Function(String, Json) onCommand;
  final VoidCallback onAddBalance;
  final VoidCallback onLobbySettings;
  const GameTable({
    super.key,
    required this.client,
    this.voice,
    this.onLeave,
    required this.onCommand,
    required this.onAddBalance,
    required this.onLobbySettings,
  });
  @override
  State<GameTable> createState() => _GameTableState();
}

class _GameTableState extends State<GameTable> {
  GameController get c => widget.client;
  Json get g => c.game!;
  int cardCount = 3;
  String? selection;
  int? ballotNumber;
  final ScrollController scroll = ScrollController();
  String? lastPhase;
  final Set<int> selectedCards = {};
  @override
  void initState() {
    super.initState();
    lastPhase = c.game?['phase'];
  }

  @override
  void didUpdateWidget(covariant GameTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPhase = c.game?['phase'];
    if (nextPhase == 'RESULT' && lastPhase != 'RESULT') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients) return;
        if (reducedMotion(context)) {
          scroll.jumpTo(0);
        } else {
          scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    lastPhase = nextPhase;
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  String playerName(String id) =>
      c.players.where((p) => p['id'] == id).firstOrNull?['name'] ??
      (g['players'] as List)
          .cast<Json>()
          .where((p) => p['id'] == id)
          .firstOrNull?['name'] ??
      id;
  Future<void> action(String value) =>
      widget.onCommand('game:action', {'action': value});
  bool get ready => c.connected && !c.busy;
  @override
  Widget build(BuildContext context) {
    final phase = g['phase'];
    final mine = c.handPlayer;
    final turn = (g['pending'] as List).firstOrNull;
    final ownTurn = turn == c.selfId && ready && c.seconds > 0;
    final players = (g['players'] as List).cast<Json>();
    final reveal = ['REVEAL', 'VOTING', 'RESULT', 'PAUSED'].contains(phase);
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (phase == 'RESULT') resultPanel(players),
        Row(
          children: [
            Expanded(
              child: Text(
                c.solo
                    ? '${c.room!['name']} · PRIVATE PRACTICE'
                    : '${c.room!['name']} · ${c.room!['code']}',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
            const Icon(Icons.lock_outline, size: 14, color: mint),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SectionTitle(
                phase == 'RESULT'
                    ? 'A hand to remember.'
                    : c.poker
                    ? (g['street'] as String).replaceAll('_', ' ')
                    : 'Round ${g['round']}',
                subtitle: 'Dealer · ${playerName(g['dealerId'])}',
              ),
            ),
            if (g['endTime'] != null) LiveTurnClock(controller: c),
          ],
        ),
        PhaseRibbon(phase: phase, round: g['round']),
        if (c.poker)
          Panel(
            child: Column(
              children: [
                const Text(
                  'COMMUNITY CARDS',
                  style: TextStyle(color: gold, letterSpacing: 2, fontSize: 11),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, bounds) => Wrap(
                    alignment: WrapAlignment.center,
                    children: List.generate(
                      5,
                      (i) => PlayingCard(
                        key: ValueKey('board-$i'),
                        width: ((bounds.maxWidth - 30) / 5).clamp(28, 52),
                        card: (g['board'] as List).length > i
                            ? Json.from(g['board'][i])
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            final rails = players.length > 6;
            final height = rails ? ((players.length / 2).ceil() * 120.0) : 410.0;
            return SizedBox(
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: width * .12,
                    right: width * .12,
                    top: 45,
                    bottom: 45,
                    child: const FeltSurface(),
                  ),
                  AnimatedPot(
                    value: (g['result']?['pot'] ?? g['pot']) as int,
                    call: g['call'],
                    compact: width < 380,
                  ),
                  for (var i = 0; i < players.length; i++)
                    Positioned(
                      left:
                          rails ? (i.isEven ? 0 : width - 90) : width / 2 +
                          math.sin(i * 2 * math.pi / players.length) *
                              (width / 2 - 50) -
                          45,
                      top:
                          rails ? (i ~/ 2) * 120.0 + 8 : height / 2 -
                          math.cos(i * 2 * math.pi / players.length) *
                              (height / 2 - 52) -
                          42,
                      width: 90,
                      child: Enter(
                        key: ValueKey(players[i]['id']),
                        milliseconds: 450 + i * 70,
                        distance: 12,
                        child: seat(players[i], turn),
                      ),
                    ),
                  if ((g['cardCount'] as int) > 0 &&
                      phase == 'DECISION' &&
                      g['round'] == 1)
                    Positioned.fill(
                      child: DealFlight(
                        key: ValueKey(g['id']),
                        seats: players.length,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (phase == 'WAITING_DEAL')
          Panel(
            child: Column(
              children: [
                const SectionTitle(
                  'The table is yours.',
                  subtitle: 'The dealer chooses equal cards per player and deals clockwise.',
                ),
                if (g['dealerId'] == c.selfId) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: cardCount > 1
                            ? () => setState(() => cardCount--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$cardCount cards each',
                        style: const TextStyle(fontSize: 20),
                      ),
                      IconButton(
                        onPressed: cardCount < 52 ~/ players.length
                            ? () => setState(() => cardCount++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: ready
                        ? () => widget.onCommand('game:deal', {
                            'cardCount': cardCount.clamp(
                              1,
                              52 ~/ players.length,
                            ),
                          })
                        : null,
                    icon: const Icon(Icons.style),
                    label: const Text('Shuffle & deal'),
                  ),
                ] else
                  Text('Waiting for ${playerName(g['dealerId'])} to deal.'),
              ],
            ),
          ),
        if (mine != null && phase != 'WAITING_DEAL')
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mine['folded']
                            ? 'FOLDED · WATCHING'
                            : mine['seen']
                            ? 'YOUR HAND'
                            : 'YOUR HAND · HIDDEN',
                        style: const TextStyle(
                          color: gold,
                          letterSpacing: 1.4,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text('${c.me?['balance']} pts'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    (g['cardCount'] as int),
                    (i) => PlayingCard(
                      selected: selectedCards.contains(i),
                      onTap: () => setState(() { if (!selectedCards.add(i)) selectedCards.remove(i); }),
                      card: (mine['cards'] as List).length > i
                          ? Json.from(mine['cards'][i])
                          : null,
                    ),
                  ),
                ),
                if (!mine['folded'] &&
                    !mine['seen'] &&
                    ['DECISION', 'SHOW_CHOICE'].contains(phase))
                  TextButton(
                    onPressed: ready
                        ? () => widget.onCommand('game:see', {})
                        : null,
                    child: const Text('See cards · no extra payment'),
                  ),
                Text(
                  'Contributed ${mine['contributed']} · Added ${mine['added']} virtual points',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        if (c.solo && phase == 'DECISION')
          SoloActionPanel(
            controller: c,
            onCommand: widget.onCommand,
            onAddBalance: widget.onAddBalance,
          ),
        if (!c.solo && (phase == 'DECISION' || phase == 'SHOW_CHOICE'))
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ownTurn
                      ? phase == 'SHOW_CHOICE'
                            ? 'SHOW IS AVAILABLE'
                            : 'YOUR TURN'
                      : '${playerName(turn ?? '')} is deciding…',
                  style: const TextStyle(color: mint, letterSpacing: 1.2),
                ),
                const SizedBox(height: 12),
                if (ownTurn && phase == 'DECISION') ...[
                  if ((c.me!['balance'] as num) < (g['call'] as num)) ...[
                    Text(
                      'Your balance is ${c.me!['balance']} points. This round requires ${g['call']}. Add virtual points or fold before the timer ends.',
                    ),
                    const SizedBox(height: 10),
                    GameButton(
                      onPressed: widget.onAddBalance,
                      child: const Text('Modify balance'),
                    ),
                  ] else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        GameButton(
                          onPressed: () => action('BLIND'),
                          child: const Text('Blind'),
                        ),
                        GameButton(
                          onPressed: () => action('PLAY'),
                          child: const Text('Play'),
                        ),
                      ],
                    ),
                  TextButton(
                    onPressed: () => action('FOLD'),
                    child: const Text("Don't play / Fold"),
                  ),
                ],
                if (ownTurn && phase == 'SHOW_CHOICE')
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      GameButton(
                        onPressed: () => action('SHOW'),
                        child: const Text('Show cards'),
                      ),
                      OutlinedButton(
                        onPressed: () => action('CONTINUE'),
                        child: Text(
                          'Continue · next ${g['call'] + c.room!['settings']['increment']}',
                        ),
                      ),
                    ],
                  ),
                if (!ownTurn)
                  const Text(
                    'The server controls turns and timers.',
                    style: TextStyle(color: Colors.white54),
                  ),
              ],
            ),
          ),
        if (reveal &&
            players.any(
              (p) => !p['folded'] && (p['cards'] as List).isNotEmpty,
            )) ...[
          SectionTitle(
            phase == 'REVEAL' ? 'Review the hands' : 'Revealed hands',
            subtitle: phase == 'REVEAL'
                ? c.solo
                      ? 'Inspect the hands. The card rankings determine the result.'
                      : 'Discuss together. Voting opens when the timer ends.'
                : null,
          ),
          ...players
              .where((p) => !p['folded'] && (p['cards'] as List).isNotEmpty)
              .map(
                (p) => Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(playerName(p['id'])),
                      Wrap(
                        children: (p['cards'] as List)
                            .map(
                              (card) =>
                                  PlayingCard(card: Json.from(card), width: 42),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
        ],
        if (phase == 'VOTING') votingPanel(),
        if (phase == 'PAUSED')
          Panel(
            child: Column(
              children: [
                const Icon(Icons.pause_circle_outline, size: 40, color: gold),
                SectionTitle('Hand paused', subtitle: g['reason']),
                const Text('All accumulated virtual points remain in the pot.'),
                if (c.host && players.where((p) => !p['folded']).length > 1)
                  GameButton(
                    onPressed: ready
                        ? () => widget.onCommand('show:reopen', {})
                        : null,
                    child: const Text('Reopen voting'),
                  ),
              ],
            ),
          ),
        if (phase != 'RESULT' && !c.poker)
          TextButton.icon(
            onPressed: widget.onAddBalance,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Modify virtual balance'),
          ),
        if (phase != 'RESULT')
          TextButton(
            onPressed: () async {
              await widget.voice?.leave();
              if (widget.onLeave != null) {
                widget.onLeave!();
              } else {
                await c.disconnectRoom();
              }
            },
            child: Text(
              c.solo
                  ? 'Back to home · practice hand continues'
                  : 'Leave table · seat and timers remain active',
            ),
          ),
        if ((c.players.length - players.length) > 0)
          Text(
            '${c.players.length - players.length} friends watching · voice remains available',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget seat(Json hp, dynamic turn) {
    final player =
        c.players.where((p) => p['id'] == hp['id']).firstOrNull ??
        {
          'name': hp['name'] ?? 'Player',
          'avatar': hp['avatar'] ?? 'kite',
          'balance':
              (hp['startingBalance'] ?? 0) +
              (hp['added'] ?? 0) -
              (hp['contributed'] ?? 0) +
              (hp['won'] ?? 0),
        };
    final speaking = widget.voice?.speaking(hp['id']) ?? false;
    final dealer = g['dealerId'] == hp['id'];
    final online = c.room!['presence']?[hp['id']]?['connected'] ?? false;
    return GestureDetector(
      onTap: hp['id'] == c.selfId || c.solo
          ? null
          : () => widget.voice?.mutePlayer(hp['id']),
      child: AnimatedContainer(
        duration: Duration(milliseconds: reducedMotion(context) ? 0 : 250),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: turn == hp['id']
                ? [const Color(0xff3b4935), const Color(0xff1f382d)]
                : [const Color(0xff1c3436), const Color(0xff102023)],
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (speaking
                          ? mint
                          : turn == hp['id']
                          ? gold
                          : Colors.black)
                      .withValues(
                        alpha: speaking || turn == hp['id'] ? .22 : .25,
                      ),
              blurRadius: speaking || turn == hp['id'] ? 18 : 6,
              spreadRadius: speaking || turn == hp['id'] ? 1 : 0,
            ),
          ],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: speaking
                ? mint
                : turn == hp['id']
                ? gold
                : const Color(0xff345048),
            width: speaking || turn == hp['id'] ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(kind: player['avatar'] ?? 'kite', size: 30),
            Text(
              player['name'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  c.solo
                      ? (turn == hp['id']
                            ? Icons.more_horiz
                            : Icons.style_outlined)
                      : Icons.circle,
                  size: 6,
                  color: c.solo
                      ? gold
                      : online
                      ? mint
                      : Colors.orange,
                ),
                const SizedBox(width: 3),
                Text(
                  hp['folded']
                      ? 'FOLDED'
                      : dealer
                      ? 'DEALER'
                      : hp['blind']
                      ? 'BLIND'
                      : '${player['balance']} pts',
                  style: TextStyle(
                    fontSize: 8,
                    color: dealer ? gold : Colors.white60,
                  ),
                ),
                if (widget.voice?.mutedPlayers.contains(hp['id']) ?? false)
                  const Icon(Icons.volume_off, size: 10),
              ],
            ),
            if (speaking)
              const Text(
                'Speaking',
                style: TextStyle(fontSize: 8, color: mint),
              ),
            if (c.solo && hp['lastAction'] != null)
              Text(
                (hp['lastAction'] as String).replaceAll('_', ' '),
                maxLines: 1,
                style: const TextStyle(fontSize: 9, color: gold),
              ),
            if ((g['cardCount'] as int) > 0)
              AnimatedOpacity(duration: Duration(milliseconds: reducedMotion(context) ? 0 : 220), opacity: hp['folded'] ? .3 : 1, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < math.min(3, g['cardCount'] as int); i++)
                  Container(width: 9, height: 13, margin: const EdgeInsets.only(top: 3, left: 1), decoration: BoxDecoration(color: const Color(0xff28473e), border: Border.all(color: gold.withValues(alpha: .6)), borderRadius: BorderRadius.circular(2))),
              ])),
          ],
        ),
      ),
    );
  }

  Widget votingPanel() {
    final ballot = (g['ballots'] as List).last as Json;
    if (ballotNumber != ballot['number']) {
      ballotNumber = ballot['number'];
      selection = null;
    }
    final submitted = (ballot['votes'] as Map).containsKey(c.selfId);
    final eligible = c.handPlayer != null && c.handPlayer!['folded'] != true;
    final options = <String>[
      ...(ballot['candidates'] as List).cast<String>().where(
        (id) => id != c.selfId,
      ),
      'ABSTAIN',
      'DRAW',
    ];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            ballot['number'] == 1 ? 'Who should win?' : 'Tie-break vote',
            subtitle: 'Votes stay hidden until the timer ends. Your vote cannot be changed.',
          ),
          if (!eligible)
            const Text('Watching · only remaining players vote.')
          else if (submitted)
            const Text(
              'Vote submitted ✓\nWaiting for the voting timer…',
              style: TextStyle(color: mint),
            )
          else ...[
            ...options.map(
              (id) => ListTile(
                onTap: ready ? () => setState(() => selection = id) : null,
                leading: Icon(
                  selection == id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selection == id ? gold : Colors.white54,
                ),
                title: Text(
                  id == 'ABSTAIN'
                      ? "Don't vote"
                      : id == 'DRAW'
                      ? 'Draw · split between eligible players'
                      : playerName(id),
                ),
              ),
            ),
            GameButton(
              onPressed: ready && selection != null && c.seconds > 0
                  ? () => widget.onCommand('show:vote', {'choice': selection})
                  : null,
              child: const Text('Submit vote'),
            ),
          ],
        ],
      ),
    );
  }

  Widget resultPanel(List<Json> players) {
    final result = g['result'] as Json;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VictoryEmblem(key: ValueKey(g['id'])),
          SectionTitle(
            result['kind'] == 'DRAW'
                ? 'Shared honours.'
                : '${playerName((result['winners'] as List).first)} wins!',
            subtitle: '${result['pot']} virtual points awarded',
          ),
          if (c.solo && result['labels'] != null)
            ...((result['labels'] as Map).entries.map(
              (e) => Text(
                '${playerName(e.key)} · ${e.value}',
                style: const TextStyle(color: gold),
              ),
            )),
          if (c.poker && result['pots'] != null)
            ...((result['pots'] as List).asMap().entries.map(
              (e) => Text(
                '${e.key == 0 ? 'Main pot' : 'Side pot ${e.key}'} · ${e.value['amount']} → ${(e.value['winners'] as List).map((id) => playerName(id)).join(', ')}',
              ),
            )),
          ...players.map((p) {
            final net = (p['won'] as int) - (p['contributed'] as int);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${playerName(p['id'])}    ${net >= 0 ? '+' : ''}$net net points',
                    style: TextStyle(
                      color: net >= 0 ? mint : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Start ${p['startingBalance']} · Added ${p['added']} · Paid ${p['contributed']}\nWon ${p['won']} · Lost ${math.max(0, -net)} · Final ${p['startingBalance'] + p['added'] - p['contributed'] + p['won']}',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            );
          }),
          ...((g['ballots'] as List)
              .where((b) => b['counts'] != null)
              .map(
                (b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Ballot ${b['number']}: ${(b['counts'] as Map).entries.map((e) => '${e.key == 'DRAW' || e.key == 'ABSTAIN' ? e.key : playerName(e.key)} ${e.value}').join(' · ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )),
          if (c.solo)
            TextButton(
              onPressed: widget.onAddBalance,
              child: const Text('Modify virtual balance'),
            ),
          if (c.host) ...[
            if (!c.solo)
              OutlinedButton(
                onPressed: widget.onLobbySettings,
                child: const Text('Configure next hand'),
              ),
            GameButton(
              onPressed: ready
                  ? () => widget.onCommand('game:start', {})
                  : null,
              child: const Text('Next hand · rotate dealer'),
            ),
          ],
          TextButton(
            onPressed: ready
                ? () async {
                    if (c.solo) {
                      widget.onLeave?.call();
                    } else {
                      await widget.onCommand('room:leave', {});
                      if (c.room == null) await widget.voice?.leave();
                    }
                  }
                : null,
            child: Text(c.solo ? 'Back to home' : 'Leave room'),
          ),
        ],
      ),
    );
  }
}
