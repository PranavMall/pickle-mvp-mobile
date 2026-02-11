# Claude Code Prompt — Pickleball Mobile MVP (Godot 4.4.1)

Use this as your initial prompt / CLAUDE.md when starting Claude Code sessions for this project.

---

## Project Overview

You are building **pickle-mvp-mobile** — a portrait-orientation mobile pickleball game in **Godot 4.4.1** (GDScript). The goal is to create the **definitive mobile pickleball game**: the first authentic 2v2 doubles pickleball game that sets an industry benchmark.

**GitHub repo:** https://github.com/PranavMall/pickle-mvp-mobile

## Core Design Pillars (Non-Negotiable)

1. **True 2v2 Doubles** — All 4 players on court (player, AI partner, 2 AI opponents) with proper positioning, court coverage, and doubles-specific rules. This is unprecedented in racquet sport mobile games.
2. **Portrait Orientation / One-Handed Play** — 1080×1920 resolution, 9:16 aspect ratio. All gameplay is swipe-based with auto-movement. **Zero buttons for gameplay actions** (UI buttons like Kitchen and Mastery are fine).
3. **Authentic Pickleball Rules** — Every official rule implemented: double bounce requirement, diagonal serves to correct service box, kitchen (non-volley zone) violations, server rotation (server 1 → server 2 → side out), scoring only on serve, win by 2 (to 11, cap at 15).
4. **Revolutionary Kitchen System** — 6-state machine (DISABLED → AVAILABLE → ACTIVE → MUST_EXIT → WARNING → COOLDOWN) with a pressure meter (0–100%) that builds through skilled play (dinks, rally wins, kitchen play) and unlocks Mastery Mode (8-second power-up with speed boost, no net faults, perfect dinks).
5. **Paddle-Perfect Physics** — Custom 2D physics with separate height simulation (not Godot 3D). Ball has gravity (160), bounce (0.65), friction (0.85), and visual height via sprite offset with shadow scaling. Shots should feel like they have "snap" and paddles should have authentic "pop."
6. **Ghibli-Inspired Aesthetic** — Eventually: hand-drawn feel, cherry blossom particles, warm color palette, living environment. For now, clean placeholder sprites are fine but the architecture should support seamless art swap.

## Technical Foundation (Locked Settings)

```
Renderer: Mobile
Orientation: Portrait (9:16)
Target FPS: 60 (non-negotiable)
Resolution: 1080×1920
Input: Touch ONLY
Physics: 2D with custom ball height system
Audio: Low latency for paddle "pop"
```

## Architecture

Single-scene MVP approach with modular systems:

```
res://
├── scenes/main/
│   ├── Main.tscn / Main.gd          # Game controller, court rendering, perspective math
│   ├── GameManager.gd                # Global state (autoload)
│   └── KitchenPressureSystem.gd
├── scenes/court/
│   ├── Court.gd                      # Kitchen zones, service boxes, bounce markers
│   └── PerspectiveRenderer.gd
├── scenes/characters/
│   ├── Player.gd / Partner.gd / Opponent.gd
│   └── PaddleController.gd          # Visual paddle with swing animation
├── scenes/ball/
│   ├── Ball.gd                       # CharacterBody2D with custom height system
│   └── BallPhysics.gd
├── scenes/ui/
│   ├── HUD.gd, KitchenButton.gd, MasteryButton.gd
├── scripts/systems/
│   ├── ServiceRules.gd               # Diagonal serve validation, server rotation
│   ├── ScoringSystem.gd              # Score-on-serve, win by 2, side switching
│   ├── KitchenSystem.gd             # 6-state machine + pressure meter
│   ├── ViolationDetector.gd         # Kitchen violations, momentum carry
│   ├── DinkDetector.gd              # Soft shot detection for pressure building
│   └── MasterySystem.gd             # 8-second power mode
├── scripts/ai/
│   ├── AIBrain.gd                    # Decision-making, positioning, shot selection
│   └── KitchenStrategy.gd           # When to enter/exit kitchen
├── scripts/utils/
│   ├── SwipeDetector.gd             # Touch input → angle, power, shot type
│   └── CourtMath.gd                 # Perspective conversions
└── scripts/autoload/
    ├── GameManager.gd               # Global game state
    └── AudioManager.gd              # Hit sounds, ambient, crowd reactions
```

## Court & Perspective Math

The court uses perspective rendering (75% width at top, 100% at bottom) to simulate 3D depth:

```
COURT_WIDTH = 280     (game units)
COURT_HEIGHT = 560    (game units)
COURT_OFFSET_Y = 60
PERSPECTIVE_SCALE = 0.75
KITCHEN_DEPTH = 70
NET_Y = COURT_HEIGHT / 2  (280)
KITCHEN_LINE_TOP = NET_Y - KITCHEN_DEPTH  (210)
KITCHEN_LINE_BOTTOM = NET_Y + KITCHEN_DEPTH  (350)
```

Screen-to-court and court-to-screen conversions must account for perspective scaling. The court renders as a trapezoid (narrower at top = far side).

## Key Game Mechanics

### Serving
- Only serving team can score
- Server starts on right side when score is even, left when odd
- Serve must go diagonally to correct service box
- Serve must clear the net AND not land in kitchen
- After fault: server 1 → server 2 → side out to other team

### Double Bounce Rule
- Serve must bounce before receiver can hit (first bounce)
- Return of serve must bounce before serving team can hit (second bounce)
- After both bounces, volleys are allowed (except in kitchen)

### Kitchen (Non-Volley Zone)
- No volleys allowed when standing in kitchen
- Momentum cannot carry player into kitchen after a volley
- Feet must be re-established outside kitchen before volleying
- Ball CAN bounce in kitchen and be played after bounce

### Pressure & Mastery System
Pressure builds (0–100%) through:
- Dinks: +5 per dink
- Dink rallies (3+): +15 bonus
- Winning rally on serve: +15
- Long rally (10+ hits): +20
- Opponent kitchen violations: +10

Pressure decreases:
- Player kitchen violation: -20
- Mastery activation: resets to 0

Mastery Mode (8 seconds): 1.3× speed, no net/out faults, perfect dinks, 1.2× power

### Scoring
- Games to 11, win by 2, cap at 15
- Only serving team scores
- Score display: "Player: X | Opponent: Y"

## Swipe Controls

```
Swipe Up: Standard shot (speed/arc based on swipe power)
Soft Forward Swipe: Dink (slow, low arc, lands in kitchen)
Short Swipe: Drop shot (medium speed, high arc)
Long/Fast Swipe: Power shot (fast, flat trajectory)
Tap (no swipe): Serve when waiting
```

Power calculated from swipe distance (max 250px). Angle from swipe direction. Shot type inferred from power + angle combination.

## AI Behavior

### Partner AI
- Covers opposite side of court from player
- Makes strategic decisions based on ball speed/position
- Can enter kitchen for dinks during opportunities
- Skill level ~0.8, speed 95% of player

### Opponent AI
- Both opponents coordinate court coverage
- Decision-making based on skill_level (0.6–0.9)
- Enter kitchen strategically when ball is slow/low near net
- React with configurable reaction_time delay
- Shot selection considers ball speed, height, distance to net, rally length

## Reference Prototype

The working HTML/JavaScript prototype (`prototype_ver_2_1.txt` in the repo/knowledge base) implements all game rules correctly. Use it as the **source of truth** for:
- Service rotation logic
- Scoring rules (score-on-serve, server switching, side out)
- Kitchen violation detection (all 4 priority checks)
- Double bounce enforcement
- Player positioning and court coverage
- Dink mechanics and pressure calculations
- Hit detection and ball physics

When implementing any game mechanic, cross-reference the prototype to ensure accuracy.

## Development Principles

1. **Complete, working code** — Never give partial implementations, snippets, or TODOs. Every file must be complete and functional. I can't afford back-and-forth debugging from incomplete code.
2. **Preserve working functionality** — When adding features, never break existing systems. Use targeted fixes, not comprehensive rewrites.
3. **Test at mobile resolution** — The game is designed for portrait mobile (430×932 or 1080×1920). Testing at desktop resolutions will cause scaling issues.
4. **Pure gameplay testing** — Test through actual swipe/tap interactions, not debug buttons. The game should be playable at every stage.
5. **Incremental progress** — Build and verify one system at a time. Don't try to implement everything at once.
6. **Git-ready code** — All code should be clean, documented, and ready to commit. Include file paths and clear instructions for where each file goes.

## Current State

The project has completed Days 1–5 of development with:
- ✅ Court rendering with perspective
- ✅ Ball physics with height system, trail, shadow
- ✅ Swipe controls (serve + rally hits)
- ✅ Kitchen state machine (6 states)
- ✅ Pressure system (0–100%)
- ✅ Mastery mode activation
- ✅ Service rules with diagonal validation
- ✅ Scoring system (score-on-serve, win by 2)
- ✅ AI for partner and opponents
- ✅ Kitchen violation detection
- ✅ Modular architecture with autoloads

**When picking up work, always check the current state of the codebase in the repo before making changes.** Don't assume — verify what exists.

## What's Next

Remaining development priorities (roughly in order):
1. **Paddle system** — Visual paddles on all 4 characters with swing animations and hit detection
2. **Sound design** — 5+ hit sound variations with power scaling, ambient court audio, crowd reactions, UI sounds
3. **AI enhancement** — Smarter kitchen strategy, difficulty scaling, better shot selection
4. **Tutorial** — Step-by-step onboarding teaching serve, rally, kitchen, and mastery
5. **Visual polish** — Ghibli-inspired art, cherry blossom particles, dynamic environment
6. **Menu system** — Main menu, settings, game flow (menu → game → results → menu)
7. **Performance optimization** — Object pooling, draw call reduction, <150MB RAM, <10% battery/hour
8. **Multiplayer foundation** — Turn-based state sync, peer-to-peer networking
9. **Store submission** — APK/iOS builds, store listings, final polish

## Success Metrics

- Consistent 60 FPS on target devices
- Average rally length: 5–8 shots
- Kitchen used 2–3 times per game
- Mastery activated 1–2 times per game
- Games last 4–6 minutes
- Load time < 3 seconds
- Memory < 150MB
- Battery drain < 10% per hour

## Important Reminders

- **Resolution matters** — Always test at mobile portrait dimensions. The perspective math breaks at desktop resolutions.
- **Ball height is simulated** — The ball moves in 2D with a separate `height` variable that affects the sprite's Y offset and shadow scale. This is NOT Godot 3D.
- **Kitchen is complex** — The kitchen system has 6 states, momentum tracking, feet establishment, and 4 priority violation checks. Don't simplify it.
- **Score-on-serve** — Only the serving team can score. This is fundamental to pickleball. Getting this wrong breaks the game.
- **Doubles positioning** — Partners share a side. Server 1 and Server 2 alternate. Players switch sides after scoring (not after side-outs).
