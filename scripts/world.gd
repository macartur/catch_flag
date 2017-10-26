
extends Node

# SOURCES
const normal_blue = preload("res://sources/001-blue.png")
const blue_with_flag = preload("res://sources/002-blue.png")
const frozen_blue = preload("res://sources/003-blue.png")

const normal_green = preload("res://sources/001-green.png")
const green_with_flag = preload("res://sources/002-green.png")
const frozen_green = preload("res://sources/003-green.png")

# OBJECTS
const agent = preload("res://objects/agent.tscn") 

# TYPE OF STATES
const blue_states = {1: normal_blue, 2: frozen_blue, 3: blue_with_flag }
const green_states = {1: normal_green, 2: frozen_green, 3: green_with_flag }

# CLASSES
class Player:
	var flag
	var frozen
	var team
	var object
	var last_update
	var speed
	var influence_number

	func _init(team=1):
		self.flag = false
		self.frozen = false
		self.team = team
		self.object = agent.instance()
		self.change_state(1)
		self.speed = 8
		self.last_update = self.get_movement()
		self.influence_number = 300

	func change_state(state=1):
		var sprite = self.object.get_node('sprite')
		var texture = null
		if team == 1:
			texture = blue_states[state]
		else:
			texture = green_states[state]
		sprite.set_texture(texture)

	func type():
		return 'Player'

	func delete(map):
		map.object.remove_child(self.object)
		self.object.free()
	
	func add_influence(map, x, y):
		for next_x in range(map.width):                                             
			for next_y in range(map.height):                                          
				map.influence_map[next_x][next_y] += self.influence_number/(1+abs(next_x - x)+abs(next_y - y))^2

	func remove_influence(map, x , y):
		for next_x in range(map.width):                                             
			for next_y in range(map.height):                                          
				map.influence_map[next_x][next_y] -= self.influence_number/(1+abs(next_x - x)+abs(next_y - y))^2

	func catch_flag(map, x, y):
		if map.ia.safe_area[x][y] != 4:
			return

		if self.team == 1 and x > 20 or self.team == 2 and x < 20:
			self.change_state(3)
			self.flag = true




	func update(delta, map, x, y):
		self.last_update -= delta
		if self.last_update > 0.0 or self.frozen == true:
			return
		self.last_update = self.get_movement()
		var tmp_x = x
		var tmp_y = y






		print(self.last_update)
		

	func get_movement():
		randomize()
		return randf()/self.speed

class IA:
	var movement_map
	var safe_area
	var width
	var height
	var map

	func _init(width, height, map):
		self.map = map
		self.width = width
		self.height = height
		self.movement_map =  self._empty_map()
		self.build_movement_map()
		self.safe_area = self._empty_map()
		self.build_safe_area()

	func build_movement_map():
		# left
		for x in range(3):
			for y in range(11, 17):
				self.add_influence(1000, x, y)
		#right
		for x in [37,38,39]:
			for y in range(11, 17):
				self.add_influence(-1000, x, y)

	func add_influence(influence_number, x, y):
		for next_x in range(self.map.width):                                             
			for next_y in range(self.map.height):                                          
				self.movement_map[next_x][next_y] += influence_number/(1+abs(next_x - x)+abs(next_y - y))^2

	func build_safe_area():
		#  1 - blue time
		#  2 - green time
		#  3 - safe area
		#  4 - flag area
		for x in range(self.width):
			for y in range(self.height):
				var value  = 0
				if x < 20:
					if x < 9 and y >= 4 and y <= 25:
						if x < 3 and y >= 11 and y <= 16:
							value = 4
						else:
							value = 3
					else:
						value = 1
				else:
					if (x > 30 and y >= 4 and y <= 25):
						if x > 36 and y >= 11 and y <= 16:
							value = 4
						else:
							value = 3
					else:
						value = 2
				self.safe_area[x][y] = value

	func _empty_map():
		var map = []
		for x in range(width):
			var columns = []
			for y in range(height):
				columns.append(0)
			map.append(columns)
		return map

class Field:
	var width
	var height
	var tile_size
	var board
	var object
	var last_update
	var update_time
	var ia

	func _init(width=40, height=30, object=null, tile_size=20):
		self.width = width
		self.height = height
		self.tile_size = tile_size
		self.board = self._empty_map()
		self.ia = IA.new(width, height, self)
		self.object = object
		self.update_time  = 0.5
		self.last_update = self.update_time
		self.create_players()
		
	func _empty_map():
		var map = []
		for x in range(width):
			var columns = []
			for y in range(height):
				columns.append(0)
			map.append(columns)
		return map

	func set_object(instance, x, y):
		if typeof(self.board[x][y]) != TYPE_INT:
			return
		self.object.add_child(instance.object)
		self.board[x][y] = instance
		instance.object.set_pos(Vector2(self.tile_size*x, self.tile_size*y))

	func remove_object(x,y):
		var instance = self.board[x][y]
		if typeof(instance) == TYPE_INT:
			return
		self.board[x][y] = 0
		instance.delete(self)

	func move_object(x, y , next_x, next_y):
		var tmp = self.board[x][y]
		if typeof(tmp) == TYPE_INT:
			return
		self.board[next_x][next_y] = tmp
		self.board[x][y] = 0
		tmp.object.set_pos(Vector2(self.tile_size*next_x, self.tile_size*next_y))

	func create_players():
		
		for x in [5, 15]:
			for y in [3, 26]:
				var p1 = Player.new(1)
				self.set_object(p1, x, y)
		
		for x in [24, 34]:
			for y in [3, 26]:
				var p2 = Player.new(2)
				self.set_object(p2, x,y)

		var p1 = Player.new(1)
		self.set_object(p1, 15, 13)
		var p2 = Player.new(2)
		self.set_object(p2, 24,13)

	func update(delta):
		self.last_update -= delta
		
		if self.last_update > 0.0 :
			return
		self.last_update = self.update_time
		for x in range(self.width):
			for y in range(self.height):
				var obj = self.board[x][y]
				if typeof(obj) != TYPE_INT:
					obj.update(delta, self, x, y)

# GAME
var field
func _ready():
	field = Field.new(40, 30, get_node('.'))
	set_process(true)

func _process(delta):
	field.update(delta)