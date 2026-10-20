import 'package:flutter/material.dart';

import '../core/theme/brand.dart';
import 'widgets.dart';

class ModeHome extends StatefulWidget {
  final String name;
  final bool connected;
  final VoidCallback onCreate,
      onJoin,
      onSolo,
      onRooms,
      onHistory,
      onPracticeHistory,
      onSettings;
  const ModeHome({
    super.key,
    required this.name,
    required this.connected,
    required this.onCreate,
    required this.onJoin,
    required this.onSolo,
    required this.onRooms,
    required this.onHistory,
    required this.onPracticeHistory,
    required this.onSettings,
  });
  @override
  State<ModeHome> createState() => _ModeHomeState();
}

class _ModeHomeState extends State<ModeHome> {
  bool online = false;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Row(
        children: [
          BrandMark(size: 64),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              Brand.name,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: Brand.ivory,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      Text(
        'KEM CHO, ${widget.name.toUpperCase()}',
        style: const TextStyle(fontSize: 11, letterSpacing: 2, color: gold),
      ),
      const SectionTitle(
        'A place at the table.',
        subtitle: 'Choose your way to play.',
      ),
      _ModeLane(
        number: '01',
        title: 'PLAY ONLINE',
        subtitle: 'Your people. Your rules.',
        detail: 'Create or join a room · live voice',
        icon: Icons.groups_outlined,
        onTap: () => setState(() => online = !online),
      ),
      if (online)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: widget.connected ? widget.onCreate : null,
                icon: const Icon(Icons.add),
                label: const Text('Create room'),
              ),
              OutlinedButton.icon(
                onPressed: widget.connected ? widget.onJoin : null,
                icon: const Icon(Icons.login),
                label: const Text('Join with code'),
              ),
              const Text(
                'Custom Gujarati game · 3–10 active players · Show & voting',
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      _ModeLane(
        number: '02',
        title: 'SOLO / PRACTICE',
        subtitle: 'Find your rhythm.',
        detail: 'Teen Patti or Texas Hold’em · 2–10 seats',
        icon: Icons.style_outlined,
        onTap: widget.onSolo,
      ),
      const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 20),
        child: Text(
          'Private practice uses game-controlled participants. Both modes currently require a connection.',
          style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.5),
        ),
      ),
      const Divider(),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.restore),
        title: const Text('Rejoin an online room'),
        trailing: const Icon(Icons.arrow_forward, size: 18),
        onTap: widget.onRooms,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history),
        title: const Text('Online game history'),
        onTap: widget.onHistory,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.auto_stories_outlined),
        title: const Text('Practice history'),
        onTap: widget.onPracticeHistory,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.tune),
        title: const Text('Settings'),
        onTap: widget.onSettings,
      ),
    ],
  );
}

class _ModeLane extends StatelessWidget {
  final String number, title, subtitle, detail;
  final IconData icon;
  final VoidCallback onTap;
  const _ModeLane({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: number == '01' ? const Color(0xff193c32) : const Color(0xff2c3026),
    shape: BeveledRectangleBorder(
      side: const BorderSide(color: Color(0xff85724a)),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  number,
                  style: const TextStyle(color: gold, letterSpacing: 2),
                ),
                const Spacer(),
                Icon(icon, color: gold, size: 28),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Brand.ivory,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xffcfceb9),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward, color: gold),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
