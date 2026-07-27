extends RefCounted
## Data container for a battle map definition.

var map_id: String
var map_name: String
var grid_cols: int = 20
var grid_rows: int = 11
var cell_size: int = 64
var spawn_cells: Array[Vector2i] = []
var exit_cell: Vector2i = Vector2i(19, 5)
var obstacles: Array[Vector2i] = []
var waves: Array = []  # Array of Dictionaries: {"normal": N, "fast": N, "armored": N}
var starting_gold: int = 100
var starting_lives: int = 20
