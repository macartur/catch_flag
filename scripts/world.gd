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
		self.speed = 20
		self.last_update = self.get_movement()
		self.influence_number = 500
		
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
				var value = self.get_influence_value(x,y, next_x,next_y) * add
				if self.team == 1:
					if self.frozen:
						map.ia.influence.blue_frozen[next_x][next_y] += value
					else:
						map.ia.influence.blue[next_x][next_y] += value
					if self.flag:
						map.ia.influence.blue_with_flag[next_x][next_y] += value
				elif self.team == 2:
					if self.frozen:
						map.ia.influence.green_frozen[next_x][next_y] += value
					else:
						map.ia.influence.green[next_x][next_y] += value
					if self.flag:
						map.ia.influence.green_with_flag[next_x][next_y] += value

	func store_flag(map, x, y):
		if self.flag == true and \
		   ((map.ia.safe_area[x][y] == 5 and self.team == 1) or (map.ia.safe_area[x][y] == 6 and self.team == 2)):
			self.remove_influence(map,x,y)
			self.flag = false
			self.add_influence(map,x,y)
			self.change_state(1)
			map.flags[self.team] += 1
			return true
		return false

	func catch_flag(map, x, y):
		if self.flag == false and \
		   ((map.ia.safe_area[x][y] == 6 and self.team == 1) or (map.ia.safe_area[x][y] == 5 and self.team == 2)):
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
		var team_area = (x < 20 and self.team == 1) or (x >= 20 and self.team == 2)

		if (self.catch_flag(map,x,y) == true):
			return

		if (self.store_flag(map, x, y) == true):
			return

		if team_area == true: # 1 
			if options.enemies_with_flag[x][y] > 0: # 2
				self._go_freeze_enemy(map, x, y, options.enemies_with_flag)
			elif options.enemies[x][y] > 0: # 3
				self._go_freeze_enemy(map, x, y, options.enemies)
			elif options.allied_frozen[x][y] > 0:  # 4
				self._go_unfreeze_allied(map, x,y, options.allied_frozen)
			else: # 6
				self._handle_movement(map, x, y, options.enemies, false, self.flag)
		else:
			if options.enemies[x][y] > 0:  # 3
				self._handle_movement(map, x, y, options.enemies, false, !self.flag)
			if options.allied_frozen[x][y] > 0: # 4
				self._go_unfreeze_allied(map, x,y, options.allied_frozen)
			else:  # 6
				self._handle_movement(map, x, y, options.enemies, false, self.flag)

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
				     ((obj.team == 1 and map.ia.safe_area[next_x][next_y] == 2) or\
				     (obj.team == 2 and map.ia.safe_area[next_x][next_y] == 1)):
						obj.freeze(map, next_x, next_y)
						return 
		if tmp_x != x or tmp_y != y:
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
			condition_1 = map.ia.movement_map[next_x][next_y] >= map.ia.movement_map[tmp_x][tmp_y] and self.team == 1
			condition_2 = map.ia.movement_map[next_x][next_y] <= map.ia.movement_map[tmp_x][tmp_y] and self.team == 2
		else:
			condition_1 = map.ia.movement_map[next_x][next_y] <= map.ia.movement_map[tmp_x][tmp_y] and self.team == 1
			condition_2 = map.ia.movement_map[next_x][next_y] >= map.ia.movement_map[tmp_x][tmp_y] and self.team == 2
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
	var flags

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
		self.flags = {1: 0, 2: 0}
	
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
		instance.remove_influence(self, x, y)
		self.board[x][y] = 0
		instance.delete(self)
		
	func remove_all_players():
		for x in range(self.width):
			for y in range(self.height):
				self.remove_object(x,y)

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

class Menu:
	var object
	var map
	var buttons
	
	func _init(object, map):
		self.object = object
		self.map = map
		
		buttons = {}
		for button_name in ['start', 'stop', 'status', 'positions', 'reset', 'edit', 'option', 'score', 'max_flags']:
			self.buttons[button_name] = object.get_node(button_name)

		self.buttons['option'].add_item('Blue', 1)
		self.buttons['option'].add_item('Green', 2)
		self.buttons['option'].select(0)

		for x in range(5, 20, 5):
			self.buttons['max_flags'].add_item(str(x))

		self.buttons['status'].set_text('Stopped ...')
	
	func get_max_score():
		var button = self.buttons['max_flags']
		return int(button.get_item_text(button.get_selected()))
	
	func selected():
		return self.buttons['option'].get_selected()+1
		
	func get_status():
		return self.buttons['status'].get_text()

	func update(delta):
		if self.buttons['start'].is_pressed():
			self.buttons['status'].set_text('Running ...')
		elif self.buttons['stop'].is_pressed():
			self.buttons['status'].set_text('Stopped ...')
		elif self.buttons['reset'].is_pressed():
			self.buttons['status'].set_text('Stopped ...')
			self.map.remove_all_players()
			self.map.flags  = {1: 0, 2: 0}
		elif self.buttons['edit'].is_pressed():
			self.buttons['status'].set_text('Editing ...')
		elif self.buttons['positions'].is_pressed():
			self.buttons['status'].set_text('Players ready ...')
			self.map.create_players()
		self.buttons['score'].set_text('Blue '+str(map.flags[1])+'  -  Green '+str(map.flags[2]))
		if (self.map.flags[1] >= self.get_max_score()):
			self.buttons['status'].set_text('The blue team won.')
		elif self.map.flags[2] >= self.get_max_score():
			self.buttons['status'].set_text('The green team won.')

class Game:
	var menu
	var map

	func _init(width, height, object, menu=null):
		self.map = Field.new(width, height, object)
		self.menu  = Menu.new(object.get_node('menu'), self.map)

	func update(delta):
		menu.update(delta)
		if (menu.get_status() == 'Running ...'):
			map.update(delta)

	func get_status():
		return self.menu.get_status()

# GAME
var game
func _ready():
	game = Game.new(40, 30, get_node('.'))
	set_process(true)
	set_process_input(true)

func _process(delta):
	game.update(delta)

func _input(ev):
	if (ev.type==InputEvent.MOUSE_BUTTON):
		if ev.pressed and game.get_status() == "Editing ...":
			var x = int(ev.pos.x) / game.map.tile_size
			var y = int(ev.pos.y) / game.map.tile_size
			if x > game.map.width or y > game.map.height:
				return
			if ev.button_index == BUTTON_LEFT:
				var p1 = Player.new(game.menu.selected())
				game.map.set_object(p1, x, y)
			elif ev.button_index == BUTTON_RIGHT:
				game.map.remove_object(x,y)