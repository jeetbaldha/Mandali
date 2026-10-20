import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/game_client.dart';
import '../core/voice_controller.dart';
import 'widgets.dart';
import 'table.dart';
import 'motion.dart';
import 'mode_home.dart';
import '../core/theme/brand.dart';
import '../solo/solo_controller.dart';
import '../solo/setup_screen.dart';
import '../solo/practice_screen.dart';
import '../core/audio/game_audio.dart';
import '../core/audio/table_audio.dart';

class GameShell extends StatefulWidget {
  final GameClient client;
  const GameShell({super.key, required this.client});
  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  GameClient get c => widget.client;
  late final VoiceController voice;
  late final SoloController solo;
  late final TableAudio tableAudio;
  final name = TextEditingController();
  String avatar = 'peacock';
  @override
  void initState() {
    super.initState();
    voice = VoiceController(c);
    solo = SoloController(c);
    tableAudio = TableAudio(c);
    voice.addListener(voiceAudioChanged);
  }

  @override
  void dispose() {
    name.dispose();
    voice.removeListener(voiceAudioChanged);
    voice.dispose();
    tableAudio.dispose();
    solo.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    try {
      await task();
    } catch (e) {
      unawaited(GameAudio.instance.play('error'));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> addPoints() async {
    final values = await form(
      'Modify virtual balance',
      {'amount': '100'},
      descriptions: const {'amount': 'Add virtual points (no cash value)'},
    );
    if (values != null) {
      await run(
        () => c.command('balance:add', {
          'amount': int.tryParse(values['amount']!),
        }),
      );
    }
  }

  Future<Map<String, String>?> form(
    String title,
    Map<String, String> values, {
    Map<String, String> descriptions = const {},
  }) async {
    final controllers = values.map(
      (key, value) => MapEntry(key, TextEditingController(text: value)),
    );
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextField(
                        controller: e.value,
                        decoration: InputDecoration(
                          labelText: descriptions[e.key] ?? e.key,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controllers.map((k, v) => MapEntry(k, v.text.trim())),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    // Dispose after the route transition has finished using its text fields.
    Future.delayed(const Duration(seconds: 1), () {
      for (final value in controllers.values) {
        value.dispose();
      }
    });
    return result;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, voice]),
    builder: (context, _) {
      if (c.loading) {
        return const BrandSplash();
      }
      return Scaffold(
        appBar: AppBar(
          leading: const Padding(
            padding: EdgeInsets.only(left: 20),
            child: BrandMark(size: 28),
          ),
          titleSpacing: 6,
          title: const Text(
            Brand.name,
            style: TextStyle(
              letterSpacing: 4,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
          actions: [
            if (c.user != null)
              IconButton(
                tooltip: 'Profile',
                onPressed: profile,
                icon: const Icon(Icons.person_outline),
              ),
            IconButton(
              tooltip: 'Settings',
              onPressed: settings,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: AmbientBackground(
          child: SafeArea(
            child: Column(
              children: [
                if (c.user != null && !c.connected)
                  Material(
                    color: const Color(0xff543b25),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.wifi_off),
                      title: const Text('Connection lost · Reconnecting…'),
                      subtitle: const Text('Your hand stays on the server.'),
                      trailing: IconButton(
                        onPressed: c.connect,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  ),
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      c.error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1050),
                      child: Enter(
                        key: ValueKey(
                          c.user == null
                              ? 'entry'
                              : c.room == null
                              ? 'home'
                              : c.game == null
                              ? 'lobby-${c.roomId}'
                              : 'table-${c.game!['id']}',
                        ),
                        child: c.user == null
                            ? entry()
                            : c.room == null
                            ? home()
                            : c.game == null
                            ? lobby()
                            : GameTable(
                                client: c,
                                voice: voice,
                                onCommand: (event, payload) =>
                                    run(() => c.command(event, payload)),
                                onAddBalance: addPoints,
                                onLobbySettings: configure,
                              ),
                      ),
                    ),
                  ),
                ),
                if (c.room != null) voiceBar(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    'VIRTUAL POINTS ONLY  ·  NO CASH VALUE',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xff9bafab),
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget entry() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 6),
      const CardEmblem(),
      const Center(
        child: Text(
          'A SEAT FOR EVERY FRIEND',
          style: TextStyle(
            color: gold,
            fontSize: 10,
            letterSpacing: 2.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SectionTitle(
        'Your people. Your table.',
        subtitle: 'A private card night, wherever your friends are. Play, talk, and share the moment.',
      ),
      Enter(
        milliseconds: 900,
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'TAKE YOUR SEAT',
                style: TextStyle(color: gold, letterSpacing: 2),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: name,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Your display name',
                ),
              ),
              Wrap(
                spacing: 8,
                children: avatars.entries
                    .map(
                      (e) => ChoiceChip(
                        label: Text(
                          e.value,
                          style: const TextStyle(fontSize: 24),
                        ),
                        selected: avatar == e.key,
                        onSelected: (_) => setState(() => avatar = e.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              PressFeedback(
                child: FilledButton(
                  onPressed: () => run(() => c.login(name.text.trim(), avatar)),
                  child: const Text('Enter as guest  →'),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your guest identity is saved on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget home() => ModeHome(
    name: c.user!['name'],
    connected: c.connected,
    onCreate: () => roomDialog(true),
    onJoin: () => roomDialog(false),
    onSolo: openPractice,
    onRooms: () => showData('Your rooms', '/rooms'),
    onHistory: () => showData('Game history', '/history'),
    onPracticeHistory: () => showData('Practice history', '/practice/history'),
    onSettings: settings,
  );
  Future<void> openPractice() async {
    await run(() async {
      await voice.leave();
      await solo.sync();
      if (!mounted) return;
      if (solo.game == null || solo.game!['phase'] == 'RESULT') {
        final started = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => SoloSetupScreen(controller: solo)),
        );
        if (started != true || !mounted) return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PracticeScreen(controller: solo)),
      );
    });
  }

  Future<void> roomDialog(bool create) async {
    final values = await form(
      create ? 'Create room' : 'Join room',
      {
        create ? 'name' : 'code': create ? "${c.user!['name']}'s game" : '',
        'balance': '',
      },
      descriptions: const {
        'name': 'Room name',
        'code': 'Room code',
        'balance': 'Starting points (blank = host default)',
      },
    );
    if (values == null) return;
    await run(() async {
      await voice.leave();
      await c.command(create ? 'room:create' : 'room:join', {
        create ? 'name' : 'code': values[create ? 'name' : 'code'],
        if (values['balance']!.isNotEmpty)
          'balance': int.tryParse(values['balance']!),
      });
    });
  }

  Widget lobby() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      SectionTitle(
        c.room!['name'],
        subtitle: 'Your private table is ready. Invite your mandali.',
      ),
      Panel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ROOM CODE',
                    style: TextStyle(
                      color: mint,
                      letterSpacing: 2,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    c.room!['code'],
                    style: const TextStyle(
                      fontSize: 26,
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy code',
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: c.room!['code'])),
              icon: const Icon(Icons.copy),
            ),
            IconButton(
              tooltip: 'Share code',
              onPressed: () => run(() async {
                await SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Join my Mandali card room: ${c.room!['code']}. Virtual points only.',
                    sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100),
                  ),
                );
              }),
              icon: const Icon(Icons.ios_share),
            ),
          ],
        ),
      ),
      SectionTitle(
        '${c.players.length} / 10 friends',
        subtitle:
            '${c.players.where((p) => p['active'] == true).length} active · minimum 3 to start',
      ),
      ...c.players.map(
        (p) => Panel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: p['id'] == c.selfId
                ? null
                : () => run(() => voice.mutePlayer(p['id'])),
            leading: CircleAvatar(
              backgroundColor: voice.speaking(p['id']) ? mint : null,
              child: Text(avatars[p['avatar']] ?? '🪁'),
            ),
            title: Text('${p['name']}${p['id'] == c.selfId ? ' (you)' : ''}'),
            subtitle: Text(
              '${p['id'] == c.room!['hostId'] ? 'Host · ' : ''}${p['active'] ? 'Playing' : 'Waiting'} · ${p['balance']} points',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  voice.mutedPlayers.contains(p['id'])
                      ? Icons.volume_off
                      : (c.room!['presence']?[p['id']]?['mic'] ?? false)
                      ? Icons.mic
                      : Icons.mic_off,
                  size: 18,
                  color: voice.speaking(p['id']) ? mint : Colors.white54,
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.circle,
                  size: 12,
                  color: (c.room!['presence']?[p['id']]?['connected'] ?? false)
                      ? mint
                      : Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ),
      Panel(
        child: Text(
          'Call ${c.room!['settings']['startingCall']} · +${c.room!['settings']['increment']} each round\nShow after round ${c.room!['settings']['showAfter']} · ${c.room!['settings']['decisionSeconds']}s turns',
          style: const TextStyle(height: 1.8),
        ),
      ),
      if (c.host) ...[
        OutlinedButton.icon(
          onPressed: configure,
          icon: const Icon(Icons.tune),
          label: const Text('Room rules & active seats'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed:
              c.connected &&
                  !c.busy &&
                  c.players.where((p) => p['active'] == true).length >= 3
              ? () => run(() => c.command('game:start'))
              : null,
          child: const Text('Start hand'),
        ),
      ],
      TextButton(onPressed: addPoints, child: const Text('Modify balance')),
      TextButton(
        onPressed: () => run(() async {
          await c.command('room:leave');
          await voice.leave();
        }),
        child: const Text('Leave room'),
      ),
    ],
  );
  Widget voiceBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    color: const Color(0xff152727),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (voice.error != null)
          Text(
            voice.error!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                'VOICE · ${voice.status.toUpperCase()}',
                style: const TextStyle(color: mint, fontSize: 10),
              ),
            ),
            if (!voice.connected)
              TextButton(
                onPressed: voice.joining ? null : () => run(voice.join),
                child: Text(voice.joining ? 'Joining…' : 'Join voice'),
              ),
            if (voice.connected) ...[
              IconButton(
                tooltip: 'Microphone',
                onPressed: voice.pushToTalk
                    ? null
                    : () => run(() => voice.setMic(!voice.mic)),
                icon: Icon(
                  voice.mic ? Icons.mic : Icons.mic_off,
                  color: voice.mic ? mint : Colors.white54,
                ),
              ),
              IconButton(
                tooltip: 'Speaker on/off',
                onPressed: () => run(() => voice.setSpeaker(!voice.speaker)),
                icon: Icon(voice.speaker ? Icons.volume_up : Icons.volume_off),
              ),
              IconButton(
                tooltip: 'Push-to-talk',
                onPressed: () => run(() async {
                  voice.pushToTalk = !voice.pushToTalk;
                  await voice.setMic(false);
                }),
                icon: Icon(
                  Icons.touch_app,
                  color: voice.pushToTalk ? gold : Colors.white54,
                ),
              ),
              IconButton(
                tooltip: 'Leave voice',
                onPressed: () => run(() async {
                  await voice.leave();
                  setState(() {});
                }),
                icon: const Icon(Icons.call_end),
              ),
            ],
          ],
        ),
        if (voice.connected && voice.pushToTalk)
          Listener(
            onPointerDown: (_) => unawaited(voice.setMic(true)),
            onPointerUp: (_) => unawaited(voice.setMic(false)),
            onPointerCancel: (_) => unawaited(voice.setMic(false)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: voice.mic
                  ? const Color(0xff397b65)
                  : const Color(0xff28443e),
              child: const Text('Hold to talk', textAlign: TextAlign.center),
            ),
          ),
      ],
    ),
  );
  Future<void> configure() async {
    final settings = Json.from(c.room!['settings']);
    final values = await form(
      'Room rules',
      settings.map((k, v) => MapEntry(k, '$v')),
      descriptions: const {
        'activeLimit': 'Active seats (3–10)',
        'startingBalance': 'Default points for new joins',
        'startingCall': 'First call',
        'increment': 'Call increment',
        'showAfter': 'Show after round',
        'decisionSeconds': 'Turn seconds (10 or 15)',
        'reviewSeconds': 'Review seconds (15–20)',
      },
    );
    if (values == null || !mounted) return;
    final active = c.players
        .where((p) => p['active'] == true)
        .map((p) => p['id'] as String)
        .toSet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Choose active seats'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: c.players
                  .map(
                    (p) => CheckboxListTile(
                      title: Text(p['name']),
                      value: active.contains(p['id']),
                      onChanged: (value) => update(() {
                        if (value == true) {
                          active.add(p['id']);
                        } else {
                          active.remove(p['id']);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await run(
        () => c.command('room:configure', {
          'settings': values.map((k, v) => MapEntry(k, int.tryParse(v))),
          'activeIds': active.toList(),
        }),
      );
    }
  }

  void voiceAudioChanged() =>
      GameAudio.instance.voiceActive(voice.connected || voice.joining);
  Future<void> settings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              const AudioSettings(),
              ListTile(
                leading: const Icon(Icons.router_outlined),
                title: const Text('Server connection'),
                onTap: connectionSettings,
              ),
              const Divider(),
              const ListTile(
                leading: BrandMark(size: 44),
                title: Text(Brand.name),
                subtitle: Text(
                  'Original card tables. Virtual points only. No deposits, withdrawals, payments or cash conversion.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> connectionSettings() async {
    final result = await form(
      'Connection settings',
      {'URL': c.endpoint},
      descriptions: const {'URL': 'Server URL (changing it signs you out)'},
    );
    if (result != null) {
      await run(() async {
        await voice.leave();
        await c.setEndpoint(result['URL']!);
      });
    }
  }

  Future<void> profile() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avatars[c.user!['avatar']] ?? '🪁',
                style: const TextStyle(fontSize: 48),
              ),
              SectionTitle(
                c.user!['name'],
                subtitle: 'Guest profile · saved on this device',
              ),
              ListTile(
                title: const Text('Hand history'),
                onTap: () {
                  Navigator.pop(context);
                  showData('Game history', '/history');
                },
              ),
              ListTile(
                title: const Text('Virtual balance transactions'),
                onTap: () {
                  Navigator.pop(context);
                  showData('Transactions', '/transactions');
                },
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  run(() async {
                    await voice.leave();
                    await c.logout();
                  });
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showData(String title, String path) async {
    await run(() async {
      final data = await c.request(path) as List;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (data.isEmpty)
                  const Panel(
                    child: Text(
                      'Nothing here yet. Completed hands and transactions will appear here.',
                    ),
                  ),
                ...data.map((item) {
                  if (path == '/rooms') {
                    return Panel(
                      child: ListTile(
                        title: Text(item['name']),
                        subtitle: Text('Code ${item['code']}'),
                        onTap: () {
                          Navigator.pop(context);
                          run(() async {
                            await voice.leave();
                            await c.resumeRoom(item['id']);
                          });
                        },
                      ),
                    );
                  }
                  if (path == '/transactions') {
                    return Panel(
                      child: ListTile(
                        title: Text(
                          '${item['kind']} · ${item['amount']} points',
                        ),
                        subtitle: Text(
                          'Balance ${item['balance_after']}\n${item['created_at']}',
                        ),
                      ),
                    );
                  }
                  return Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['result']['kind']} · ${item['result']['pot']} virtual points',
                          style: const TextStyle(color: gold, fontSize: 18),
                        ),
                        Text('${item['date']}'),
                        const SizedBox(height: 10),
                        ...((item['players'] as List).map(
                          (p) => Text(
                            '${p['id'] == c.selfId ? 'You' : p['name'] ?? 'Player'} · start ${p['startingBalance']} + added ${p['added']} − paid ${p['contributed']} + won ${p['won']} = ${p['finalBalance']}',
                          ),
                        )),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    });
  }
}
