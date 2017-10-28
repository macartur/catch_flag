
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
	var fix_influence_number

	func _init(team=1):
		self.flag = false
		self.frozen = false
		self.team = team
		self.object = agent.instance()
		self.change_state(1)
		self.speed = 10
		self.last_update = self.get_movement()
		self.influence_number = 100
		self.fix_influence_number = self.influence_number
		
	func change_state(state=1):
		var sprite = self.object.get_node('sprite')
		var texture = null
		if team == 1:
			texture = blue_states[state]
		else:
			texture = green_states[state]
		sprite.set_texture(texture)

	func delete(map):
		map.object.remove_child(self.object)
		self.object.free()

	func get_influence_value(x,y,next_x,next_y):
		return self.influence_number/(1+abs(next_x - x)+abs(next_y - y))

	func add_influence(map, x, y):
		for next_x in range(map.width):                                             
			for next_y in range(map.height):          
				if self.team == 1:
					map.ia.blue_influence[next_x][next_y] += self.get_influence_value(x,y, next_x,next_y)
				else:
					map.ia.green_influence[next_x][next_y] += self.get_influence_value(x,y, next_x,next_y)

	func remove_influence(map, x , y):
		for next_x in range(map.width):                                             
			for next_y in range(map.height):            
				if self.team == 1:                              
					map.ia.blue_influence[next_x][next_y] -= self.get_influence_value(x,y, next_x,next_y)
				else:
					map.ia.green_influence[next_x][next_y] -= self.get_influence_value(x,y, next_x,next_y)

	func catch_flag(map, x, y):
		if map.ia.safe_area[x][y] != 4:
			return

		if self.team == 1 and x > 20 or self.team == 2 and x < 20:
			self.change_state(3)
			self.flag = true

	func freeze(map,x,y):
		self.remove_influence(map,x,y)
		self.influence_number = 0
		self.add_influence(map,x,y)
		self.frozen = true
		self.change_state(2)

	func unfreeze(map,x,y):
		self.remove_influence(map,x,y)
		self.influence = self.fix_influence_number
		self.add_influence(map,x,y)
		self.frozen = false
		self.change_state(1)

	func update(delta, map, x, y):
		self.last_update -= delta
		if self.last_update > 0.0 or self.frozen == true:
			return
		self.last_update = self.get_movement()

		var enemies = map.ia.blue_influence
		var allied = map.ia.green_influence
		var team_area = false

		if self.team == 1:
			enemies = map.ia.green_influence
			allied =  map.ia.blue_influence

		if (x < 20 and self.team == 1) or (x > 20 and self.team == 2):
			team_area = true

		#self.go_to_catch_a_flag(map,x,y, enemies)
		#self.go_to_allied_flag(map,x,y, enemies)
		#self.go_to_enemy_closer(map,x,y, enemies)
		# decision tree
		if enemies[x][y] > 0: # 2 - Search for enemy unfrozen closer
			if team_area == true: # 4 - allied field
				print(1)
				self.go_to_enemy_closer(map,x,y, enemies) # go to the enemy closer
			else:
				print(2)
				self.go_to_allied_flag(map, x, y, enemies) # go to the safe field
		else:
			if allied[x][y] < 0: # 1 - search for allied frozen closer
				pass
			else:
				if self.flag == true: # 5 - I have a flag
					print(4)
					self.go_to_allied_flag(map,x,y, enemies)# go to store a flag
				else:  # 5 - I haven't a flag
					print(5)
					self.go_to_catch_a_flag(map,x,y, enemies)# go to catch a flag	

	func go_to_catch_a_flag(map,x,y, enemies): 
		# try to go to the team flag
		var tmp_x = x
		var tmp_y = y
		var best_influence = map.ia.movement_map[x][y]
		var enemy_closer = enemies[x][y]
		for next_x in [x-1,x,x+1]: 
			for next_y in [y-1,y,y+1]:
				if  map.not_allowed(next_x, next_y):
					continue
				var obj = map.board[next_x][next_y]
				if (typeof(obj) == TYPE_INT):
					if (self.team == 1 and map.ia.movement_map[next_x][next_y] < best_influence) or\
					   (self.team == 2 and map.ia.movement_map[next_x][next_y] > best_influence) and\
					   enemies[next_x][next_y] <= enemy_closer: 
						tmp_x = next_x
						tmp_y = next_y
						best_influence = map.ia.movement_map[next_x][next_y]
						enemy_closer = enemies[next_x][next_y]
		if typeof(map.board[tmp_x][tmp_y]) == TYPE_INT:
			map.move_object(x, y, tmp_x, tmp_y)

	func go_to_allied_flag(map, x, y, enemies):
		# try to go to the team flag
		var tmp_x = x
		var tmp_y = y
		var best_influence = map.ia.movement_map[x][y]
		var enemy_closer = enemies[x][y]
		for next_x in [x-1,x,x+1]: 
			for next_y in [y-1,y,y+1]:
				if  map.not_allowed(next_x, next_y):
					continue
				var obj = map.board[next_x][next_y]
				if (typeof(obj) == TYPE_INT):
					if (self.team == 1 and map.ia.movement_map[next_x][next_y] > best_influence) or\
					   (self.team == 2 and map.ia.movement_map[next_x][next_y] < best_influence) and\
					   enemies[next_x][next_y] <= enemy_closer: 
						tmp_x = next_x
						tmp_y = next_y
						best_influence = map.ia.movement_map[next_x][next_y]
						enemy_closer = enemies[next_x][next_y]
		if typeof(map.board[tmp_x][tmp_y]) == TYPE_INT:
			map.move_object(x, y, tmp_x, tmp_y)

	func go_to_enemy_closer(map,x,y, enemies):
		var tmp_x = x
		var tmp_y = y
		var best_influence = enemies[x][y]
		var done = false
		for next_x in [x-1,x,x+1]: 
			for next_y in [y-1,y,y+1]:
				if map.not_allowed(next_x, next_y):
					continue
				var obj = map.board[next_x][next_y]
				if typeof(obj) != TYPE_INT and obj.team != self.team and obj.frozen == false:
					# freeze only one enimy closer
					obj.freeze(map, next_x, next_y)
					done = true
					break
				elif enemies[next_x][next_y] >= best_influence:
					best_influence = enemies[next_x][next_y]
					tmp_x = next_x
					tmp_y = next_y

		if done == false and typeof(map.board[tmp_x][tmp_y]) == TYPE_INT:
			map.move_object(x, y, tmp_x, tmp_y)

	func get_movement():
		randomize()
		return randf()/self.speed

class IA:
	var movement_map
	var safe_area
	var blue_influence
	var green_influence
	var width
	var height
	var map

	func _init(width, height, map):
		self.map = map
		self.width = width
		self.height = height
		self.movement_map =  self._empty_map()
		self.build_movement_map()
		self.blue_influence =  self._empty_map()
		self.green_influence =  self._empty_map()
		self.safe_area = self._empty_map()
		self.build_safe_area()

	func build_movement_map():
		self.add_influence(1000, 0, 13)
		self.add_influence(-1000, 39, 13)

	func add_influence(influence_number, x, y):
		for next_x in range(self.map.width):                                             
			for next_y in range(self.map.height):                                          
				self.movement_map[next_x][next_y] += influence_number/(1+abs(next_x - x)+abs(next_y - y))

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
		tmp.remove_influence(self, x,y)
		self.board[next_x][next_y] = tmp
		tmp.add_influence(self, x, y)
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