extends RefCounted

const RADIUS := 2
const EVEN := [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1),Vector2i(0,-1)]
const ODD := [Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1)]
const ROW := 0.8660254038

static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for step in ODD if cell.y & 1 else EVEN:
		result.append(cell + step)
	return result


static func axial(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x-(cell.y-(cell.y&1))/2,cell.y)


static func distance(first: Vector2i, second: Vector2i) -> int:
	var diff := axial(first)-axial(second)
	return maxi(maxi(absi(diff.x),absi(diff.y)),absi(diff.x+diff.y))


static func within(cell: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(cell.y-radius,cell.y+radius+1):
		for x in range(cell.x-radius,cell.x+radius+1):
			var candidate := Vector2i(x,y)
			if distance(cell,candidate)<=radius:
				result.append(candidate)
	return result


static func position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x+0.5*(cell.y&1),cell.y*ROW)


static func pick(point: Vector2) -> Vector2i:
	var row := roundi(point.y/ROW)
	var best := Vector2i.ZERO
	var score := INF
	for y in range(row-1,row+2):
		var cell := Vector2i(roundi(point.x-0.5*(y&1)),y)
		var cost := position(cell).distance_squared_to(point)
		if cost<score:
			score=cost
			best=cell
	return best
