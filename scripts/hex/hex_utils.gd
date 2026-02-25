class_name HexUtils
## Static utility class for hex coordinate math.
## Uses axial coordinates (q, r) with flat-top hex orientation.

## Convert axial hex coordinate to pixel position (center of hex).
static func axial_to_pixel(hex: Vector2i) -> Vector2:
	var x: float = Constants.HEX_SIZE * (1.5 * hex.x)
	var y: float = Constants.HEX_SIZE * (sqrt(3.0) / 2.0 * hex.x + sqrt(3.0) * hex.y)
	return Vector2(x, y)

## Convert pixel position to axial hex coordinate (rounded).
static func pixel_to_axial(pixel: Vector2) -> Vector2i:
	var q: float = (2.0 / 3.0 * pixel.x) / Constants.HEX_SIZE
	var r: float = (-1.0 / 3.0 * pixel.x + sqrt(3.0) / 3.0 * pixel.y) / Constants.HEX_SIZE
	return axial_round(Vector2(q, r))

## Round fractional axial coordinates to the nearest hex.
static func axial_round(frac: Vector2) -> Vector2i:
	var q: float = frac.x
	var r: float = frac.y
	var s: float = -q - r
	var rq: int = roundi(q)
	var rr: int = roundi(r)
	var rs: int = roundi(s)
	var q_diff: float = absf(rq - q)
	var r_diff: float = absf(rr - r)
	var s_diff: float = absf(rs - s)
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	return Vector2i(rq, rr)

## Get the 6 neighboring hex coordinates.
static func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in Constants.HEX_DIRECTIONS:
		neighbors.append(hex + dir)
	return neighbors

## Manhattan distance between two hex coordinates.
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = absi(a.x - b.x)
	var dr: int = absi(a.y - b.y)
	var ds: int = absi((-a.x - a.y) - (-b.x - b.y))
	return maxi(dq, maxi(dr, ds))

## Check if two hexes are neighbors.
static func are_neighbors(a: Vector2i, b: Vector2i) -> bool:
	return hex_distance(a, b) == 1

## Get all hexes within a given radius (filled circle).
static func hex_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			results.append(center + Vector2i(q, r))
	return results

## Get hexes forming a ring at exact distance from center.
static func hex_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	if radius == 0:
		return [center]
	var results: Array[Vector2i] = []
	var hex: Vector2i = center + Constants.HEX_DIRECTIONS[4] * radius  # Start SW
	for i in range(6):
		for _j in range(radius):
			results.append(hex)
			hex = hex + Constants.HEX_DIRECTIONS[i]
	return results

## Draw a line between two hexes (for line-of-sight, route visualization).
static func hex_linedraw(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n: int = hex_distance(a, b)
	if n == 0:
		return [a]
	var results: Array[Vector2i] = []
	var a_pixel: Vector2 = axial_to_pixel(a)
	var b_pixel: Vector2 = axial_to_pixel(b)
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		var lerped: Vector2 = a_pixel.lerp(b_pixel, t)
		# Add small nudge to avoid landing exactly on hex edges
		lerped += Vector2(1e-6, 1e-6)
		results.append(pixel_to_axial(lerped))
	return results

## Get the 6 corner points of a hex in pixel coordinates (for drawing).
static func get_hex_corners(center: Vector2, size: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i in range(6):
		var angle_deg: float = 60.0 * i
		var angle_rad: float = deg_to_rad(angle_deg)
		corners.append(center + Vector2(cos(angle_rad), sin(angle_rad)) * size)
	return corners

## Get the 6 corner points relative to origin (for _draw calls).
static func get_hex_corners_local(size: float) -> PackedVector2Array:
	return get_hex_corners(Vector2.ZERO, size)
