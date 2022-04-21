extends KinematicBody2D

class_name Player

# To Dos/Ideas
#
#

# Physics
var acceleration = 200 # per sec
var gravity = 1500 # per sec
var gravityMult = 1.0
var friction = 600 # per sec
var airRes = 150 # per sec
var speed = 125 # cap
var jump_impulse = 200

var velocity = Vector2()

var peak = 0
var jumping = false
var slid = false

var frames = 0
var disablePlaying = false
var movementEnabled = true

# Other

var victimer = 0
var rng = RandomNumberGenerator.new()

# Skills
var skill = null
var activeSkill = null

# Skill Related
var pogoing = false # Pogo


# Node Refs
onready var sprite: AnimatedSprite = $AnimatedSprite
onready var powers = $UI/PowersContainer
onready var tween: Tween = $Tween
onready var trail: Particles2D = $TrailEffect

var skilleffect = preload("res://objects/SkillEffect.tscn")

# Buffers
const BUFFER_DEFAULT = 0.1 # seconds
var floor_buffer = 0
var jump_buffer = 0
var skill_buffer = 0

# Squash Consts
const SQUASH_CENTER = 0b00000
const SQUASH_UP = 0b00001
const SQUASH_DOWN = 0b00010
const SQUASH_LEFT = 0b00100
const SQUASH_RIGHT = 0b01000
const SQUASH_FORWARD = 0b10000

# Setup Func!!

func setup():
	Engine.time_scale = 1
	for i in range(len(Globals.characters)):
		Globals.characters[i] = Globals.characters[i].new(self)
	$UI/PowersContainer.setup()
	skill = Globals.characters[0]
	update_asset(skill.asset, skill.effects)

# Signals

func _animation_finished():
	if sprite.animation == "jump":
		sprite.play("idle")	

# Game calls

func _physics_process(delta):
	frames += 1
	
	rng.randomize()
	
	gravityMult = 1.0
	
	check_buffers(delta)
	
	get_input(delta)
	
	if activeSkill or skill.has_method("passive"):
		do_skill(delta)
	
	if movementEnabled:
		do_gravity(delta)
	
	limit_vel()
	
	if not activeSkill:
		check_direction()
	
	move()

	check_collisions()
	
	if trail.emitting:
		do_trail()

	if disablePlaying:
		victimer += delta
		get_node("../RichTextLabel").text = "nice dub boss - " + str(round((1-victimer)*100)/100)
		if victimer >= 1:
			var _err = get_tree().change_scene("res://scenes/Main.tscn")

# Called in process

func check_buffers(delta):
	if is_on_floor():
		floor_buffer = BUFFER_DEFAULT
		if sprite.animation == "jump":
			sprite.play("idle")
	elif floor_buffer:
		floor_buffer = clamp(floor_buffer-delta,0,BUFFER_DEFAULT)
	if jump_buffer:
		jump_buffer = clamp(jump_buffer-delta,0,BUFFER_DEFAULT)
	if skill_buffer:
		skill_buffer = clamp(skill_buffer-delta,0,20)

func get_input(delta):
	if Input.is_action_just_pressed("title"):
		var _err = get_tree().change_scene("res://scenes/Main.tscn")

	if jumping and is_on_floor():
		jumping = false
	
	if Input.is_action_just_pressed("reset"):
		var _err = get_tree().reload_current_scene()
	
	var previousSel = Globals.selected
	
	if Input.is_action_just_pressed("char1"):
		Globals.selected = 0
	elif Input.is_action_just_pressed("char2"):
		Globals.selected = 1
	elif Input.is_action_just_pressed("char3"):
		Globals.selected = 2
	elif Input.is_action_just_pressed("char4"):
		Globals.selected = 3
		
	if len(Globals.characters) <= Globals.selected:
		Globals.selected = len(Globals.characters) - 1
		
	skill = Globals.characters[Globals.selected]
	
	if Globals.selected != previousSel and not activeSkill:
		update_asset(skill.asset, skill.effects)
	
	if Input.is_action_just_pressed("skill"):
		skill_buffer = BUFFER_DEFAULT
		if activeSkill and "timer" in activeSkill:
			skill_buffer += activeSkill.timer

	if movementEnabled and not disablePlaying:
		do_movement_inputs(delta)
	else:
		if Input.is_action_just_pressed("jump"):
			floor_buffer = BUFFER_DEFAULT
			
	if OS.is_debug_build():
		debug(delta)

func do_movement_inputs(delta):
	var f = 0
	
	var dirpressed = Input.get_axis("left","right")
	
	velocity.x  = clamp(velocity.x + (acceleration*delta*dirpressed), -speed, speed)
	
	if (dirpressed > 0) != (velocity.x > 0) or dirpressed == 0:
		if is_on_floor():
			f = friction
		elif dirpressed == 0:
			f = airRes
	
	if f:
		if velocity.x > 0:
			velocity.x -= f*delta
			if velocity.x < 0:
				velocity.x = 0
			
		elif velocity.x < 0:
			velocity.x += f*delta
			if velocity.x > 0:
				velocity.x = 0

	if skill_buffer:
		use_skill(delta)
	
	if bool(jump_buffer) and bool(floor_buffer):
		velocity.y = -jump_impulse
		sprite.play("jump")
		jumping = true
		jump_buffer = 0
		floor_buffer = 0
		squash(0.8,1.2)
	elif Input.is_action_just_pressed("jump"):
		jump_buffer = BUFFER_DEFAULT

func use_skill(delta):
	if not skill.charge:
		return

	var use_charge = false

	if skill.has_method("use"):
		use_charge = skill.use(delta)

	if use_charge:
		if skill.has_method("do"):
			activeSkill = skill
		skill_buffer = 0
		if not Globals.DEBUG_INF_CHARGE:
			powers.update_charges(Globals.selected, skill.charge)
			skill.charge -= 1

func do_skill(delta):
	if activeSkill and activeSkill.has_method("do"):
		activeSkill.do(delta)
	elif skill.has_method("passive"):
		skill.passive(delta)

func debug(_delta):
	var dir = 0
	var x = 0.6
	var y = 0.6
	if Input.is_action_pressed("ui_left"):
		dir ^= SQUASH_LEFT
	elif Input.is_action_pressed("ui_right"):
		dir ^= SQUASH_RIGHT
	else:
		x = 1
	if Input.is_action_pressed("ui_up"):
		dir ^= SQUASH_UP
	elif Input.is_action_pressed("ui_down"):
		dir ^= SQUASH_DOWN
	else:
		y = 1
	if dir and not tween.is_active():
		squash(x, y, 0.05, 0.3, dir)

	if Input.is_action_just_pressed("DEBUG_toggle_inf_charge"):
		Globals.DEBUG_INF_CHARGE = !Globals.DEBUG_INF_CHARGE
		print("DEBUG_INF_CHARGE = " + str(Globals.DEBUG_INF_CHARGE))

func do_gravity(delta):
	if is_on_floor() and not jumping:
		velocity.y = 5
		pogoing = false
		if position.y-peak > 2:
			var squashmult = clamp(position.y-peak,0,200)
			squashmult = 0.005 * squashmult
			squash(1 + 0.9*squashmult, 1 - 0.7*squashmult,0,0.3,SQUASH_DOWN)
			peak = 0
		peak = position.y
	else:
		if peak > position.y:
			peak = position.y
		if jumping and velocity.y > -300 and velocity.y < 150: # Peak of jump
			if Input.is_action_pressed("jump") or pogoing:
				velocity.y += gravity/2*delta
			else:
				velocity.y += gravity*delta
		else:
			velocity.y += gravity*gravityMult*delta

func limit_vel():
	velocity.x = clamp(velocity.x, -500, 500)
	velocity.y = clamp(velocity.y, -500, 500*gravityMult)			
			
func check_direction():
	if velocity.x > 0:
		sprite.flip_h = false
		$Grapple/Raycast.cast_to.x = 25
		$Grapple/Raycast.position.x = 6
	elif velocity.x < 0:
		sprite.flip_h = true
		$Grapple/Raycast.cast_to.x = -25
		$Grapple/Raycast.position.x = -6

func move():
	if slid:
		slid = false
	else:
		velocity = move_and_slide(velocity,Vector2.UP)
		if not activeSkill:
			if velocity.x != 0 and sprite.animation == "idle":
				sprite.play("walk")
			elif sprite.animation == "walk":
				if velocity.x == 0:
					sprite.play("idle")
				else:
					sprite.speed_scale = abs(0.008*velocity.x)

func check_collisions():
	for i in get_slide_count():
		var collider = get_slide_collision(i).collider
		if collider.get_collision_layer_bit(2) or collider.get_collision_layer_bit(3): # Kill Planes & enemies
			var _err = get_tree().reload_current_scene()
		elif collider.get_collision_layer_bit(4): # victory flag
			disablePlaying = true
			Engine.time_scale = 1

func do_trail():
	var tex = sprite.frames.get_frame(sprite.animation,sprite.frame)
	if sprite.flip_h or sprite.scale.x != 1 or sprite.scale.y != 1:
		var im = tex.get_data()
		if sprite.flip_h:
			im.flip_x()
		if sprite.scale.x < .05 or sprite.scale.y < .05:
			tex = null
		else:
			im.resize(im.get_width()*sprite.scale.x, im.get_height()*sprite.scale.y, 0)
			tex = ImageTexture.new()
			tex.create_from_image(im, 0)
	trail.texture = tex
	trail.position = sprite.position

# Called elsewhere

func update_asset(asset, effects=[]):
	if asset and sprite.frames != asset:

		if frames > 0:
			make_smoke(Vector2(-20,-16), -90)
			make_smoke(Vector2(20,1), 200)
			make_smoke(Vector2(1,20), -210)
			make_smoke(Vector2(20,-16), 90)
			modulate = Color(4,4,4,1)
			yield(get_tree().create_timer(0.1), "timeout")
			sprite.frames = asset
			modulate = Color(1,1,1,1)
		else:
			sprite.frames = asset
	if "trail" in effects:
		trail.emitting = true
	else:
		trail.emitting = false
			
func make_smoke(pos, deg):
	pos += Vector2(rng.randf_range(-15,15),rng.randf_range(-15,15))
	deg += rng.randf_range(-10,10)
	return skill_animation("smoke", position, false, pos, deg, true)

func skill_end():
	update_asset(skill.asset, skill.effects)

func skill_animation(anima, loca, follow=false, vel=Vector2.ZERO, rot=0, behind=false):
	var anim = skilleffect.instance()
	anim.play(anima)
	anim.position = loca
	anim.vel = vel
	anim.rot = rot
	if follow:
		anim.show_behind_parent = behind
		add_child(anim)
	else:
		if behind:
			get_owner().add_child(anim)
			get_owner().move_child(anim,0)
		else:
			get_owner().add_child(anim)
	return anim

func squash(tox,toy,into=0,outof=0.3,align=SQUASH_CENTER):
	var toscale = Vector2(tox,toy)
	var pos = null
	if align != SQUASH_CENTER:
		if sprite.frames.get_frame(sprite.animation,sprite.frame):
			var charSize = sprite.frames.get_frame(sprite.animation,sprite.frame).get_size()
			pos = (charSize - (charSize * toscale) ) / 2
			if toscale.x > 1: # Center if scale greater than 1 (if not it'd be a negative number)
				pos.x = 0
			if toscale.y > 1:
				pos.y = 0
			if align and (pos.x or pos.y):
				if align & SQUASH_UP:
					pos.y *= -1
				elif not align & SQUASH_DOWN:
					pos.y = 0
				if align & SQUASH_FORWARD:
					if sprite.flip_h:
						align = align ^ SQUASH_LEFT
					else:
						align = align ^ SQUASH_RIGHT
				if align & SQUASH_LEFT:
					pos.x *= -1
				elif not align & SQUASH_RIGHT:
					pos.x = 0
	var _err = tween.stop(sprite)
	if into > 0:
		_err = tween.interpolate_property(sprite, "scale", Vector2(1,1), toscale, into)
		if pos:
			_err = tween.interpolate_property(sprite, "position", Vector2(0,0), pos, into)
	_err = tween.interpolate_property(sprite, "scale", toscale, Vector2(1,1), outof, 0, 2, into)
	if pos:
		_err = tween.interpolate_property(sprite, "position", pos, Vector2(0,0), outof, 0, 2, into)
	_err = tween.start()
