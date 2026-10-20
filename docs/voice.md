# Live voice configuration and verification

The Flutter client uses LiveKit's WebRTC SFU SDK. It supports microphone mute,
speaker playback on/off, push-to-talk, local per-player mute (tap a table seat),
active-speaker highlights and SDK connection/reconnection states. Microphone starts
muted. Join voice explicitly in a room; permission is requested when enabling it.
Backgrounding the application mutes the microphone. Foreground voice reconnection
uses the SDK's reconnection handling; re-enable the microphone when ready.
No camera or screen sharing is exposed.

Set these in the repository root `.env`, then restart the Node server:

```dotenv
LIVEKIT_URL=wss://your-livekit-host
LIVEKIT_API_KEY=your-server-api-key
LIVEKIT_API_SECRET=your-server-api-secret
```

Use a LiveKit Cloud project or a self-hosted LiveKit server with working TLS and
TURN. The keys belong only on the backend. The app calls `/voice/token` using its
guest bearer token; the backend checks room membership and grants microphone-only
publish and subscribe access scoped to the exact room UUID. Missing configuration
produces an explicit message; card gameplay remains functional.

Leaving room membership queues a durable voice revocation. The backend worker calls
LiveKit's remove-participant API with a token revocation timestamp and retries failed
requests. Rejoining cancels pending removal. Verify token revocation support on your
chosen LiveKit server version as part of the device release checks.

Official setup and API references:
- [Flutter quickstart](https://docs.livekit.io/transport/sdk-platforms/flutter/)
- [Flutter SDK reference](https://docs.livekit.io/reference/client-sdk-flutter/)
- [Self-hosting](https://docs.livekit.io/transport/self-hosting/)

Before release, test on two physical Android/iOS devices on separate networks:
microphone permission denial/retry, echo/headsets, simultaneous speakers, mute,
push-to-talk release/cancel, per-player local mute, network switching, background/resume,
and a 10-participant call. Configure TURN for restrictive networks and verify that a
revoked/left participant cannot retain voice access. This environment has no provider
credentials, so real audio transport has not been verified.

Android microphone/internet/audio permissions and iOS microphone/local-network usage
descriptions are included. Speaker off silences remote playback; it does not mute the
local microphone. Local player mute affects only the listener. SDK speaker detection
is derived from actual audio, not client-submitted game commands.
