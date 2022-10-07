extends Node2D

class_name LevelMap

enum { NORTH, WEST, SOUTH, EAST }

signal player_move_attempted
signal update_chips_left
signal player_reached_exit

const DEFAULT_TILESET_PATH = "res://res/tiles.png"
const DEFAULT_TILESET_SIZE = 32
const move_delay = 0.3
var tiles_tex: ImageTexture
var player_pos = Vector2(0, 0)
var player_layer = 0
var viewport_offset: Vector2 # the base offset of the map view
var last_move_time = 0
var chips_left = 0

func _ready():
	tiles_tex = ImageTexture.new()
	for y in range(32):
		for x in range(32):
			$Layer1.set_cell(x,y,Objects.FLOOR)

	var err = set_tileset(DEFAULT_TILESET_PATH, DEFAULT_TILESET_SIZE)
	if err != "":
		Console.write_line(err)
		get_tree().quit()

func _get_atlas(texture: Texture, rect: Rect2) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.set_atlas(texture)
	atlas.set_region(rect)
	return atlas

func get_tile(x: int, y: int, layer: int) -> int:
	if layer == 1:
		return $Layer1.get_cell(x, y)
	return $Layer2.get_cell(x, y)

func set_tile(x: int, y: int, layer: int, tileID: int):
	if layer == 1:
		$Layer1.set_cell(x, y, tileID)
	else:
		$Layer2.set_cell(x, y, tileID)

func change_tile_location(x1: int, y1: int, l1: int, x2: int, y2: int, l2: int):
	var tile: int
	if l1 == 1:
		tile = $Layer1.get_cell(x1, y1)
		$Layer1.set_cell(x1, y1, -1)
	else:
		tile = $Layer2.get_cell(x1, y1)
		$Layer2.set_cell(x1, y1, -1)
	if l2 == 1:
		$Layer1.set_cell(x2, y2, tile)
	else:
		$Layer2.set_cell(x2, y2, tile)

func shift_player(direction: int):
	shift_tile(player_pos.x, player_pos.y, player_layer, direction)
	match direction:
		NORTH:
			player_pos.y -= 1
		WEST:
			player_pos.x -= 1
		SOUTH:
			player_pos.y += 1
		EAST:
			player_pos.x += 1

func shift_tile(x: int, y: int, layer: int, direction: int):
	var new_x = x
	var new_y = y
	match direction:
		NORTH:
			if y <= 0:
				return
			new_y = y - 1
		WEST:
			if x <= 0:
				return
			new_x = x - 1
		SOUTH:
			if y >= 31:
				return
			new_y = y + 1
		EAST:
			if x >= 31:
				return
			new_x = x + 1
	change_tile_location(x, y, layer, new_x, new_y, layer)


func set_tileset(path: String, tile_size: int) -> String:
	var img:Image
	if path.begins_with("res://"):
		var stream_tex:StreamTexture = load(path)
		if stream_tex == null:
			return "Could not load tileset texture %s" % path
		tiles_tex.create_from_image(stream_tex.get_data())
	else:
		img = Image.new()
		if img.load(path) != OK:
			return "Unable to load tileset texture %s" % path
		tiles_tex.create_from_image(img)

	var img_width = tiles_tex.get_width()
	var img_height = tiles_tex.get_height()
	if img_width % tile_size > 0 or img_height % tile_size > 0:
		return "Tileset has an invalid size, tile width and height must be multiples of %d" % tile_size

	var tileset = TileSet.new()
	var x = 0
	var y = 0
	for t in range(111):
		var atlas = _get_atlas(tiles_tex, Rect2(x, y, tile_size, tile_size))

		tileset.create_tile(t)
		tileset.tile_set_texture(t, atlas)
		if y + tile_size == img_height:
			y = 0
			x += tile_size
		else:
			y += tile_size
	$Layer1.tile_set = tileset
	$Layer2.tile_set = tileset
	return ""

func center_camera():
	var camera_x = 0
	var camera_y = 0
	if player_pos.x <= 4:
		camera_x = 0
	else:
		camera_x = (player_pos.x - 4) * 32
	if player_pos.y <= 4:
		camera_y = 0
	else:
		camera_y = (player_pos.y - 4) * 32
	transform.origin.x = viewport_offset.x - camera_x
	transform.origin.y = viewport_offset.y - camera_y

func check_movement():
	if Input.is_key_pressed(KEY_UP):
		emit_signal("player_move_attempted", NORTH)
	if Input.is_key_pressed(KEY_LEFT):
		emit_signal("player_move_attempted", WEST)
	if Input.is_key_pressed(KEY_DOWN):
		emit_signal("player_move_attempted", SOUTH)
	if Input.is_key_pressed(KEY_RIGHT):
		emit_signal("player_move_attempted", EAST)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _physics_process(delta):
	last_move_time += delta
	if last_move_time >= move_delay:
		last_move_time = 0.0
	if Input.is_action_just_pressed("ui_up", false)\
	or Input.is_action_just_pressed("ui_left", false)\
	or Input.is_action_just_pressed("ui_down", false)\
	or Input.is_action_just_pressed("ui_right", false):
		last_move_time = 0
	
	var can_move = last_move_time == 0.0

	if can_move:
		check_movement()

func _on_LevelMap_player_move_attempted(direction: int):
	var new_x = player_pos.x
	var new_y = player_pos.y
	# next_x and next_y are used for checking the thing immediately after the destination.
	# So for example, if the tile at (new_x,new_y) is DIRT_MOVABLE and the tile at
	# (next_x,next_y) is FLOOR, it'll move, but if it's WALL, it won't
	var next_x = player_pos.x
	var next_y = player_pos.y
	match direction:
		NORTH:
			if player_pos.y < 1:
				return
			new_y = player_pos.y - 1
			next_y = player_pos.y - 2
		WEST:
			if player_pos.x < 1:
				return
			new_x = player_pos.x - 1
			next_x = player_pos.x - 2
		SOUTH:
			if player_pos.y >= 31:
				return
			new_y = player_pos.y + 1
			next_y = player_pos.y + 2
		EAST:
			if player_pos.x >= 31:
				return
			new_x = player_pos.x + 1
			next_x = player_pos.x + 2

	var dest_tile = get_tile(new_x, new_y, player_layer)
	var next_tile = get_tile(next_x, next_y, player_layer)
	match dest_tile:
		Objects.FLOOR, -1:
			pass
		Objects.WALL:
			return
		Objects.DIRT_MOVABLE:
			match next_tile:
				Objects.FLOOR, -1:
					shift_tile(new_x, new_y, player_layer, direction)
				_:
					return
		Objects.COMPUTER_CHIP:
			if chips_left > 0:
				emit_signal("update_chips_left", chips_left - 1)
		Objects.EXIT:
			emit_signal("player_reached_exit")
		_:
			print("Destination tile: %d" % dest_tile)
			return
	shift_player(direction)
	center_camera()

func _on_LevelMap_update_chips_left(left: int):
	chips_left = left
