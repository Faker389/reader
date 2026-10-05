import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../core/utils/json.dart';

/// A typed, in-memory cached collection persisted to a Hive box.
///
/// Reads are served from memory (no decoding on every access); writes update
/// the cache immediately and persist asynchronously. Listeners receive the
/// full list after every change.
class JsonStore<T> {
  JsonStore({
    required Box<String> box,
    required T Function(JsonMap json) decode,
    required JsonMap Function(T value) encode,
    required String Function(T value) idOf,
  })  : _box = box,
        _encode = encode,
        _idOf = idOf {
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        final value = decode(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        _cache[key.toString()] = value;
      } on Object catch (e) {
        debugPrint('JsonStore: skipping unreadable record $key: $e');
      }
    }
  }

  final Box<String> _box;
  final JsonMap Function(T value) _encode;
  final String Function(T value) _idOf;
  final Map<String, T> _cache = {};
  final StreamController<List<T>> _changes = StreamController<List<T>>.broadcast();

  List<T> get all => List<T>.unmodifiable(_cache.values);
  int get length => _cache.length;

  T? get(String id) => _cache[id];

  bool contains(String id) => _cache.containsKey(id);

  Stream<List<T>> watch() async* {
    yield all;
    yield* _changes.stream;
  }

  Future<void> put(T value) async {
    final id = _idOf(value);
    _cache[id] = value;
    _emit();
    await _persist(() => _box.put(id, jsonEncode(_encode(value))));
  }

  Future<void> putAll(Iterable<T> values) async {
    final entries = <String, String>{};
    for (final value in values) {
      final id = _idOf(value);
      _cache[id] = value;
      entries[id] = jsonEncode(_encode(value));
    }
    if (entries.isEmpty) return;
    _emit();
    await _persist(() => _box.putAll(entries));
  }

  Future<void> delete(String id) async {
    if (_cache.remove(id) == null) return;
    _emit();
    await _persist(() => _box.delete(id));
  }

  Future<void> clear() async {
    _cache.clear();
    _emit();
    await _persist(_box.clear);
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(all);
  }

  Future<void> _persist(Future<Object?> Function() write) async {
    if (!_box.isOpen) return;
    await write();
  }

  Future<void> dispose() => _changes.close();
}

/// Simple JSON key-value access for singleton records (profile, drafts).
class KeyValueStore {
  KeyValueStore(this._box);

  final Box<String> _box;

  JsonMap? getJson(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on Object {
      return null;
    }
  }

  Future<void> putJson(String key, JsonMap value) async {
    if (!_box.isOpen) return;
    await _box.put(key, jsonEncode(value));
  }

  List<String> getStringList(String key) {
    final raw = _box.get(key);
    if (raw == null) return const [];
    try {
      return [for (final v in jsonDecode(raw) as List) v.toString()];
    } on Object {
      return const [];
    }
  }

  Future<void> putStringList(String key, List<String> values) async {
    if (!_box.isOpen) return;
    await _box.put(key, jsonEncode(values));
  }

  String? getString(String key) => _box.get(key);

  Future<void> putString(String key, String value) async {
    if (!_box.isOpen) return;
    await _box.put(key, value);
  }

  Future<void> remove(String key) async {
    if (!_box.isOpen) return;
    await _box.delete(key);
  }
}
