import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bullet.dart';
import '../providers/bujo_provider.dart';

class InsertionBar extends StatelessWidget {
  final String? prevBulletId; 
  final DateTime? targetDate;
  final BulletScope targetScope;
  final String? targetCollectionId;

  const InsertionBar({
    super.key,
    this.prevBulletId,
    this.targetDate,
    this.targetScope = BulletScope.none,
    this.targetCollectionId,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Bullet>(
      onWillAccept: (data) {
        if (data == null) return false;
        if (data.id == prevBulletId) return false;
        return true;
      },
      onAccept: (bullet) {
        Provider.of<BujoProvider>(context, listen: false).insertBulletAfter(
          activeId: bullet.id,
          prevId: prevBulletId,
          targetDate: targetDate,
          targetScope: targetScope,
          targetCollectionId: targetCollectionId,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        return Container(
          width: double.infinity,
          // 【核心修改】平时高度设为 2，极度紧凑；悬停时变大方便看
          height: isHovering ? 20 : 2, 
          color: Colors.transparent,
          child: Center(
            child: Container(
              height: 2,
              width: double.infinity,
              color: isHovering ? Colors.blue : Colors.transparent,
            ),
          ),
        );
      },
    );
  }
}