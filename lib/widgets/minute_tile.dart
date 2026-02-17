import 'package:flutter/material.dart';
import 'package:billyalarm/models/minute_item.dart';
import 'package:billyalarm/ui/theme.dart';

class MinuteTile extends StatelessWidget {
  final MinuteItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;

  const MinuteTile({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.remark != null && item.remark!.isNotEmpty)
                        Text(
                          item.remark!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textColor.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (item.ringtoneTitle != null)
                        Text(
                          ' - ${item.ringtoneTitle!}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.accentColor,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${item.minute.toString().padLeft(2, '0')}分',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentColor,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildIconButton(Icons.play_arrow, onTest, '立即测试'),
                const SizedBox(width: 12),
                _buildIconButton(Icons.edit, onEdit, '编辑'),
                const SizedBox(width: 12),
                _buildIconButton(Icons.delete, onDelete, '删除'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, String tooltip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.accentColor),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 22,
      ),
    );
  }
}
