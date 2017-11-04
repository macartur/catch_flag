extends Node

# SOURCES
const normal_blue = preload("res://sources/001-blue.png")
const blue_with_flag = preload("res://sources/002-blue.png")
const frozen_blue = preload("res://sources/003-blue.png")

# textures
const normal_green = preload("res://sources/001-green.png")
const green_with_flag = preload("res://sources/002-green.png")
const frozen_green = preload("res://sources/003-green.png")

# scenes
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
		self.speed = 15
		self.last_update = self.get_movement()
		self.influence_number = 10
		
	func change_state(state=1):
		var sprite = self.object.get_node('sprite')
		var texture = null
		if self.team == 1:
			texture = blue_states[state]
		else:
			texture = green_states[state]
		sprite.set_texture(texture)

	func delete(map):
		map.object.remove_child(self.object)
		self.object.free()

	func get_influence_value(x,y,next_x,next_y):
		return int(self.influence_number/pow(1+abs(next_x - x)+abs(next_y - y), 2))

	func add_influence(map, x, y):
		self._handle_influence(map,x,y, 1)

	func remove_influence(map, x , y):
		self._handle_influence(map,x,y, -1)

	func _handle_influence(map, x, y, add):
		for next_x in range(map.width):
			for next_y in range(map.height):
				if self.team == 1:
					if self.frozen:
						map.ia.influence.blue_frozen[next_x][next_y] += self.get_influence_value(x,y, next_x,next_y) * add
					elif self.flag:
						map.ia.influence.blue_with_flag[next_x][next_y] += self.get_influence_value(x,y, next_x,next_y) * add
					else:
						map.ia.influence.blue[next_x][next_y] += self.get_influence_value(x,y, next_x,next_y) * add
				else:
					if self.frozen:
						map.ia.influence.green_frozen[next_x][next_y] += self.get_influence_value(x,y, next_x,next_y) * add
					elif self.flag:
						map.ia.influence.green_with_flag[next_x][next_y] += self.get_influence_value(x,y, next_x,next_y) * add
					else:
						map.ia.influence.green[next_x][next_y] += self.get_influence_value(x,y, next_x,next_y) * add

	func catch_flag(map, x, y):
		if self.flag == false and ((map.ia.safe_area[x][y] == 6 and self.team == 1) or (map.ia.safe_area[x][y] == 5 and self.team == 2)):
			self.remove_influence(map,x,y)
			self.flag = true
			self.add_influence(map,x,y)
			self.change_state(3)
			return true
		return false

	func freeze(map,x,y):
		if self.frozen:
			return
		self.remove_influence(map,x,y)
		self.flag = false
		self.frozen = true
		self.add_influence(map,x,y)
		self.change_state(2)

	func unfreeze(map,x,y):
		self.remove_influence(map,x,y)
		self.frozen = false
		self.add_influence(map,x,y)
		self.change_state(1)

	func update(delta, map, x, y):
		self.last_update -= delta
		if self.last_update > 0.0 or self.frozen == true:
			return

		self.last_update = self.get_movement()
		var options = map.ia.get_options(self)
		var team_area = map.ia.team_safe_area(self, x, y)
		# move to flag
#		self._handle_movement(map, x, y, options.enemies,false, false)
#		self._go_freeze_enemy(map, x, y, options.enemies)
#		self._go_unfreeze_allied(map, x, y, options.allied_frozen)
		if (self.catch_flag(map,x,y) == true):
			return

		if team_area == true and options.enemies_with_flag[x][y] > 0:
			print(1, options.enemies_with_flag[x])
			self._go_freeze_enemy(map, x, y, options.enemies_with_flag)
			return
		self._handle_movement(map, x, y, options.enemies, false, !self.flag)  # go catch flag
		
#		self._go_freeze_enemy(map, x, y, options.enemies)
#		print(options.enemies[x])



	func _go_unfreeze_allied(map, x, y, allied_frozen):
		var tmp_x = x
		var tmp_y = y
		for next_x in  shuffle([x-1,x,x+1]):
			for next_y in shuffle([y-1,y,y+1]):
				if map.not_allowed(next_x, next_y):
					continue
				var obj = map.board[next_x][next_y]
				if typeof(obj) != TYPE_INT:
					if self.team == obj.team and obj.frozen:
						obj.unfreeze(map, next_x, next_y)
						return
				elif self.closer_condition(allied_frozen, next_x, next_y, tmp_x, tmp_y, true):
					tmp_x = next_x
					tmp_y = next_y
		if tmp_x != x or tmp_y != y:
			map.move_object(x, y, tmp_x, tmp_y)

	func _go_freeze_enemy(map, x, y, enemies):
		var tmp_x = x
		var tmp_y = y
		for next_x in  shuffle([x-1,x,x+1]):
			for next_y in shuffle([y-1,y,y+1]):
				if map.not_allowed(next_x, next_y):
					continue
				var obj = map.board[next_x][next_y]
				if typeof(obj) == TYPE_INT:
					if self.closer_condition(enemies, next_x, next_y, tmp_x, tmp_y, true):
						tmp_x = next_x
						tmp_y = next_y
				elif (self.team != obj.team) and (obj.frozen == false) and \
				     ((obj.team == 1 and next_x >= 20 and map.ia.safe_area[next_x][next_y] == 2) or\
				     (obj.team == 2 and next_x < 20 and map.ia.safe_area[next_x][next_y] == 1)):
						obj.freeze(map, next_x, next_y)
						return 
		if tmp_x != x or tmp_y != y:
			print('=',self.team, tmp_x, tmp_y)
			map.move_object(x, y, tmp_x, tmp_y)

	func _handle_movement(map, x, y, influence, closer, catch_flag):
		var tmp_x = x
		var tmp_y = y

		for next_x in  self.shuffle([x-1,x,x+1]):
			for next_y in self.shuffle([y-1,y,y+1]):
				if map.not_allowed(next_x, next_y):
					continue
				var obj = map.board[next_x][next_y]
				if typeof(obj) == TYPE_INT:
					if self.movement_condition(map,next_x, next_y, tmp_x, tmp_y, catch_flag) and \
					   self.closer_condition(influence, next_x,next_y, tmp_x, tmp_y, closer):
						tmp_x = next_x
						tmp_y = next_y
		if tmp_x != x or tmp_y != y:
			map.move_object(x, y, tmp_x, tmp_y)

	func movement_condition(map, next_x, next_y, tmp_x, tmp_y, catch_flag):
		var condition_1
		var condition_2
		if catch_flag:
			condition_1 = map.ia.movement_map[next_x][next_y] <= map.ia.movement_map[tmp_x][tmp_y] and self.team == 1
			condition_2 = map.ia.movement_map[next_x][next_y] >= map.ia.movement_map[tmp_x][tmp_y] and self.team == 2
		else:
			condition_1 = map.ia.movement_map[next_x][next_y] >= map.ia.movement_map[tmp_x][tmp_y] and self.team == 1
			condition_2 = map.ia.movement_map[next_x][next_y] <= map.ia.movement_map[tmp_x][tmp_y] and self.team == 2
		return condition_1 or condition_2

	func closer_condition(influence, next_x,next_y, tmp_x, tmp_y, closer):
		if closer == false:
			return influence[next_x][next_y] <= influence[tmp_x][tmp_y]
		else:
			return influence[next_x][next_y] >= influence[tmp_x][tmp_y]

	func shuffle(array):
		var new_array = []
		while(array.size() > 0):
			var n = random_index(array)
			new_array.append(array[n])
			array.erase(array[n])
		return new_array

	func random_index(array):
		randomize()
		return randi()%(array.size())

	func get_movement():
		randomize()
		return randf()/self.speed

class IA:
	var movement_map
	var safe_area
	var influence
	var width
	var height
	var map

	func _init(width, height, map):
		self.map = map
		self.width = width
		self.height = height
		self.movement_map =  self._empty_map()
		self.safe_area = self._empty_map()
		self.build_safe_area()
		self.build_movement_map()
		self.influence = { }
		for key in ['green', 'blue', 'blue_frozen', 'green_frozen', 'blue_with_flag', 'green_with_flag']:
			self.influence[key] = self._empty_map()

	func get_options(player=null):
		var options = {}
		if player.team == 1:
			options.enemies = self.influence.green
			options.enemies_with_flag = self.influence.green_with_flag
			options.allied_frozen = self.influence.blue_frozen
		else:
			options.enemies = self.influence.blue
			options.enemies_with_flag = self.influence.blue_with_flag
			options.allied_frozen = self.influence.green_frozen
		return options

	func build_movement_map():
		self.add_influence(1000, 0, 13)
		self.add_influence(-1000, 39, 13)

	func add_influence(influence_number, x, y):
		for next_x in range(self.map.width):                                             
			for next_y in range(self.map.height):                                          
				self.movement_map[next_x][next_y] += influence_number/pow(1+abs(next_x - x)+abs(next_y - y), 2)

	func team_safe_area(player,x,y):
		if (x < 20 and player.team == 1) or (x > 20 and player.team == 2):
			return true
		return false

	func build_safe_area():
		#  1 - blue time
		#  2 - green time
		#  3 - blue safe area
		#  4 - green safe area
		#  5 - blue flag area
		#  6 - green flag area
		for x in range(self.width):
			for y in range(self.height):
				var value  = 0
				if x < 20:
					if x < 9 and y >= 4 and y <= 25:
						if x < 3 and y >= 11 and y <= 16:
							value = 5   
						else:
							value = 3
					else:
						value = 1
				else:
					if (x > 30 and y >= 4 and y <= 25):
						if x > 36 and y >= 11 and y <= 16:
							value = 6
						else:
							value = 4
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
		self.update_time  = 0.2
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

	func not_allowed(x,y):
		return (x >= self.width or y >= self.height or x < 0 or y < 0)

	func set_object(instance, x, y):
		if typeof(self.board[x][y]) != TYPE_INT:
			return
		self.object.add_child(instance.object)
		self.board[x][y] = instance
		instance.add_influence(self, x, y)
		instance.object.set_pos(Vector2(self.tile_size*x, self.tile_size*y))

	func remove_object(x,y):
		var instance = self.board[x][y]
		if typeof(instance) == TYPE_INT:
			return
		instance.remove_influence(x,y)
		self.board[x][y] = 0
		instance.delete(self)

	func move_object(x, y , next_x, next_y):
		var tmp = self.board[x][y]
		if typeof(tmp) == TYPE_INT:
			return
		tmp.remove_influence(self,x, y)
		self.board[next_x][next_y] = tmp
		self.board[x][y] = 0
		tmp.add_influence(self, next_x, next_y)
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
		self.set_object(p1, 10, 13)

		var p2 = Player.new(2)
		self.set_object(p2, 29,13)

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