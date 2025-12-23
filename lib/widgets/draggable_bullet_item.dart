import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/bullet.dart';
import '../providers/bujo_provider.dart';

class DraggableBulletItem extends StatelessWidget {
  final Bullet bullet;
  final Widget child; 
  final String? collectionId; 

  const DraggableBulletItem({
    super.key,
    required this.bullet,
    required this.child,
    this.collectionId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BujoProvider>(context, listen: false);

    return LongPressDraggable<Bullet>(
      data: bullet,
      delay: const Duration(milliseconds: 300),
      feedback: Material(
        elevation: 6,
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Text(bullet.content, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: child,
      ),
      child: DragTarget<Bullet>(
        onWillAcceptWithDetails: (details) => details.data.id != bullet.id,
        onAcceptWithDetails: (details) {
          provider.nestBullet(childId: details.data.id, parentId: bullet.id);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          
          return Container(
            decoration: BoxDecoration(
              color: isHovering ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: child,
          );
        },
      ),
    );
  }
}