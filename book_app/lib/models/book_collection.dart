/// Bir kitabın rafta görünme biçimi.
enum ShelfDisplayMode { spine, face, stack }

ShelfDisplayMode shelfDisplayModeFromString(String? value) {
  switch (value) {
    case 'face':
      return ShelfDisplayMode.face;
    case 'stack':
      return ShelfDisplayMode.stack;
    default:
      return ShelfDisplayMode.spine;
  }
}

String shelfDisplayModeToString(ShelfDisplayMode mode) => switch (mode) {
  ShelfDisplayMode.face => 'face',
  ShelfDisplayMode.stack => 'stack',
  ShelfDisplayMode.spine => 'spine',
};

class BookCollection {
  const BookCollection({
    required this.id,
    required this.name,
    required this.color,
    required this.bookIds,
    this.displayModes = const {},
  });

  final int id;
  final String name;
  final String color;
  final List<int> bookIds;

  /// Kitap kimliği -> görünüm biçimi. Eksikse [ShelfDisplayMode.spine].
  final Map<int, ShelfDisplayMode> displayModes;

  ShelfDisplayMode displayModeFor(int bookId) =>
      displayModes[bookId] ?? ShelfDisplayMode.spine;

  BookCollection copyWith({Map<int, ShelfDisplayMode>? displayModes}) {
    return BookCollection(
      id: id,
      name: name,
      color: color,
      bookIds: bookIds,
      displayModes: displayModes ?? this.displayModes,
    );
  }

  factory BookCollection.fromJson(Map<String, dynamic> json) {
    int integer(dynamic value) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    final ids = json['book_ids'];
    final modesRaw = json['display_modes'];
    final modes = <int, ShelfDisplayMode>{};
    if (modesRaw is Map) {
      modesRaw.forEach((key, value) {
        final id = int.tryParse('$key');
        if (id != null) {
          modes[id] = shelfDisplayModeFromString(value?.toString());
        }
      });
    }
    return BookCollection(
      id: integer(json['id']),
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#6750E8',
      bookIds: ids is List ? ids.map(integer).toList() : const [],
      displayModes: modes,
    );
  }
}
