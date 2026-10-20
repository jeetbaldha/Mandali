# Mandali Flutter client

This is the existing Flutter Android/iOS project, now connected to the multiplayer
card-game backend in `../server`. Platform identifiers and native project files
were preserved; microphone permissions and secure-storage configuration were added.

See the [repository setup guide](../README.md), [confirmed rules](../docs/rules.md),
[voice configuration](../docs/voice.md) and [verification record](../docs/verification.md).

```powershell
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:3000
```

Start PostgreSQL and the Node server first, following the repository setup guide.
All amounts are virtual points with no cash value.
