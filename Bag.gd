


class_name Bag 
extends RefCounted


# the items
var _items: Array = []
# their weights
var _weights: Array[int] = []

# the sum of the weights
var _total: int = 0


# the remaining items in the bag (in case we want to remove them as we grab them)
var _remaining: Array[int] = []

# the sum of the remaining weights in the bag
var _remaining_total: int = 0

var _rng: RandomNumberGenerator

func _init(rng: RandomNumberGenerator = null) -> void:
    if rng:
        _rng = rng
    else:
        _rng = RandomNumberGenerator.new()
        _rng.randomize()

func add(item: Variant, weight: int = 1) -> void:
    assert(weight > 0.0, "Weight must be positive")
    _items.append(item)
    _weights.append(weight)
    _remaining.append(weight)
    _total += weight
    _remaining_total += weight

func size() -> int:
    return _items.size()

func is_empty() -> bool:
    return _items.is_empty()

func draw() -> Variant:
    if is_empty():
        return null
    var roll := _rng.randi_range(0, _total - 1)
    var acc := 0.0
    for i in _weights.size():
        acc += _weights[i]
        if roll < acc:
            return _items[i]
	
    return null

func draw_unique() -> Variant:
    if _remaining_total <= 0:
        return null
    var roll := _rng.randi_range(0, _remaining_total - 1)
    var acc := 0
    for i in _remaining.size():
        if _remaining[i] <= 0:
            continue
        acc += _remaining[i]
        if roll < acc:
            _remaining_total -= _remaining[i]
            _remaining[i] = 0
            return _items[i]
    return null

func draw_cycle() -> Variant:
    if _remaining_total <= 0:
        refill()
    return draw_unique()

func refill() -> void:
    _remaining = _weights.duplicate()
    _remaining_total = _total

func clear() -> void:
    _items.clear()
    _weights.clear()
    _remaining.clear()
    _total = 0
    _remaining_total = 0


func probabilities() -> Array:
    var result := []
    if _total == 0:
        return result
    for i in _items.size():
        result.append({
			"item": _items[i], 
			"weight": _weights[i], 
			"percent": (_weights[i] * 100.0) / _total
		})
    return result


func probabilities_remaining() -> Array:
    var result := []
    if _remaining_total == 0:
        return result
    for i in _items.size():
        if _remaining[i] > 0:
            result.append({
                "item": _items[i],
                "weight": _remaining[i],
                "percent": (_remaining[i] * 100.0) / _remaining_total,
            })
    return result