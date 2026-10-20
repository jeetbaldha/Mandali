# Verification record

## Cleanup and regression checks — 2026-10-20

- TypeScript compilation passed; all 49 backend unit tests passed.
- Flutter analysis and Dart analysis of lib, test, and integration_test passed.
- All 7 Flutter tests passed, including two new regression tests that failed
  before fixing delayed practice refreshes overwriting newer socket state.
- Practice refreshes now discard responses when state, authentication, or the
  active refresh has changed, and ignore responses after disposal.
- Unrelated PDF/resume working files, logs, and a loose screenshot were moved
  outside the project into `C:\Users\LENOVO\Mandali_Cleanup_Backup_20261020`.
- Identical platform icons and configuration files were retained because their
  platform-specific paths are required. Generated build output was removed.
- Database integration tests could not run because Docker is stopped.
  Device gameplay, live voice, and release builds were not retested.

## Resumed verification — 2026-10-03

- TypeScript compilation: passed.
- Backend unit tests: all 49 passed, including solo Teen Patti and Poker,
  hand evaluation, side pots, action authorization and point conservation.
- Flutter static analysis: passed with no issues.
- Flutter widget tests: all 5 passed.
- Android debug APK: rebuilt successfully with the current solo, branding and
  audio changes. LiveKit/WebRTC still report the KGP future-compatibility warning.
- Database integration tests were not rerun: the Docker engine is stopped.
- Live audio, physical-device behavior and iOS remain unverified.

## Earlier verification

Validated on the existing Windows workstation and Android emulator:

- TypeScript compilation: passed.
- Backend unit tests: 26 passed (deck, payments, privacy, turns, timers, Show,
  voting, ties, Draw, deterministic remainder, dealer rotation and conservation).
- PostgreSQL migration runner: applied migrations and successfully reran them.
- Real PostgreSQL + Socket.IO integration suite: passed, exercising 2-player start
  rejection, 3/5/6/10 members, capacity, authorization, private reconnect snapshots,
  duplicate/conflicting commands, virtual additions, settlement and process recovery.
- Flutter static analysis: passed.
- Flutter widget tests: 5 passed, including 3/6/10-seat layouts at mobile width.
- Android debug APK: compiled successfully.
- Android emulator end-to-end integration test: passed. Three real guest identities
  joined a room, each paid 20 virtual points, requested Show, waited 15 seconds,
  voted through a 20-second hidden ballot, and split the 60-point pot. Verified
  history and safe rendering after another player left the finished hand.

Not yet verified: live provider audio, physical-device network switching and headset
behavior, iOS build/signing, production load, store submission or security audit.
The Flutter tool reports a future-compatibility warning for Kotlin Gradle Plugin
usage in the current LiveKit/WebRTC plugins; the present Android build succeeds.


UI refresh: emerald/gold styling, startup and screen entrances, dealt-card flight,
card flip, pot count-up, countdown ring, active-seat glow and result celebration.
Reduced-motion and finite-animation checks passed. The emulator full-hand test
was rerun successfully after an emulator disconnect; no game rules were changed.

