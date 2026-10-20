# Mandali — private multiplayer card rooms

A Flutter Android/iOS client with an Express + Socket.IO + PostgreSQL backend.
The original Flutter project remains in `card_game_flutter_application/`; its
platform configuration was extended, not replaced. No second Flutter project exists.

**Virtual points only. No deposits, withdrawals, cash prizes, payments or conversion.**

## Implemented

Private room codes, guest sessions, 10-member rooms, host settings and active seats,
dealer-selected card count, secure server dealing, sequential timed turns, blind/see/play/fold,
increasing cumulative contributions, audited balance additions, optional Show, timed
reveal, hidden immutable votes, tie-breaks, Draw splitting, settlement, history,
persistent reconnect/restart recovery and a connected dark Flutter table UI.

Voice uses a LiveKit WebRTC integration with mute, playback control, push-to-talk,
local mute and speaker indicators. It requires provider configuration; no simulated
voice is substituted. This is a working development foundation, not a store-ready release.

## Local setup (PowerShell, from this directory)

1. Copy `.env.example` to `.env` if one does not exist. Choose a PostgreSQL password;
   put the same password in `POSTGRES_PASSWORD` and `DATABASE_URL` (URL-encode special
   characters in the URL). Do not commit `.env`.
2. Start Docker Desktop, then:

```powershell
docker compose up -d
cd server
npm install
npm run migrate
npm run dev
```

PostgreSQL binds to `127.0.0.1:55432` (5432 was blocked on this workstation). The server
listens on port 3000. Health: `http://localhost:3000/health`.

In a second terminal:

```powershell
cd card_game_flutter_application
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:3000
```

Install Flutter and add its `bin` directory to your PATH before running these commands.
Android Studio and VS Code can open the existing Flutter directory.

- Android emulator: `http://10.0.2.2:3000`.
- iOS simulator on the backend machine: `http://localhost:3000`.
- Physical devices: use your backend computer's LAN address, on the same network.
  Allow TCP 3000 through your development firewall if needed.
- Settings in the app can change the server URL; changing it signs out the old session.
- Release builds require an HTTPS API endpoint. Local cleartext is enabled only in
  the Android debug manifest. Use HTTPS for iOS device testing if ATS blocks your URL.
- Three distinct guest identities are needed to start. A second connection using the
  same guest token is the same player, not another seat.

## Solo practice and audio

Choose Solo from the home screen to play Teen Patti or Poker against computer
opponents with 2–10 total seats. Configure virtual starting points, stakes or
blinds, and a 10- or 15-second turn timer. Practice uses the backend and database,
so start the local services before playing. Practice history and transactions
are stored separately from multiplayer rooms.

Settings include sound effects, optional music, haptics, volume and reduced motion.
Brand configuration lives in `branding.json`; `tools/generate_brand_assets.py`
regenerates the bundled icons and synthesized audio.

## Voice configuration

Set `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET` in root `.env`, restart
the server, then press Join voice. Keys are never sent to Flutter. See
[voice setup and verification](docs/voice.md).

## Checks

```powershell
cd server
npm test
npm run test:integration
npm run build
```

Integration tests require PostgreSQL and create/drop only a uniquely named test
schema. They cover real sockets with 2/3/5/6/10 members, room capacity, authorization,
private snapshots, duplicate/conflicting commands, virtual additions, votes, payouts,
disconnect/reconnect and server restart recovery.

```powershell
cd card_game_flutter_application
flutter analyze
flutter test
flutter build apk --debug
```

With the server running and an Android emulator connected, run the full device flow:

```powershell
flutter test integration_test/multiplayer_test.dart -d emulator-5554
```

This uses real guest sessions and a room named `Emulator validation`, pays a hand,
waits through real reveal/voting timers, verifies a Draw payout, and leaves the room.
It does not use mocked networking or a client-side game engine.

Use macOS + Xcode for `flutter build ios --no-codesign`, simulator/device checks and
Apple signing. iOS has microphone usage and secure-storage entitlements configured,
but cannot be built on this Windows workstation.

## Source map

- `server/src/engine/`: cards, ledger, timers and hand state machine.
- `server/src/store.ts`: PostgreSQL transactional state, audit and history.
- `server/src/app.ts`: HTTP/Socket.IO authorization, validation, snapshots and timers.
- `database/migrations/`: versioned SQL schema.
- `card_game_flutter_application/lib/core/`: sessions, reconnect and voice.
- `card_game_flutter_application/lib/ui/`: entry, home, lobby, table, votes and results.
- [Confirmed rules](docs/rules.md), [protocol](docs/events.md), [architecture](docs/architecture.md).

## Release boundaries

The server deliberately allows only one authoritative process. Horizontal scaling
requires a shared Socket.IO adapter and room ownership/leases. Add monitoring, backup
restore drills, load testing, account recovery and retention policies before launch.
Replace the existing example bundle/application IDs and debug release signing with
owned production identifiers and credentials. Test audio on physical Android/iOS
devices and separate networks, including TURN and background behavior.

A paused unresolved vote preserves the pot and lets the host reopen voting; it does
not give the host arbitrary payout power. A missing dealer can leave a hand waiting.
These exceptional admin-resolution policies need explicit product rules before adding
automatic overrides. Guest sessions last 30 days; no recovery exists if a token is lost.
