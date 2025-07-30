class MysteryBoxRecord {
  final String itemId;
  final String orderId;
  final String name;
  final int count;
  final String? imageUrl;
  final DateTime? createTime;

  MysteryBoxRecord({
    required this.itemId,
    required this.orderId,
    required this.name,
    this.count = 1,
    this.imageUrl,
    this.createTime,
  });

  factory MysteryBoxRecord.fromJson(Map<String, dynamic> json) {
    return MysteryBoxRecord(
      itemId: json['itemId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      count: json['count'] ?? 1,
      imageUrl: json['imageUrl']?.toString(),
      createTime: json['createTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'orderId': orderId,
      'name': name,
      'count': count,
      'imageUrl': imageUrl,
      'createTime': createTime?.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MysteryBoxRecord &&
        other.itemId == itemId &&
        other.orderId == orderId &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(itemId, orderId, name);
}