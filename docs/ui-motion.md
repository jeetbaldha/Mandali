# Visual design and motion

The Flutter UI uses an emerald, midnight and warm-gold palette, layered panels,
a drawn felt table with a metallic rail, custom card backs and a fanned-card brand
emblem. All artwork is native Flutter drawing; no image downloads or additional
animation packages are required.

Motion is coordinated around actual state changes:

- Brief branded launch sequence and fanned-card entrance.
- Fade/slide entrances when entering a screen or starting a new hand.
- Tactile button press feedback and Material selection transitions.
- Staggered player-seat arrivals and active-turn/speaker glow transitions.
- Clockwise card flight when the server supplies the first dealt hand.
- Perspective card reveal and animated card entrance.
- Animated virtual-pot totals and a small contribution indicator.
- Smooth server-deadline ring and changing countdown digits.
- Phase banners for decisions, Show, reveal, voting and results.
- Finite trophy/confetti celebration and automatic scroll to the finished result.

Decorative effects do not intercept table input, trigger commands, or change game
rules, cards, contributions or timers. The client still uses server state for all
gameplay. Finite animations settle instead of running continuous background loops.
The system's reduced-motion/accessibility preference disables decorative travel,
card rotations, confetti motion and number interpolation.

Implementation: `lib/ui/motion.dart`, `table_effects.dart`, `widgets.dart`,
`table.dart`, `shell.dart` and the shared application theme in `theme.dart`.

