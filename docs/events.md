# HTTP and Socket.IO protocol

All currency is integer **virtual points**. Send JSON only. Unknown command fields are
rejected. Server defaults are in `server/src/engine/game.ts`; schemas are in `app.ts`.

## Authentication and HTTP

`POST /session/guest` accepts `{name, avatar}` and returns `{token, user}`. Names are
1–30 characters; avatar is peacock, lion, lotus, kite, sun or moon. The random bearer
token expires after 30 days; only its SHA-256 hash is stored. Store it in device secure
storage. Losing it loses access to that guest identity; account recovery is not implemented.

Use `Authorization: Bearer <token>` for:

| Route | Result |
|---|---|
| GET /session | Authenticated player identity |
| GET /rooms | Up to 20 recent rooms where the player is a member |
| GET /history | Up to 50 completed hands the player participated in, with results and closed ballot totals |
| GET /transactions | Latest 100 of the player's ledger entries |
| POST /voice/token `{roomId}` | Room-scoped microphone-only LiveKit access token and URL |

`GET /health` is public; returns 503 when PostgreSQL is unavailable.

## Socket connection

Connect using `auth: {token}`. Every incoming packet revalidates the session.
Commands are limited to 60 packets per 10 seconds per connection, with a 16KB maximum
packet. HTTP uses IP rate limits (120/minute, guest creation 30/hour). These are basic
abuse controls, not a distributed anti-abuse service.

All mutation events use this envelope:

```json
{
  "commandId": "fresh UUID, reused for exact retries",
  "roomId": "room UUID",
  "version": 7,
  "payload": {}
}
```

Omit `roomId` and `version` for room creation and join. All other mutations require
the latest snapshot version. Acknowledgments are `{ok:true,roomId}` or
`{ok:false,error}`. Exact retries do not reapply mutations and return current state;
reuse with different payloads fails. On `STALE_STATE`, sync before deciding whether
to issue a fresh command. Never automatically rebase a late game action.

| Event | Payload | Authorization / behavior |
|---|---|---|
| room:create | `{name,balance?}` | Creates room and host; initial points default to 500 |
| room:join | `{code,balance?}` | Maximum 10 seats; joins in-progress hands as spectator |
| room:configure | `{settings,activeIds}` | Host only, before start or after result |
| room:leave | `{}` | Between hands; releases membership, transfers host to lowest occupied seat |
| game:start | `{}` | Host only, 3+ active seats; creates next hand, rotates dealer |
| game:deal | `{cardCount}` | Current dealer only; count × seats must be ≤52 |
| game:action | `{action}` | Current turn only; BLIND/PLAY/FOLD or SHOW/CONTINUE depending on phase |
| game:see | `{}` | Remaining participant sees own cards, no charge |
| balance:add | `{amount}` | Adds positive virtual points to actor's balance, separately audited |
| show:vote | `{choice}` | Another eligible player UUID, DRAW or ABSTAIN; one immutable vote per ballot |
| show:reopen | `{}` | Host reopens an unresolved paused ballot; cannot assign a winner |

`settings` is the complete object: `activeLimit` (3–10), `startingBalance` (0–1 billion),
`startingCall` and `increment` (1–100,000), `showAfter` (1–100),
`decisionSeconds` (10 or 15), `reviewSeconds` (15–20).
Starting balance changes apply to future joins, not existing balances.

Other events:

| Event | Direction | Data |
|---|---|---|
| room:sync | client → server | `{roomId}`, acknowledged; authenticates membership and subscribes this socket |
| room:disconnect | client → server | `{roomId}`, acknowledged; stops this socket's updates but retains seat and running turn |
| game:state | server → client | Personalized room snapshot, version, selfId, serverTime and presence |
| voice:status | client → server | `{roomId,mic,speaker}`; subscription required |
| voice:status | server → client | `{playerId,mic,speaker}`; informational, not game authority |
| server:error | server → client | Rate-limit error before disconnect |

The client subscribes to one table at a time. Returning to another room uses sync.
Joining/dealing/rounds/pot/reveal/results are represented by **one versioned snapshot**
rather than separate events that can arrive in inconsistent combinations.

## Privacy and clocks

Snapshots contain player status, pot, call, round, dealer, turn queue, phase,
`startTime`, `endTime` and server epoch time in milliseconds. Hidden hands are empty
arrays with the hand's shared card count available separately. Own blind cards stay
empty until See/Play. Opponent hands appear only at Show. Folded hands are never
publicly revealed. Open ballots expose only the recipient's own submitted choice;
counts appear only after that ballot expires. History omits private cards entirely.

Timers are enforced on receipt with server time. The Flutter countdown uses the
snapshot's server clock offset; device clock changes do not authorize actions.

## Persistence and recovery

Room row locks serialize commands. State, normalized ledger, votes, actions and
deduplication keys commit together. The timer worker scans persisted deadlines every
250ms. After a server restart, an overdue phase expires once and the next player gets
a full turn. Disconnected seats keep their server state and normal timeout behavior.
No client state is accepted for recovery.

One server process holds a PostgreSQL advisory authority lock. Multi-process serving
is intentionally refused; horizontal scaling needs a shared Socket.IO adapter and
room ownership partitioning before removing that safeguard.
