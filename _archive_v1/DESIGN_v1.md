# Tether — core mechanic prototype

Run `Scenes/prototype.tscn` (it is the main scene). Primitive shapes only.

| Input | Keyboard | Gamepad |
|---|---|---|
| Move | A / D, arrows | Left stick, D-pad |
| Jump | Space / W / Up | A |
| Hook / let go of ring | J | RB |
| Reel in (hold) | K | RT |
| Slack out (hold) | L | LT |
| Sever (hold 1s) | Q | Y |
| Restart / debug | R / F1 | Start |

## How the cord works (one rule, four verbs)

The cord is a **one-sided spring** along the path *player → [ring] → companion*. A ring
is a frictionless **pulley**: the same tension pulls both ends, so the heavier companion
is a counterweight. All forces are measured in **W = one player-weight**.

**Bracing** is the rule everything else grows from: a body standing on ground ignores the
cord until tension exceeds its grip. Read the thresholds as a ladder:

```
0 W ── 1.0 you hanging ── 1.4 walking pull ── 1.5 companion hanging
    ── 2.6 COMPANION GRIP ── 2.8 YOUR GRIP ── 3.2 REEL MAX ── 4.2 BREAK (for 0.35s)
```

- Walking can't drag them (1.4 < 2.6), so they follow at their own pace.
- You can hang off a ledge from them (1.0 < 2.6) — they are your anchor.
- You can hold them when they dangle (1.5 < 2.8) — you are theirs.
- Reeling beats their grip (3.2 > 2.6) — reeling is how you move them on purpose.
- A hard, pumped swing or long fall can exceed 2.6 → they get yanked off their feet.
- Sustained > 4.2 W snaps the cord (short jolts are forgiven by the 0.35 s window).

Verbs that emerge:
- **Anchor & Swing** — hook a ring, swing. Companion plants its feet while you're hooked.
- **Reel & Pull** — haul them up ledges and over gaps; or haul yourself up to them / a ring.
  Through a ring, reeling lifts *whichever end is lighter or unplanted* — sometimes you.
- **Slack & Drift** — pay out cord to reach further / lower them gently.
- **Sever** — hold Q for 1 s. You become *unburdened* (1.2× speed, 1.56× jump height) and
  the companion greys out and sits. Permanent for the run. Different ending.

## Game-feel decisions (and why)

| Decision | Value | Why |
|---|---|---|
| Jump defined by height/time | 104 px, 0.36 s to apex | Designer-readable; gravity derived (≈1605) |
| Fall gravity multiplier | 1.6×, **off while cord is taut** | Snappy falls normally, but a clean symmetric pendulum when swinging |
| Coyote / jump buffer | 0.10 s / 0.12 s | Industry-standard forgiveness; precision isn't the point |
| Variable jump | release = 0.45× upward velocity | Short hops for fine placement |
| Swing control | input pumps *along the arc* (520 px/s²) | Steering in x fights the pendulum and feels mushy |
| Hooked + airborne | cord auto-takes-up slack | Without it you free-fall then jolt (~4 W), which yanked the companion off every time. Paying out is always deliberate (L). |
| Swing release | Jump or J; jump adds 0.55× pop and 1.1× x-speed; above-run-speed momentum decays slowly (260 px/s²) | Swing launches must feel *earned* |
| Hooking | cord snaps to current path length | Immediate catch; a free-fall before the hook bites feels unresponsive |
| Companion while you're hooked | plants feet | Otherwise its follow-walk feeds you slack mid-swing |
| Companion edge stop | 14 px back from drops, firm stop | Stopping at the very lip let tiny jolts roll it off the circular collider's corner |
| Cord relax | reeled-in cord eases back to 180 px when both stand | Otherwise a short cord drags every step |
| Ledge lip | cord against a wall pulls straight up | Stand-in for real rope wrapping, so hauling over a ledge works |
| Juice | squash/stretch on jump & land, cord thins + reddens + trembles with strain, companion shakes when dragged, "…" when waiting at an edge | Tension must be *readable without the debug bar* |

## Difficulty stance: "gentle precision"

The challenge is **managing tension**, not frame-perfect jumping.
- Respawn is instant (fade ~1 s) at the last checkpoint; no lives.
- Falls are mostly caught by the cord — death is rare and usually a choice/mistake chain.
- Checkpoints only bank when the companion is within 220 px, so you can't die to teleport them forward past a puzzle.
- Measured (scripted playtests): the gap swing lands for any release in a ~20-frame window; the ring lift onto the high ledge succeeded in 12/12 timing combos. Both are deliberately forgiving for a tutorial.
- The *together* route at the end takes ~15 s of hook-reel-haul; severing takes ~2 s. Making the selfish option obviously cheaper is the point.

## Level (teaching gym, left → right)

1. Walk — companion follows, can't jump.
2. 64 px step — reel them up (teaches: stand near the edge, planted feet).
3. 280 px gap + ring — hook, swing, release; then pulley/reel them across (rescue).
4. Crumbling bridge — they will fall; catch and haul.
5. 150 px wall + ring — lift both with the pulley (slow) **or** sever and jump alone (fast).
6. "A still place" — ending depends on whether you arrived together.

Everything is editable in the editor: `Block`/`CrumbleBlock` (top-left + `size`),
`TetherAnchor` (shows its hook range), `Zone` (kill / checkpoint / goal). All tuning values
are `@export` on Player, Companion and Tether — select the node and tune in the Inspector
with F1 debug open.

## Open decisions for you

1. **What does Slack *do* for the companion?** Right now it only pays out cord. The concept
   says slack lets the companion move *independently* (unlocking routes). Proposal: while
   slack exceeds X, the companion pursues its own goal markers (e.g. toward a light),
   which can pull *you* into danger. Biggest remaining gap vs. the concept.
2. **Strain break = checkpoint retry (current) or a terminal ending** ("Begin again?")?
   Terminal is stronger thematically but punishing for a 5-minute piece.
3. **Should the Sever be offered earlier, as a temptation in every section** (e.g. a
   shortcut in each), or only once at the end (current)?
4. **Real rope wrapping** around corners (raycast + pivot list) vs. the current straight
   cord + lip rule. Wrapping looks better and enables "wrap around a post" puzzles; costs a day.
5. **Mass ratio** (1 : 1.5). Raising the companion's mass makes pulley puzzles weightier but
   makes swings yank them more often.
