import '../models/mystery_box_record.dart';
class MysteryBoxItem {
  final String name;
  final int count;
  final String? rarity;
  final String? imageUrl;

  MysteryBoxItem({
    required this.name,
    required this.count,
    this.rarity,
    this.imageUrl,
  });

  factory MysteryBoxItem.fromRecord(MysteryBoxRecord record) {
    return MysteryBoxItem(
      name: record.name,
      count: record.count,
      imageUrl: record.imageUrl,
    );
  }

  MysteryBoxItem copyWith({
    String? name,
    int? count,
    String? rarity,
    String? imageUrl,
  }) {
    return MysteryBoxItem(
      name: name ?? this.name,
      count: count ?? this.count,
      rarity: rarity ?? this.rarity,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MysteryBoxItem && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}
