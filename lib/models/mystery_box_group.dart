import '../models/mystery_box_item.dart';
import '../models/mystery_box_record.dart';

class MysteryBoxGroup {
  final String itemId;
  final String name;
  final String auth;
  final List<MysteryBoxItem> items;
  final List<String> completeList;
  final List<String> missingItems;
  final int totalObtained;

  MysteryBoxGroup({
    required this.itemId,
    required this.name,
    required this.auth,
    required this.items,
    required this.completeList,
    required this.missingItems,
    required this.totalObtained,
  });

  factory MysteryBoxGroup.fromRecords(
      String itemId,
      String name,
      String auth,
      List<MysteryBoxRecord> records,
      List<String> completeList,
      ) {
    // 按名称分组并统计数量
    final Map<String, MysteryBoxItem> itemMap = {};

    for (final record in records) {
      if (itemMap.containsKey(record.name)) {
        final existing = itemMap[record.name]!;
        itemMap[record.name] = existing.copyWith(count: existing.count + record.count);
      } else {
        itemMap[record.name] = MysteryBoxItem.fromRecord(record);
      }
    }

    final items = itemMap.values.toList();
    final obtainedNames = items.map((item) => item.name).toSet();
    final missingItems = completeList.where((item) => !obtainedNames.contains(item)).toList();
    final totalObtained = items.fold(0, (sum, item) => sum + item.count);

    return MysteryBoxGroup(
      itemId: itemId,
      name: name,
      auth: auth,
      items: items,
      completeList: completeList,
      missingItems: missingItems,
      totalObtained: totalObtained,
    );
  }

  double get completionRate {
    if (completeList.isEmpty) return 0.0;
    final obtainedCount = completeList.length - missingItems.length;
    return obtainedCount / completeList.length;
  }
}