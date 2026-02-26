extends Node
## Global constants for hex geometry, enums, and game configuration.

# --- Hex Geometry (flat-top) ---
const HEX_SIZE: float = 32.0  # Outer radius in pixels
const HEX_WIDTH: float = HEX_SIZE * 2.0
const HEX_HEIGHT: float = HEX_SIZE * sqrt(3.0)

# Flat-top hex: basis vectors for axial → pixel conversion
# q basis: (3/2 * size, sqrt(3)/2 * size)
# r basis: (0, sqrt(3) * size)
const HEX_Q_BASIS_X: float = HEX_SIZE * 1.5
const HEX_Q_BASIS_Y: float = HEX_SIZE * 0.8660254  # sqrt(3)/2
const HEX_R_BASIS_X: float = 0.0
const HEX_R_BASIS_Y: float = HEX_SIZE * 1.7320508  # sqrt(3)

# --- Map Defaults ---
const DEFAULT_MAP_WIDTH: int = 30
const DEFAULT_MAP_HEIGHT: int = 20

# --- Axial Direction Vectors (flat-top hex neighbors) ---
const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

# --- Enums ---
enum Player { PLAYER, AI }

enum TurnPhase {
	PLAYER_INPUT,
	AI_TURN,
	COMBAT_RESOLUTION,
	PRODUCTION,
	LOGISTICS,
	UPKEEP
}

enum UnitAction {
	IDLE,
	MOVE,
	ATTACK,
	FORTIFY
}

enum BuildingState {
	CONSTRUCTING,
	OPERATIONAL,
	DAMAGED
}

# --- Combat ---
const ADJACENCY_BONUS: float = 2.0
const FLANK_THRESHOLD: int = 3  # Number of enemy-adjacent sides for flanking
const FLANK_DAMAGE_MULTIPLIER: float = 1.5
const COMBAT_RANDOM_MIN: float = 0.8
const COMBAT_RANDOM_MAX: float = 1.2
const ZOC_MOVEMENT_COST: int = 99  # Zone of control effectively stops movement

# --- Logistics ---
const DEFAULT_ROUTE_CAPACITY: int = 1
const DEPOT_CAPACITY_BONUS: int = 1
