import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/bullet.dart';
import '../models/collection.dart';

class BujoProvider with ChangeNotifier {
  List<Bullet> _bullets = [];
  List<Collection> _collections = []; 
  
  DateTime _focusDate = DateTime(
    DateTime.now().year, 
    DateTime.now().month, 
    DateTime.now().day
  );

  List<Bullet> get bullets => _bullets;
  List<Collection> get collections => _collections;
  DateTime get focusDate => _focusDate;

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final String? collectionsJson = prefs.getString('collections');
    if (collectionsJson != null) {
      final List<dynamic> decoded = json.decode(collectionsJson);
      _collections = decoded.map((item) => Collection.fromMap(item)).toList();
    }

    final String? bulletsJson = prefs.getString('bullets');
    if (bulletsJson != null) {
      final List<dynamic> decoded = json.decode(bulletsJson);
      _bullets = decoded.map((item) => Bullet.fromMap(item)).toList();
    }
    
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String collectionsJson = json.encode(_collections.map((c) => c.toMap()).toList());
    await prefs.setString('collections', collectionsJson);
    final String bulletsJson = json.encode(_bullets.map((b) => b.toMap()).toList());
    await prefs.setString('bullets', bulletsJson);
  }

  void setFocusDate(DateTime date) {
    _focusDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

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

  void addCollection(String name) {
    _collections.add(Collection(id: const Uuid().v4(), name: name));
    _saveData();
    notifyListeners();
  }

  void renameCollection(String id, String newName) {
    final index = _collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      _collections[index].name = newName;
      _saveData();
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
    _saveData();
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
      status: BulletStatus.open,
      collectionId: collectionId,
    );
    _bullets.add(newBullet);
    _saveData();
    notifyListeners();
  }

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
      DateTime? normalizedDate;
      if (date != null) {
        normalizedDate = DateTime(date.year, date.month, date.day);
        if (scope == BulletScope.week) normalizedDate = getStartOfWeek(date);
        if (scope == BulletScope.month) normalizedDate = DateTime(date.year, date.month, 1);
        if (scope == BulletScope.year) normalizedDate = DateTime(date.year, 1, 1);
      }

      _bullets[index] = Bullet(
        id: b.id,
        content: content,
        type: type,
        date: normalizedDate,
        scope: scope,
        collectionId: collectionId,
        status: b.status, 
      );
      
      _saveData();
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
        status: bullet.status,
        type: bullet.type,
        date: targetDate,
        scope: newScope,
        collectionId: bullet.collectionId, 
      );
      _bullets.add(updatedBullet);
      _saveData();
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
    _saveData();
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
    _saveData();
    notifyListeners();
  }

  // 【核心修改】状态切换逻辑
  // 点击图标：
  // 如果是 Open -> 变 Completed
  // 如果是 Completed -> 变 Open (回退)
  // 如果是 Cancelled -> 变 Open (回退)
  void toggleStatus(String id) {
    final index = _bullets.indexWhere((b) => b.id == id);
    if (index != -1) {
      BulletStatus current = _bullets[index].status;
      BulletStatus newStatus;
      
      if (current == BulletStatus.open) {
        newStatus = BulletStatus.completed;
      } else {
        // 无论是 completed 还是 cancelled，点击都重置为 open
        newStatus = BulletStatus.open;
      }
      
      _changeStatusInternal(index, newStatus);
    }
  }

  // 侧滑指定状态 (完成 或 废弃)
  void changeStatus(String id, BulletStatus status) {
    final index = _bullets.indexWhere((b) => b.id == id);
    if (index != -1) {
      _changeStatusInternal(index, status);
    }
  }

  void _changeStatusInternal(int index, BulletStatus newStatus) {
    _bullets[index] = Bullet(
      id: _bullets[index].id,
      content: _bullets[index].content,
      date: _bullets[index].date,
      type: _bullets[index].type,
      scope: _bullets[index].scope,
      collectionId: _bullets[index].collectionId,
      status: newStatus,
    );
    _saveData();
    notifyListeners();
  }

  void deleteBullet(String id) {
    _bullets.removeWhere((b) => b.id == id);
    _saveData();
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