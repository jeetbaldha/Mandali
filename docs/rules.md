# Confirmed game rules

- One standard 52-card deck, no jokers; cryptographic server shuffle.
- Minimum 3 active players; default maximum active seats 6, configurable to 10;
  room membership maximum 10.
- Host selects active seats. Dealer selects equal cards per player before each hand.
  Server deals one card to each seat in dealer order, repeating for the chosen count.
- Dealer rotates to the next selected seat for the next hand, not each payment round.
  Current dealer must press Deal. Cards stay the same across payment rounds.
- Dealer acts first, followed by seat order. Blind and Play both pay the whole call.
  Play reveals own cards; See reveals them without an additional payment. Blind keeps
  unseen cards hidden. A player who has seen cards cannot make them unknown again.
- Calls are `startingCall + increment × (round − 1)`. Every call is a NEW contribution.
  Fold pays nothing for that round and retains all previous contributions in the pot.
- Defaults: 500 starting points, call 20, increment 20, Show available after round 3,
  15-second turns, 20-second review. Turns may be 10 or 15 seconds; review 15–20.
- Low balance does not immediately fold. Add virtual points or Fold during the same
  turn timer. Unanswered decision turns Fold on expiry. Additions have separate
  ledger entries and do not inflate the pot or game winnings.
- After a completed payment round at/after Show eligibility, each remaining player
  gets a Show/Continue turn. Any Show begins reveal immediately; expired Show turns
  continue. If all continue, the next increased payment round begins.
- Only non-folded hand participants reveal, vote, win or share a draw. Folded players
  remain spectators with voice and can be selected for a subsequent hand.
- Reveal lasts the configured interval. Voting lasts 20 seconds, even when all
  ballots arrive early. No self-votes, no vote edits, no live counts.
- Draw needs strictly more than half of eligible players. Otherwise the unique
  player with the most positive candidate votes wins. Abstentions are ignored for
  candidate scoring and do not count toward Draw. Missing votes abstain.
- Tied leaders enter one tie-break with the original electorate and only tied
  candidates. Repeated ties or no positive candidate votes pause with the pot intact.
  The host may reopen voting; the host cannot unilaterally assign a winner.
- Draw divides integer points among eligible players. Remainder points go one at a
  time in seat order starting with the dealer's position.
- One remaining player receives the pot automatically. Zero remaining players pause
  with the pot intact. Normal sequential folding settles at one, so zero is defensive.
- Balances carry into the next hand; results distinguish start, additions, contributions,
  winnings, net gameplay change and final balance. No points have monetary value.

Operational boundaries: additions cap the resulting balance at 1 billion points;
call amounts above that pause the hand. A dealer who never deals leaves the hand
waiting, preserving state. No emergency arbitrary payout/refund rule is implemented.
Disconnected players keep their seats. Explicit membership leave is available between
hands; disconnecting during a hand leaves the normal server turn/timeout rules active.
