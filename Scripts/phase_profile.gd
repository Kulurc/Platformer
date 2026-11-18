class_name PhaseProfile
extends Resource
## One relationship phase. The sandbox's phases live in Data/Phases/*.tres and are listed,
## in order, on the root node's `phase_profiles`. Double-click a .tres to edit it in the
## Inspector; changes apply the next time you run. Add a 4th file + entry for a phase IV
## (Zone "phase" numbers start at 1 = first entry).

enum AIMode { MIRROR, FOLLOW }

@export_group("Title card")
@export var title := "I.  Together"
@export_multiline var subtitle := ""
## Show the title card when this phase starts (phase I's is shown by the intro trigger).
@export var show_title := true

@export_group("Cord")
## Longest the cord can be in this phase. When entering a phase with a shorter max, the
## cord tightens toward it gradually (Tether.tighten_speed).
@export_range(40.0, 800.0, 5.0) var max_length := 440.0
## Comfortable length the cord eases back to when you're both standing.
@export_range(8.0, 800.0, 5.0) var rest_length := 200.0
## Beyond this distance you count as "apart": drives the cold/anxious filter and memory.
@export_range(10.0, 800.0, 5.0) var comfort := 170.0

@export_group("Tension memory (cord shortens while apart)")
## Seconds apart before the cord starts shortening itself. 0 = never (off).
@export_range(0.0, 10.0, 0.1) var shrink_after := 0.0
## How fast it shortens (px/s). It never grows back.
@export_range(0.0, 300.0, 1.0) var shrink_speed := 40.0
## Shortest it can ratchet down to in this phase.
@export_range(8.0, 800.0, 5.0) var leash_floor := 440.0

@export_group("Partner AI")
## MIRROR: walks the way you walk. FOLLOW: only closes distance to you.
@export var ai_mode := AIMode.MIRROR
## How close it tries to stay (px).
@export_range(0.0, 400.0, 1.0) var follow_distance := 90.0
## Seconds of your velocity it predicts ahead ("moves before you do"). 0 = off.
@export_range(0.0, 1.5, 0.05) var predict := 0.0
## Chance it copies your jump even when there's nothing to jump (it may land in a pit).
@export_range(0.0, 1.0, 0.05) var mirror_jump_chance := 0.0

@export_group("Pull-back (holding on when you leave)")
## Chance that, when you start walking away, it plants its feet and holds on.
@export_range(0.0, 1.0, 0.05) var hold_on_chance := 0.0
## How long it holds on each time (s). Longer = harder tug.
@export_range(0.0, 3.0, 0.05) var hold_on_time := 0.45
## Minimum seconds between hold-ons (lower = it pulls back more often).
@export_range(0.0, 10.0, 0.1) var hold_on_cooldown := 0.0

@export_group("Tug (yanked back when you pull away)")
@export var tug_enabled := false
## How hard you must pull away (in W, one Wisp-weight) before it counts as a tug.
@export_range(0.5, 5.0, 0.05) var tug_force := 1.3
## Strength of the yank back toward them (px/s).
@export_range(0.0, 1200.0, 10.0) var tug_impulse := 300.0
## How long you lose control after a tug (s).
@export_range(0.0, 1.5, 0.01) var tug_stagger := 0.22
## Minimum seconds between tugs.
@export_range(0.0, 5.0, 0.05) var tug_cooldown := 0.9
## How long the partner panics after a tug (runs and jumps at you blindly).
@export_range(0.0, 5.0, 0.1) var panic_time := 1.2
## Camera shake on a tug (px).
@export_range(0.0, 30.0, 0.5) var tug_camera_shake := 6.0

@export_group("Swap")
## After swapping, the new body ignores you this long (it hesitates).
@export_range(0.0, 2.0, 0.01) var swap_delay := 0.0
## After swapping, your input still drives the OLD body this long.
@export_range(0.0, 2.0, 0.01) var control_bleed := 0.0

@export_group("Look & feel")
## How much each body takes on the other's colour / silhouette (0..1).
@export_range(0.0, 1.0, 0.05) var bleed := 0.0
## Strength of the separation filter (cold/vignette) and the warm closeness pulse.
@export_range(0.0, 1.0, 0.05) var anxiety := 0.25
## How much being apart degrades YOUR movement (lighter gravity, mushy acceleration).
@export_range(0.0, 1.0, 0.05) var floaty := 0.0
