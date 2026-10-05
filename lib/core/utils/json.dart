/// Small helpers for reading loosely-typed JSON maps (Hive, Firestore) into
/// strongly-typed models without sprinkling casts everywhere.
typedef JsonMap = Map<String, dynamic>;

extension JsonRead on JsonMap {
  String str(String key, [String fallback = '']) {
    final value = this[key];
    return value is String ? value : fallback;
  }

  String? strOrNull(String key) {
    final value = this[key];
    return value is String ? value : null;
  }

  int integer(String key, [int fallback = 0]) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  double dbl(String key, [double fallback = 0]) {
    final value = this[key];
    return value is num ? value.toDouble() : fallback;
  }

  bool boolean(String key, [bool fallback = false]) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  DateTime? date(String key) {
    final value = this[key];
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    // Firestore Timestamp, without importing cloud_firestore here.
    if (value != null) {
      try {
        final dynamic dyn = value;
        final Object? converted = dyn.toDate();
        if (converted is DateTime) return converted;
      } on NoSuchMethodError {
        return null;
      }
    }
    return null;
  }

  T enumValue<T extends Enum>(String key, List<T> values, T fallback) {
    final name = this[key];
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  List<JsonMap> mapList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  List<String> stringList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return [for (final item in value) if (item is String) item];
  }
}

int? millis(DateTime? date) => date?.millisecondsSinceEpoch;
