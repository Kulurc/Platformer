class_name PartnerAI
extends RefCounted
## Drives whichever body you are NOT controlling. Deliberately simple: walk where you
## walk, jump what it can jump. Its personality per phase comes from the PhaseProfile
## (Data/Phases/*.tres) - see configure():
##   MIRROR mode       walks the same way you walk (competent, interchangeable)
##   predict           moves before you do (anxious)
##   mirror_jump_chance copies your jumps even into pits (anxious)
##   hold_on_*         plants its feet when you leave, so the cord tugs you back (clinging)
## After a tug it panics: follows closer and jumps at you blindly.

var mirror := true
var follow := 90.0
var predict := 0.0
var mirror_jump_chance := 0.0
var hold_on_chance := 0.0
var hold_on_time := 0.45
var hold_on_cooldown := 0.0
var jump_safety := 0.9     ## fraction of its jump height/reach it trusts itself with
var trail_margin := 14.0   ## px of daylight it keeps behind you (beyond both half-widths)

var _panic := 0.0
var _hesitate := 0.0
var _hold_cd := 0.0
var _leader_was_leaving := false
var _mirror_jump_timer := -1.0
var _air_dir := 0.0
var _air_hold := 0.0


func configure(p: PhaseProfile) -> void:
	mirror = p.ai_mode == PhaseProfile.AIMode.MIRROR
	follow = p.follow_distance
	predict = p.predict
	mirror_jump_chance = p.mirror_jump_chance
	hold_on_chance = p.hold_on_chance
	hold_on_time = p.hold_on_time
	hold_on_cooldown = p.hold_on_cooldown


func panic(t: float) -> void:
	_panic = maxf(_panic, t)


func reset() -> void:
	_panic = 0.0
	_hesitate = 0.0
	_mirror_jump_timer = -1.0


func think(me: Character, leader: Character, tether: Tether, dt: float) -> void:
	_panic = maxf(0.0, _panic - dt)
	_hesitate = maxf(0.0, _hesitate - dt)
	_hold_cd = maxf(0.0, _hold_cd - dt)
	me.calling = false

	# After a sever, nobody follows anybody. It stands where you left it.
	if tether.severed:
		me.set_intent(0.0, false, false)
		return

	# You're on a ring: plant and be the counterweight.
	if tether.anchor:
		me.set_intent(0.0, false, false)
		return

	if not me.is_on_floor():
		_air_hold -= dt
		me.set_intent(_air_dir, false, _air_hold > 0.0)
		return

	var target_x := leader.global_position.x
	if predict > 0.0:
		target_x += clampf(leader.velocity.x * predict, -120.0, 120.0)  # moves before you do
	var dx := target_x - me.global_position.x
	var move := 0.0
	var f := follow * (0.5 if _panic > 0.0 else 1.0)
	if absf(dx) > f:
		move = signf(dx)

	if mirror:
		# Walk the same way you walk, as long as it's near you.
		if leader.in_move != 0.0 and absf(leader.global_position.x - me.global_position.x) < f * 1.6:
			move = signf(leader.in_move)
	if hold_on_chance > 0.0:
		var leaving := leader.in_move != 0.0 and signf(leader.in_move) == signf(leader.global_position.x - me.global_position.x)
		if leaving and not _leader_was_leaving and _panic <= 0.0 and _hold_cd <= 0.0 and randf() < hold_on_chance:
			_hesitate = hold_on_time  # holds on
			_hold_cd = hold_on_time + hold_on_cooldown
		_leader_was_leaving = leaving
	if _hesitate > 0.0:
		move = 0.0
		me.calling = true

	# Never lead: it only ever walks toward you or after you. If it's ahead of you in the
	# direction it would walk (e.g. right after a swap), it waits for you to pass it.
	if move != 0.0 and signf(leader.global_position.x - me.global_position.x) != move:
		move = 0.0
	# ...and once it follows, it trails a body-width behind, easing off as it closes in
	# (so a faster follower settles in behind you instead of walking inside you).
	if move != 0.0:
		var gap := absf(leader.global_position.x - me.global_position.x)
		var trail := me.half_w() + leader.half_w() + trail_margin
		move *= clampf((gap - trail) / trail, 0.0, 1.0)

	var jump := false
	if move != 0.0:
		var scan := _scan(me, signf(move))
		if scan == "jump":
			jump = true
		elif scan == "blocked":
			if _panic > 0.0:
				jump = true  # reckless
			else:
				move = 0.0
				me.calling = true

	if leader.just_jumped and mirror_jump_chance > 0.0 and randf() < mirror_jump_chance 			and absf(leader.global_position.x - me.global_position.x) < 220.0:
		_mirror_jump_timer = 0.12
	if _mirror_jump_timer >= 0.0:
		_mirror_jump_timer -= dt
		if _mirror_jump_timer < 0.0:
			jump = true
			if move == 0.0:
				move = signf(leader.global_position.x - me.global_position.x)

	if jump:
		_air_dir = signf(move)  # commit to the jump at full speed
		_air_hold = 0.45
	me.set_intent(move, jump, jump)


## "clear" | "jump" | "blocked" for walking in direction `dir`.
func _scan(me: Character, dir: float) -> String:
	var space := me.get_world_2d().direct_space_state
	var x0 := me.global_position.x
	var feet := me.feet_y()
	var hw := me.half_w()
	var reach_h := me.jump_height * jump_safety

	# Wall ahead?
	if _ray(space, me, Vector2(x0, feet - 4.0), Vector2(x0 + dir * (hw + 8.0), feet - 4.0)):
		var clear_above := not _ray(space, me,
			Vector2(x0, feet - reach_h), Vector2(x0 + dir * (hw + 14.0), feet - reach_h))
		return "jump" if clear_above else "blocked"

	# Gap ahead?
	var edge_x := x0 + dir * (hw + 6.0)
	if not _ray(space, me, Vector2(edge_x, feet - 4.0), Vector2(edge_x, feet + 24.0)):
		var reach := me.jump_reach() * jump_safety
		var k := 30.0
		while k <= reach:
			var x := x0 + dir * (hw + k)
			if _ray(space, me, Vector2(x, feet - reach_h * 0.8), Vector2(x, feet + 60.0)):
				return "jump"
			k += 15.0
		return "blocked"
	return "clear"


func _ray(space: PhysicsDirectSpaceState2D, me: Character, from: Vector2, to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, 1, [me.get_rid()])
	return not space.intersect_ray(q).is_empty()
