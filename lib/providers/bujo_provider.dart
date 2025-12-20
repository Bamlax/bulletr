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
  
  List<Collection> get collections {
    _collections.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _collections;
  }
  
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
    await prefs.setString('collections', json.encode(_collections.map((c) => c.toMap()).toList()));
    await prefs.setString('bullets', json.encode(_bullets.map((b) => b.toMap()).toList()));
  }

  void _touchCollection(String? collectionId) {
    if (collectionId == null) return;
    final index = _collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) _collections[index].updatedAt = DateTime.now();
  }

  void setFocusDate(DateTime date) {
    _focusDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  // --- 查询 ---
  List<Bullet> getBulletsByScope(DateTime date, BulletScope scope) {
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    List<Bullet> rawList = _bullets.where((b) {
      if (b.date == null) return false; 
      if (b.scope != scope) return false;
      if (scope == BulletScope.day) return isSameDay(b.date!, normalizedDate);
      if (scope == BulletScope.week) return isSameDay(getStartOfWeek(b.date!), getStartOfWeek(normalizedDate));
      if (scope == BulletScope.month) return b.date!.year == normalizedDate.year && b.date!.month == normalizedDate.month;
      return b.date!.year == normalizedDate.year;
    }).toList();
    return _sortBulletsHierarchically(rawList);
  }

  List<Bullet> getInboxBullets() {
    List<Bullet> rawList = _bullets.where((b) => b.date == null && b.collectionId == null).toList();
    return _sortBulletsHierarchically(rawList);
  }

  List<Bullet> getCollectionBullets(String collectionId) {
    List<Bullet> rawList = _bullets.where((b) => b.collectionId == collectionId).toList();
    return _sortBulletsHierarchically(rawList);
  }

  List<Bullet> _sortBulletsHierarchically(List<Bullet> rawList) {
    List<Bullet> sorted = [];
    Set<String> idsInList = rawList.map((b) => b.id).toSet();
    
    // 根节点
    List<Bullet> roots = rawList.where((b) => b.parentId == null || !idsInList.contains(b.parentId)).toList();
    
    // 按物理顺序(在_bullets中的顺序)排序
    roots.sort((a, b) => _bullets.indexOf(a).compareTo(_bullets.indexOf(b)));

    for (var root in roots) {
      _addNodeAndChildren(root, rawList, sorted);
    }
    return sorted;
  }

  void _addNodeAndChildren(Bullet node, List<Bullet> allNodes, List<Bullet> result) {
    result.add(node);
    List<Bullet> children = allNodes.where((b) => b.parentId == node.id).toList();
    children.sort((a, b) => _bullets.indexOf(a).compareTo(_bullets.indexOf(b)));
    for (var child in children) {
      _addNodeAndChildren(child, allNodes, result);
    }
  }

  int getBulletDepth(Bullet bullet) {
    int depth = 0;
    String? currentParentId = bullet.parentId;
    int safeGuard = 0;
    while (currentParentId != null && safeGuard < 10) {
      final parentIndex = _bullets.indexWhere((b) => b.id == currentParentId);
      if (parentIndex == -1) break;
      depth++;
      currentParentId = _bullets[parentIndex].parentId;
      safeGuard++;
    }
    return depth;
  }

  // --- 核心：插入逻辑 (用于 InsertionBar) ---
  // 将 activeId 插入到 prevId 之后 (如果 prevId 为 null，则插到最前面)
  // 同时处理上下文 (date, scope, collectionId)
  void insertBulletAfter({
    required String activeId, 
    required String? prevId, // 上一个任务的ID
    // 上下文信息 (目标列表的属性)
    required DateTime? targetDate,
    required BulletScope targetScope,
    required String? targetCollectionId,
  }) {
    if (activeId == prevId) return;

    final activeIndex = _bullets.indexWhere((b) => b.id == activeId);
    if (activeIndex == -1) return;
    final activeBullet = _bullets[activeIndex];

    // 1. 确定新的父节点 (ParentId)
    String? newParentId;

    if (prevId == null) {
      // 插到列表最顶部 -> 必然是根节点
      newParentId = null;
    } else {
      final prevIndex = _bullets.indexWhere((b) => b.id == prevId);
      if (prevIndex == -1) {
        newParentId = null; // 防御
      } else {
        final prevBullet = _bullets[prevIndex];
        // 智能判断规则：
        // 规则A：如果 prevBullet 有子节点 (且在当前视图中可见)，那么“插在 prev 后面”通常意味着“插在 prev 的第一个子节点位置”。
        //       但是！由于我们是展平列表，InsertionBar 是插在 prev 和 prev的下一个元素(可能是prev的子) 之间。
        //       如果列表中 prev 下面紧跟的是它的子节点，那我们在 prev 后面插入，实际上是想成为 prev 的**第一个子节点**。
        //       如果 prev 下面紧跟的是它的兄弟，那我们就是 prev 的**兄弟**。
        
        // 简化规则：
        // 默认成为 prev 的兄弟 (同级)。
        // 只有一种情况例外：如果 prev 是“展开”的父节点。但在扁平列表中，我们很难判断“展开”。
        // 这里采用最直观的逻辑：【跟随 prev 的层级】。
        // 即：prev 是谁的儿子，我也做谁的儿子。
        
        // 修正：用户说“无法拖出子记录”。
        // 如果 prevBullet 是一个子节点，那新任务也是子节点。
        // 如果 prevBullet 是根节点，那新任务也是根节点。
        // 这样就实现了“拖出来”：只要你把子任务拖到一个根任务的下面，它就变成了根任务。
        
        // 有一个特殊情况：如果 prevBullet 有子节点，我想让新任务成为它的子节点怎么办？
        // 答：拖到 prevBullet 的文本上 (嵌套功能)。
        // 所以，插入条只负责“同级插入”或“出坑”，不负责“入坑”。
        
        newParentId = prevBullet.parentId;
      }
    }

    // 2. 从旧位置移除
    _bullets.removeAt(activeIndex);

    // 3. 计算插入的物理位置
    int insertIndex = 0;
    if (prevId != null) {
      final newPrevIndex = _bullets.indexWhere((b) => b.id == prevId);
      // 插在 prev 后面。注意：如果 prev 有子树，物理上应该插在 prev 子树的后面吗？
      // 不，我们的 _sortBulletsHierarchically 会自动处理显示顺序。
      // 我们只需要保证在 _bullets 列表中，它位于 prev 后面即可 (为了保持根节点的相对顺序)。
      // 简单起见，直接插在 prev 后面。
      if (newPrevIndex != -1) {
        insertIndex = newPrevIndex + 1;
      }
    }

    // 4. 构建新对象
    final updatedBullet = Bullet(
      id: activeBullet.id,
      content: activeBullet.content,
      status: activeBullet.status,
      type: activeBullet.type,
      date: targetDate,
      scope: targetScope,
      collectionId: targetCollectionId,
      parentId: newParentId,
      updatedAt: DateTime.now(),
    );

    // 5. 插入
    _bullets.insert(insertIndex, updatedBullet);

    // 6. 级联更新子任务 (如果跨日期/集子移动)
    if (activeBullet.date != targetDate || activeBullet.collectionId != targetCollectionId) {
      _cascadeMoveChildren(activeBullet.id, targetDate, targetScope, targetCollectionId);
    }

    _touchCollection(targetCollectionId);
    _saveData();
    notifyListeners();
  }

  // --- 嵌套 ---
  void nestBullet({required String childId, required String? parentId}) {
    if (childId == parentId) return;
    final index = _bullets.indexWhere((b) => b.id == childId);
    if (index != -1) {
      if (parentId != null && _isDescendant(parentId, childId)) return;
      
      var b = _bullets[index];
      if (parentId != null) {
        final parent = _bullets.firstWhere((e) => e.id == parentId);
        _moveBulletInternal(b, parent.date, parent.scope, parent.collectionId, parentId);
      } else {
        // 这里的逻辑其实很少用到，因为拖到空白处走 insertBulletAfter 了
        _bullets[index] = Bullet(
          id: b.id, content: b.content, status: b.status, type: b.type,
          date: b.date, scope: b.scope, collectionId: b.collectionId,
          parentId: null, updatedAt: DateTime.now(),
        );
        _saveData();
        notifyListeners();
      }
    }
  }

  bool _isDescendant(String targetId, String potentialAncestorId) {
    String? current = targetId;
    int safeGuard = 0;
    while (current != null && safeGuard < 20) {
      final idx = _bullets.indexWhere((b) => b.id == current);
      if (idx == -1) return false;
      if (_bullets[idx].parentId == potentialAncestorId) return true;
      current = _bullets[idx].parentId;
      safeGuard++;
    }
    return false;
  }

  // --- CRUD (保持不变) ---
  void addCollection(String name) { _collections.add(Collection(id: const Uuid().v4(), name: name)); _saveData(); notifyListeners(); }
  void renameCollection(String id, String newName) { final index = _collections.indexWhere((c) => c.id == id); if (index != -1) { _collections[index].name = newName; _collections[index].updatedAt = DateTime.now(); _saveData(); notifyListeners(); } }
  void deleteCollection(String id) { _collections.removeWhere((c) => c.id == id); for (var i = 0; i < _bullets.length; i++) { if (_bullets[i].collectionId == id) { var b = _bullets[i]; _bullets[i] = Bullet(id: b.id, content: b.content, date: b.date, type: b.type, scope: b.scope, status: b.status, updatedAt: DateTime.now(), parentId: b.parentId, collectionId: null); } } _saveData(); notifyListeners(); }
  void addBullet({required String content, DateTime? date, required String type, required BulletScope scope, String? collectionId}) { DateTime? normalizedDate; if (date != null) { normalizedDate = DateTime(date.year, date.month, date.day); if (scope == BulletScope.week) normalizedDate = getStartOfWeek(date); if (scope == BulletScope.month) normalizedDate = DateTime(date.year, date.month, 1); if (scope == BulletScope.year) normalizedDate = DateTime(date.year, 1, 1); } final newBullet = Bullet(id: const Uuid().v4(), content: content, date: normalizedDate, type: type, scope: scope, status: BulletStatus.open, collectionId: collectionId, updatedAt: DateTime.now()); _bullets.add(newBullet); _touchCollection(collectionId); _saveData(); notifyListeners(); }
  void updateBulletFull(String id, {required String content, required String type, DateTime? date, required BulletScope scope, String? collectionId, String? parentId}) { final index = _bullets.indexWhere((b) => b.id == id); if (index != -1) { var b = _bullets[index]; bool isMove = (b.date != date || b.scope != scope || b.collectionId != collectionId); _bullets[index] = Bullet(id: b.id, content: content, type: type, date: date, scope: scope, collectionId: collectionId, status: b.status, updatedAt: DateTime.now(), parentId: parentId ?? b.parentId); if (isMove) { _cascadeMoveChildren(id, date, scope, collectionId); } _touchCollection(collectionId); _saveData(); notifyListeners(); } }
  void moveBullet(Bullet bullet, DateTime newDate, BulletScope newScope) { DateTime targetDate = DateTime(newDate.year, newDate.month, newDate.day); if (newScope == BulletScope.week) targetDate = getStartOfWeek(newDate); if (newScope == BulletScope.month) targetDate = DateTime(newDate.year, newDate.month, 1); if (newScope == BulletScope.year) targetDate = DateTime(newDate.year, 1, 1); _moveBulletInternal(bullet, targetDate, newScope, bullet.collectionId, null); }
  void _moveBulletInternal(Bullet bullet, DateTime? date, BulletScope scope, String? collectionId, String? newParentId) { final index = _bullets.indexWhere((b) => b.id == bullet.id); if (index != -1) { _bullets[index] = Bullet(id: bullet.id, content: bullet.content, status: bullet.status, type: bullet.type, date: date, scope: scope, collectionId: collectionId, updatedAt: DateTime.now(), parentId: newParentId); _cascadeMoveChildren(bullet.id, date, scope, collectionId); _touchCollection(bullet.collectionId); _saveData(); notifyListeners(); } }
  void _cascadeMoveChildren(String parentId, DateTime? date, BulletScope scope, String? collectionId) { List<Bullet> children = _bullets.where((b) => b.parentId == parentId).toList(); for (var child in children) { final idx = _bullets.indexWhere((b) => b.id == child.id); if (idx != -1) { _bullets[idx] = Bullet(id: child.id, content: child.content, status: child.status, type: child.type, date: date, scope: scope, collectionId: collectionId, updatedAt: DateTime.now(), parentId: parentId); _cascadeMoveChildren(child.id, date, scope, collectionId); } } }
  
  // 保留旧方法防止报错
  void reorderDailyBullets(DateTime date, int oldIndex, int newIndex) {}
  void reorderCollectionBullets(String? collectionId, int oldIndex, int newIndex) {}

  void toggleStatus(String id) { final index = _bullets.indexWhere((b) => b.id == id); if (index != -1) { BulletStatus current = _bullets[index].status; BulletStatus newStatus = (current == BulletStatus.open) ? BulletStatus.completed : BulletStatus.open; _changeStatusInternal(index, newStatus); } }
  void changeStatus(String id, BulletStatus status) { final index = _bullets.indexWhere((b) => b.id == id); if (index != -1) { _changeStatusInternal(index, status); } }
  void _changeStatusInternal(int index, BulletStatus newStatus) { _bullets[index] = Bullet(id: _bullets[index].id, content: _bullets[index].content, date: _bullets[index].date, type: _bullets[index].type, scope: _bullets[index].scope, collectionId: _bullets[index].collectionId, status: newStatus, updatedAt: DateTime.now(), parentId: _bullets[index].parentId); _touchCollection(_bullets[index].collectionId); _saveData(); notifyListeners(); }
  void deleteBullet(String id) { final index = _bullets.indexWhere((b) => b.id == id); if (index != -1) { _touchCollection(_bullets[index].collectionId); _cascadeDeleteChildren(id); _bullets.removeAt(index); _saveData(); notifyListeners(); } }
  void _cascadeDeleteChildren(String parentId) { List<String> childrenIds = _bullets.where((b) => b.parentId == parentId).map((b) => b.id).toList(); for (var childId in childrenIds) { _cascadeDeleteChildren(childId); _bullets.removeWhere((b) => b.id == childId); } }
  bool isSameDay(DateTime d1, DateTime d2) { return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day; }
  DateTime getStartOfWeek(DateTime date) { DateTime cleanDate = DateTime(date.year, date.month, date.day); return cleanDate.subtract(Duration(days: cleanDate.weekday - 1)); }
}