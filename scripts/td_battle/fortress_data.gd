extends RefCounted
## Data container for a fortress layout in offense (PvE attack) mode.

var fortress_id: String
var fortress_name: String
var difficulty: int
var grid_cols: int = 20
var grid_rows: int = 11
var cell_size: int = 64
var entry_cells: Array[Vector2i] = []     # One per lane, column 0
var exit_cell: Vector2i = Vector2i(19, 5)
var obstacles: Array[Vector2i] = []       # Spines + internal
var towers: Array[Dictionary] = []        # {"cell": Vector2i, "type": String, "upgraded": bool}
var lanes: Array[Dictionary] = []         # {"profile": String, "row_range": Vector2i, "entry_cell": Vector2i}
var unit_budget: int = 20
var win_threshold: int = 3
