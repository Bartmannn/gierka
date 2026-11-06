class_name NoteCursor
extends RefCounted
## Przesuwa się po posortowanej liście nut razem z czasem utworu
## i zwraca nuty, które właśnie się zaczęły. Działa też dla listy Cue.

var _items: Array = []
var _index: int = 0


func _init(items: Array) -> void:
	_items = items


## Zwraca elementy (MidiNote lub Cue), których czas minął od poprzedniego wywołania.
func advance(time: float) -> Array:
	var started: Array = []
	while _index < _items.size() and _items[_index].time <= time:
		started.append(_items[_index])
		_index += 1
	return started


func reset() -> void:
	_index = 0
