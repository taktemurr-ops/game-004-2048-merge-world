/// Independent rules for locally playable 2048 variants.
/// No online accounts, tracking or monetization are required to play.
enum MergeMode { classic, bigBoard, daily, zen, timed }

extension MergeModeRules on MergeMode {
  int get boardSize => this == MergeMode.bigBoard ? 5 : 4;
  int? get timeLimitSeconds => this == MergeMode.timed ? 180 : null;
  bool get hasTimer => this == MergeMode.timed;
  int get target => this == MergeMode.bigBoard ? 4096 : 2048;
  String get storageKey => name;
}

/// UTC-day identifier, unaffected by the user's local timezone during the day.
/// The same day always starts with the same two tiles across devices.
int dailySeed(DateTime at) {
  final utc = at.toUtc();
  final day = DateTime.utc(utc.year, utc.month, utc.day);
  return day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

/// Converts a keyboard or accessibility direction to the existing game enum's
/// stable four-way controls. Kept UI-agnostic for deterministic testing.
String normalizedDirection(String value) {
  final text = value.toLowerCase().trim();
  if (const {'left', 'right', 'up', 'down'}.contains(text)) return text;
  throw ArgumentError.value(value, 'direction', 'Unsupported direction');
}
