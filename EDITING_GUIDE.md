# Editing guide

Everything below is editable in the Godot **Inspector**. Hover any field for its tooltip.
Changes apply the next time you press **F5 / Run**.

## Where things live

| To change... | Select / open |
|---|---|
| Anything about a **phase** (cord, AI, pull-back, tug, swap, visuals) | `Data/Phases/phase_1_together.tres`, `phase_2_closer.tres`, `phase_3_inseparable.tres` (double-click) |
| A **character** (speed, jump, weight, grip, sprite, reel tremble, bubble colour) | `Wisp` / `Ember` nodes in `Scenes/prototype.tscn` |
| **Cord physics** shared by every phase (stiffness, reel speed, break force, look, sounds) | `Tether` node |
| Phase order, camera, sever bonus, debug keys | Root node (`Sandbox`) |
| Level geometry, rings, checkpoints, phase changes, endings | Nodes under `Level`, `Anchors`, `Zones` |
| Dialogue and scripted events | Nodes under `Dialogue` (DialogueTrigger) |
| Volume, music | Pause menu (Esc) / `SoundManager` autoload / Audio bus panel |

---

## 1. Phase II constraints (cord slack, memory, anxious partner)

Open **`Data/Phases/phase_2_closer.tres`**.

| Group | Field | What it does | Now |
|---|---|---|---|
| Cord | `max_length` | Longest the cord can be in this phase (tightens to it gradually) | 320 |
| | `rest_length` | Length it eases back to when you're both standing | 150 |
| | `comfort` | Beyond this distance you count as "apart" (filter + memory) | 110 |
| Tension memory | `shrink_after` | Seconds apart before the cord starts shortening itself (0 = off) | 1.2 |
| | `shrink_speed` | How fast it shortens, px/s (it never grows back) | 40 |
| | `leash_floor` | Shortest it can ratchet down to | 150 |
| Partner AI | `follow_distance` | How close it stays | 50 |
| | `predict` | How far ahead of you it moves (s of your velocity) | 0.35 |
| | `mirror_jump_chance` | Chance it copies your jump, even into a pit | 1.0 |
| Swap | `control_bleed` | Your input still drives the old body this long after a swap | 0.12 |
| Look & feel | `bleed` / `anxiety` / `floaty` | Look-alike amount / cold filter strength / how mushy your movement gets when apart | 0.35 / 0.8 / 0.5 |

Slack you give with RMB is capped by the current cord ceiling. How fast slack pays out
(`slack_speed`) and how fast you reel (`reel_speed`) are on the **Tether** node, because
they're the same in every phase. Press **F5** in-game to reset the cord memory while tuning.

## 2. Character sprites and animations

Each character draws its placeholder shape until you give it art.

1. Select `Wisp` (or `Ember`). In **Sprite (optional)**, click `sprite_frames` → **New SpriteFrames**, then click it to open the SpriteFrames panel at the bottom.
2. Create animations with these exact names (only `idle` is required; any missing one falls back to `idle`):

   | Name | Plays when |
   |---|---|
   | `idle` | standing still |
   | `run` | walking (faster than `run_anim_threshold`) |
   | `jump` / `fall` | airborne, going up / coming down |
   | `swing` | airborne on a taut cord (hanging, swinging) |
   | `reel` | planted and hauling the other one in |
   | `dragged` | being dragged along the ground by the cord |
   | `stagger` | yanked by a phase III tug |
   | `left_behind` | the one you abandoned after severing |

3. Drag frames in, set FPS and loop per animation.
4. Line it up: `sprite_offset` moves the art relative to the body, `sprite_scale` resizes it, and `sprite_faces_right` says which way your art faces (it flips automatically).
5. Make the **collision** match the art: `shape` (RECT/CIRCLE) and `size` on the same node.

What still works with sprites: jump/land squash, the reel tremble, flipping into the partner's
art during a phase III swap glitch (if both have sprites), the colour bleed tint, and greying
out when left behind. The "you" marker and "..." still draw on top.

## 3. Phase III pull-back and tug

Open **`Data/Phases/phase_3_inseparable.tres`**.

**Pull-back** is the partner planting its feet when you start to leave, so the cord holds you.

| Field | What it does | Now |
|---|---|---|
| `hold_on_chance` | Chance it holds on each time you start walking away (0-1) | 1.0 |
| `hold_on_time` | How long it holds each time; longer means a harder pull | 0.45 s |
| `hold_on_cooldown` | Minimum gap between hold-ons. **This is the frequency knob**: raise it to pull back less often | 0 s |

**Tug** is the yank you feel when you pull away against it.

| Field | What it does | Now |
|---|---|---|
| `tug_enabled` | On/off | on |
| `tug_force` | How hard you must pull away before it counts (W = one Wisp-weight). Lower = tugs more easily | 1.3 |
| `tug_impulse` | Strength of the yank back (px/s) | 300 |
| `tug_stagger` | How long you lose control after a tug | 0.22 s |
| `tug_cooldown` | Minimum time between tugs | 0.9 s |
| `panic_time` | How long the partner panics afterwards (closes in, jumps blindly) | 1.2 s |
| `tug_camera_shake` | Screen shake per tug (px) | 6 |

Related in the same file: `max_length` 120 (the short leash), `follow_distance` 30,
`swap_delay` 0.3 (new body hesitates), `control_bleed` 0.3 (old body still obeys you).
Use **F4** (slow-motion) to watch a tug frame by frame.

---

## 4. Other tools

### Phases
- Any phase can use any behaviour: e.g. give phase II a mild tug (`tug_enabled`, high `tug_force`) or phase I a little `predict`.
- **Add a phase IV:** duplicate a `.tres`, edit it, add it as the 4th entry of the root's `phase_profiles`, and place a PHASE zone with `phase = 4`.
- Phases only escalate; the cord's memory survives respawns.

### Debug keys (root → Debug → `debug_tools`; turn off before sharing a build)
| Key | Does |
|---|---|
| F1 | Toggle the readout (tension bar, cord length/cap, who's planted) |
| F2 | Jump to the next phase |
| F3 | Teleport both to the next checkpoint (wraps around) |
| F4 | Slow-motion toggle (`slow_motion_scale`, default 0.25) |
| F5 | Reset cord memory to the phase maximum |

### Dialogue and scripted events (DialogueTrigger)
- `activated_by`: EITHER character, only the CONTROLLED one, or BOTH inside together.
- `one_shot`: untick to replay every time.
- Steps you can add: **DialogueLine** (speech bubble, BBCode), **DialogueCall** (call a method),
  **DialogueWait** (pause N seconds), **DialogueMusic** (start/stop music or ambience; empty stream = stop).
- Methods on the root node made for DialogueCall (drag the root onto `target`):

  | Method | Args | Use |
  |---|---|---|
  | `lock_input` | seconds | Cutscene: ignore the player for a while |
  | `shake_camera` | amount | Emphasis |
  | `go_to_phase` | phase number | Escalate the relationship at a story beat |
  | `sever_tether` | (none) | Cut the cord from a script |
  | `swap` | (none) | Force a perspective swap |

  Plus anything on HUD, e.g. `show_title(title, subtitle)` or `show_message(text, seconds)`.

### Characters (Wisp / Ember nodes)
`run_speed`, `jump_height`, `time_to_apex` (jump feel), `mass` and `grip` (who holds whom),
`swing_pump`, the **Reel feedback** group (tremble strength/rate, `reel_squash`), `bubble_tint`,
and `speaker` (GIRL/BOY for dialogue).

### Cord, shared (Tether node)
`reel_speed`, `slack_speed`, `reel_max_force`, `reel_brace` (extra grip while reeling),
`break_force` / `break_time` (when it snaps), `stiffness` / `damping` (elasticity),
`anchor_range` (ring hook reach), `sever_hold_time`, plus the **Reel / slack feedback**
group (tints, shimmer, flow dots, `reel_sound` / `slack_sound` and their volumes).

### Root node (Sandbox)
Camera follow speed / lean / look-ahead, `checkpoint_partner_radius`, and
`sever_speed_mult` / `sever_jump_mult` (how good movement feels after severing).

### Level pieces
- **Block** / **CrumbleBlock** / **Gate**: position = top-left; resize with `size`. Crumble: `crumble_delay`, `respawn_delay`. Gate: point `plate_path` at a Plate.
- **TetherAnchor** (ring): drag anywhere; the faint circle shows hook range.
- **Zone**: `kind` = KILL / CHECKPOINT / PHASE / STAY / EXIT. PHASE uses `phase`; STAY uses `stay_time`.
- Ending text is in `Scripts/main.gd` → `_check_zones()` (search "You stayed").

### Audio
- Bus volumes: pause menu sliders, or the **Audio** panel at the bottom of the editor (buses: Master, Music, Sfx).
- Dialogue blip loudness: each DialogueLine's `text_volume` (default -10 dB).
- Controls: `Scripts/main.gd` → `_ensure_input()`, or define the same action names in Project Settings → Input Map (those win).
