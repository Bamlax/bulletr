import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/bullet.dart';
import '../models/collection.dart';

class BujoProvider with ChangeNotifier {
  final List<Bullet> _bullets = [];
  final List<Collection> _collections = []; 
  
  DateTime _focusDate = DateTime(
    DateTime.now().year, 
    DateTime.now().month, 
    DateTime.now().day
  );

  List<Bullet> get bullets => _bullets;
  List<Collection> get collections => _collections;
  DateTime get focusDate => _focusDate;

  void setFocusDate(DateTime date) {
    _focusDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  // --- 查询逻辑 ---

  List<Bullet> getBulletsByScope(DateTime date, BulletScope scope) {
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    return _bullets.where((b) {
      if (b.date == null) return false; 
      if (b.scope != scope) return false;
      
      if (scope == BulletScope.day) {
        return isSameDay(b.date!, normalizedDate);
      } else if (scope == BulletScope.week) {
        DateTime startOfB = getStartOfWeek(b.date!);
        DateTime startOfTarget = getStartOfWeek(normalizedDate);
        return isSameDay(startOfB, startOfTarget);
      } else if (scope == BulletScope.month) {
        return b.date!.year == normalizedDate.year && b.date!.month == normalizedDate.month;
      } else {
        return b.date!.year == normalizedDate.year;
      }
    }).toList();
  }

  List<Bullet> getInboxBullets() {
    return _bullets.where((b) => b.date == null && b.collectionId == null).toList();
  }

  List<Bullet> getCollectionBullets(String collectionId) {
    return _bullets.where((b) => b.collectionId == collectionId).toList();
  }

  // --- 增删改逻辑 ---

  void addCollection(String name) {
    _collections.add(Collection(id: const Uuid().v4(), name: name));
    notifyListeners();
  }

  void renameCollection(String id, String newName) {
    final index = _collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      _collections[index].name = newName;
      notifyListeners();
    }
  }

  void deleteCollection(String id) {
    _collections.removeWhere((c) => c.id == id);
    for (var b in _bullets) {
      if (b.collectionId == id) {
        b.collectionId = null;
      }
    }
    notifyListeners();
  }

  void addBullet({
    required String content, 
    DateTime? date, 
    required String type, 
    required BulletScope scope,
    String? collectionId
  }) {
    DateTime? normalizedDate;
    if (date != null) {
      normalizedDate = DateTime(date.year, date.month, date.day);
      if (scope == BulletScope.week) normalizedDate = getStartOfWeek(date);
      if (scope == BulletScope.month) normalizedDate = DateTime(date.year, date.month, 1);
      if (scope == BulletScope.year) normalizedDate = DateTime(date.year, 1, 1);
    }

    final newBullet = Bullet(
      id: const Uuid().v4(),
      content: content,
      date: normalizedDate,
      type: type,
      scope: scope,
      collectionId: collectionId,
    );
    _bullets.add(newBullet);
    notifyListeners();
  }

  // 【核心修改】全量更新方法 (用于编辑框)
  void updateBulletFull(String id, {
    required String content,
    required String type,
    DateTime? date,
    required BulletScope scope,
    String? collectionId,
  }) {
    final index = _bullets.indexWhere((b) => b.id == id);
    if (index != -1) {
      var b = _bullets[index];
      
      // 处理日期归一化
      DateTime? normalizedDate;
      if (date != null) {
        normalizedDate = DateTime(date.year, date.month, date.day);
        if (scope == BulletScope.week) normalizedDate = getStartOfWeek(date);
        if (scope == BulletScope.month) normalizedDate = DateTime(date.year, date.month, 1);
        if (scope == BulletScope.year) normalizedDate = DateTime(date.year, 1, 1);
      }

      // 替换对象 (或者直接修改属性)
      // 这里直接修改属性，因为是内存对象引用
      b.content = content;
      b.type = type;
      b.date = normalizedDate;
      b.scope = scope;
      b.collectionId = collectionId;
      
      notifyListeners();
    }
  }

  void moveBullet(Bullet bullet, DateTime newDate, BulletScope newScope) {
    DateTime targetDate = DateTime(newDate.year, newDate.month, newDate.day);
    if (newScope == BulletScope.week) targetDate = getStartOfWeek(newDate);
    if (newScope == BulletScope.month) targetDate = DateTime(newDate.year, newDate.month, 1);
    if (newScope == BulletScope.year) targetDate = DateTime(newDate.year, 1, 1);

    final index = _bullets.indexWhere((b) => b.id == bullet.id);
    if (index != -1) {
      _bullets.removeAt(index);
      final updatedBullet = Bullet(
        id: bullet.id,
        content: bullet.content,
        isCompleted: bullet.isCompleted,
        type: bullet.type,
        date: targetDate,
        scope: newScope,
        collectionId: bullet.collectionId, 
      );
      _bullets.add(updatedBullet);
      notifyListeners();
    }
  }
  
  void reorderDailyBullets(DateTime date, int oldIndex, int newIndex) {
    List<Bullet> currentScopeBullets = getBulletsByScope(date, BulletScope.day);
    if (oldIndex < newIndex) newIndex -= 1;
    final itemToMove = currentScopeBullets[oldIndex];
    currentScopeBullets.removeAt(oldIndex);
    currentScopeBullets.insert(newIndex, itemToMove);
    
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    _bullets.removeWhere((b) => 
      b.scope == BulletScope.day && 
      b.date != null && 
      isSameDay(b.date!, normalizedDate)
    );
    
    _bullets.addAll(currentScopeBullets);
    notifyListeners();
  }
  
  void reorderCollectionBullets(String? collectionId, int oldIndex, int newIndex) {
    List<Bullet> list = collectionId == null 
        ? getInboxBullets() 
        : getCollectionBullets(collectionId);

    if (oldIndex < newIndex) newIndex -= 1;
    final itemToMove = list[oldIndex];
    list.removeAt(oldIndex);
    list.insert(newIndex, itemToMove);

    if (collectionId == null) {
       _bullets.removeWhere((b) => b.date == null && b.collectionId == null);
    } else {
       _bullets.removeWhere((b) => b.collectionId == collectionId);
    }
    _bullets.addAll(list);
    notifyListeners();
  }

  void toggleStatus(String id) {
    final index = _bullets.indexWhere((b) => b.id == id);
    if (index != -1) {
      _bullets[index].isCompleted = !_bullets[index].isCompleted;
      notifyListeners();
    }
  }

  void deleteBullet(String id) {
    _bullets.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
  
  DateTime getStartOfWeek(DateTime date) {
    DateTime cleanDate = DateTime(date.year, date.month, date.day);
    return cleanDate.subtract(Duration(days: cleanDate.weekday - 1));
  }
}