# Pickleball Mobile MVP — CLAUDE.md

## What This Is
A portrait-orientation 2v2 doubles pickleball mobile game in Godot 4.4.1. Target: Android and iOS.

## The Prototype Is Law
`prototype_ver_2_1.txt` in this folder is a fully working HTML/JavaScript pickleball game. It is the **source of truth** for every rule, every physics value, every coordinate, every game flow. When in doubt, match the prototype exactly. Do not "improve" it. Do not redesign it. Copy its logic.

## Non-Negotiable Rules
1. **ALL code changes go to the main branch.** No worktrees, no separate branches. I test by deploying directly to my Android phone from Godot.
2. **Complete files only.** Never give partial snippets or "add this to line 47." Always provide the full file.
3. **Test each change before moving on.** Don't build Phase 2 on broken Phase 1.
4. **The prototype's variable names, constants, and flow should be preserved** in the GDScript translation wherever possible.

## Technical Setup (Already Configured)
- Godot 4.4.1, Mobile renderer
- Viewport: 430×932 (scales to any phone via canvas_items stretch)
- Portrait orientation (9:16)
- Android export templates installed
- Android SDK, Java 17, debug keystore configured
- I test by USB-deploying to my Android phone

## Court & Perspective (From Prototype — Do Not Change)
```
COURT_WIDTH = 280
COURT_HEIGHT = 560
COURT_OFFSET_Y = 60
PERSPECTIVE_SCALE = 0.75
KITCHEN_DEPTH = 70
NET_Y = 280 (COURT_HEIGHT / 2)
KITCHEN_LINE_TOP = 210 (NET_Y - KITCHEN_DEPTH)
KITCHEN_LINE_BOTTOM = 350 (NET_Y + KITCHEN_DEPTH)
```

## Ball Physics (From Prototype — Do Not Change)
```
GRAVITY = 160
BOUNCE_DAMPING = 0.65
FRICTION = 0.85
HIT_DISTANCE = 60
HIT_COOLDOWN = 800ms (0.8 seconds)
Ball height check for can_hit: height < 40
```

## Shot Types (From Prototype — Do Not Change)
```
Dink:   speed=80,  arc=60
Drop:   speed=100, arc=140
Power:  speed=320, arc=80
Normal: speed=220, arc=100
```

## Scoring Rules
- Only the serving team can score
- Games to 11, win by 2
- Score format: YOUR_SCORE - OPPONENT_SCORE - SERVER_NUMBER
- Server rotation: Server 1 faults → Server 2. Server 2 faults → Side Out.
- First serve of game: start with Server 2, so first fault = immediate side out
- After scoring: serving team players switch sides (left/right) based on score parity

## Kitchen System (6 States)
DISABLED → AVAILABLE → ACTIVE → MUST_EXIT → WARNING → COOLDOWN

## Pressure Values (From Prototype)
```
Dink: +15, Power shot: -5 (penalty), Drop: +5
Long rally (>10 hits): +20, Win point: +15
Kitchen violation: -20, Opponent violation: +10
Kitchen entry: +5, Re-establish feet: +10
Normal shot: +0 (no pressure)
```

## Mastery Mode
- Activates at 100% pressure, lasts 8 seconds
- Benefits: speed × 1.3, no net faults, no out of bounds (ball bounces back), perfect dink accuracy
- Dink bonus during mastery: speed × 1.2, arc × 0.8

## What Has Failed Before (Learn From This)
1. **Distributed architecture** — splitting game state across 6+ scripts with signal-based communication caused state sync bugs that passed unit tests but failed in gameplay. Keep state centralized.
2. **Screen vs court coordinate confusion** — the ball physics must work in COURT coordinates (matching the prototype), then convert to screen coordinates only for rendering. Previous versions mixed these up, causing every ball to land at position (162.8356, 0.0).
3. **AI hits bypassing ball physics** — previous versions had AI set ball velocity directly with hardcoded values instead of using the same hit function as the player. All hits must go through the same physics system.
4. **Working on branches I couldn't test** — code was pushed to branches I didn't know about. Everything must go to main.
5. **Building features on broken foundations** — adding kitchen systems, mastery, visual effects before basic serve-rally-score worked. Build incrementally and verify each layer.

## Mobile-Specific Requirements
- Touch/swipe input must work on Android (InputEventScreenTouch, InputEventScreenDrag)
- All Control nodes must have mouse_filter = MOUSE_FILTER_IGNORE to not block touch
- UI elements must be large enough to read and tap on a 6-inch phone screen
- Auto-scale editor window for desktop testing (detect screen size, maintain 430:932 aspect ratio)

## Development Order
Phase A: Court rendering + ball physics + basic serve that lands in the right box
Phase B: Player swipe input + AI returns + basic rally loop (serve → return → return → repeat)  
Phase C: Scoring + server rotation + side switching (all matching prototype)
Phase D: Kitchen system + pressure + mastery
Phase E: UI polish (sizing, positioning for phone)
Phase F: Visual effects, particles, shaders

DO NOT start a phase until the previous one is verified working on my Android phone.
