// class BiMap {
//
//   static Map<V, K> inverse<K, V>(Map<K, V> m) {
//     m.map((k, v) => MapEntry(v, k));
//   }
//
// }


class BiMap<K, V> implements Map<K, V> {
   Map<K, V> _mapForward = new Map<K, V>();
   Map<V, K> _mapInverse = new Map<V, K>();

   K inverse(V value) {
     return _mapInverse[value];
   }

  @override
  V operator [](Object key) {
    return _mapForward[key];
  }

  @override
  void operator []=(K key, V value) {
     if (_mapForward.containsValue(key)) {
       V value = _mapForward[key];
       _mapInverse.remove(value);
       _mapForward.remove(key);
     }

     _mapForward[key] = value;
     _mapInverse[value] = key;
  }

  @override
  void addAll(Map<K, V> other) {
    // TODO: implement addAll
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    // TODO: implement addEntries
  }

  @override
  Map<RK, RV> cast<RK, RV>() {
    // TODO: implement cast
    throw UnimplementedError();
  }

  @override
  void clear() {
    // TODO: implement clear
  }

  @override
  bool containsKey(Object key) {
    return _mapForward.containsKey(key);
  }

  @override
  bool containsValue(Object value) {
    return _mapForward.containsValue(value);
  }

  @override
  // TODO: implement entries
  Iterable<MapEntry<K, V>> get entries => throw UnimplementedError();

  @override
  void forEach(void Function(K key, V value) f) {
    // TODO: implement forEach
  }

  @override
  // TODO: implement isEmpty
  bool get isEmpty => _mapForward.isEmpty;

  @override
  // TODO: implement isNotEmpty
  bool get isNotEmpty => _mapForward.isNotEmpty;

  @override
  // TODO: implement keys
  Iterable<K> get keys => _mapForward.keys;

  @override
  // TODO: implement length
  int get length => _mapForward.length;

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    // TODO: implement putIfAbsent
    throw UnimplementedError();
  }

  @override
  V remove(Object key) {
    _mapInverse.remove(_mapForward[key]);
    return _mapForward.remove(key);
  }

  @override
  void removeWhere(bool Function(K key, V value) predicate) {
    // TODO: implement removeWhere
  }

  @override
  V update(K key, V Function(V value) update, {V Function() ifAbsent}) {
    // TODO: implement update
    throw UnimplementedError();
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    // TODO: implement updateAll
  }

  @override
  // TODO: implement values
  Iterable<V> get values => _mapInverse.keys;

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) f) {
    // TODO: implement map
    throw UnimplementedError();
  }



}