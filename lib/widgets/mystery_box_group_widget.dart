import 'package:flutter/material.dart';
import '../models/mystery_box_group.dart';
import '../pages/home_page_improved.dart';

class MysteryBoxGroupWidget extends StatefulWidget {
  final MysteryBoxGroup group;

  const MysteryBoxGroupWidget({
    super.key,
    required this.group,
  });

  @override
  State<MysteryBoxGroupWidget> createState() => _MysteryBoxGroupWidgetState();
}

class _MysteryBoxGroupWidgetState extends State<MysteryBoxGroupWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部信息
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.group.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 统计信息
                  Row(
                    children: [
                      _buildStatCard(
                        '已获得',
                        widget.group.totalObtained.toString(),
                        Icons.card_giftcard,
                        MorandiGreenTheme.cardPrimary,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        '端盒进度',
                        '${(widget.group.completionRate * 100).toStringAsFixed(1)}%',
                        Icons.percent,
                        MorandiGreenTheme.cardSecondary,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        '未抽到',
                        widget.group.missingItems.length.toString(),
                        Icons.help_outline,
                        MorandiGreenTheme.cardWarning,
                      ),
                    ],
                  ),

                  // 完成度进度条
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: widget.group.completionRate,
                    backgroundColor: colorScheme.onPrimaryContainer.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.group.completionRate >= 1.0 ? Colors.green : Colors.blue,
                    ),
                    minHeight: 6,
                  ),
                ],
              ),
            ),
          ),

          // 详细信息（可展开/收起）
          if (_isExpanded) ...[
            // 已获得物品列表
            if (widget.group.items.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                child: Text(
                  '已获得盲盒 (${widget.group.items.length} 种)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1),
                      },
                      children: [
                      // 表头
                      TableRow(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.5),
                        ),
                        children: [
                          _buildTableCell('物品名称', isHeader: true),
                          _buildTableCell('数量', isHeader: true),
                        ],
                      ),
                      // 数据行
                      ...widget.group.items.map((item) => TableRow(
                        children: [
                          _buildTableCell(item.name),
                          _buildTableCell(
                            item.count.toString(),
                            alignment: Alignment.center,
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            ],

            // 缺少物品列表
            if (widget.group.missingItems.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange.withOpacity(0.1),
                child: Text(
                  '缺少物品 (${widget.group.missingItems.length} 种)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.group.missingItems.map((item) {
                      return Chip(
                        label: Text(
                          item,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        side: BorderSide(color: Colors.orange.withOpacity(0.3)),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.6), width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, Alignment alignment = Alignment.centerLeft}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      alignment: alignment,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 14 : 13,
        ),
      ),
    );
  }
}