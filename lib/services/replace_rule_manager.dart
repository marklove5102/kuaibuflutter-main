import 'dart:convert';
import 'dart:io';
import 'database_helper.dart';

/// 替换规则模型
class ReplaceRule {
  int? id;
  bool enabled;
  String scope;
  String scopeValue;
  String bookScope;
  String bookName;
  String replaceType;
  String findText;
  String replaceText;

  ReplaceRule({
    this.id,
    this.enabled = true,
    this.scope = 'all_sites',
    this.scopeValue = '',
    this.bookScope = 'all_books',
    this.bookName = '',
    this.replaceType = 'normal',
    required this.findText,
    this.replaceText = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'enabled': enabled ? 1 : 0,
      'scope': scope,
      'scope_value': scopeValue,
      'book_scope': bookScope,
      'book_name': bookName,
      'replace_type': replaceType,
      'find_text': findText,
      'replace_text': replaceText,
    };
  }

  factory ReplaceRule.fromMap(Map<String, dynamic> map) {
    return ReplaceRule(
      id: map['id'],
      enabled: map['enabled'] == 1,
      scope: map['scope'] ?? 'all_sites',
      scopeValue: map['scope_value'] ?? '',
      bookScope: map['book_scope'] ?? 'all_books',
      bookName: map['book_name'] ?? '',
      replaceType: map['replace_type'] ?? 'normal',
      findText: map['find_text'] ?? '',
      replaceText: map['replace_text'] ?? '',
    );
  }
}

/// 替换规则管理器
class ReplaceRuleManager {
  static final ReplaceRuleManager _instance = ReplaceRuleManager._internal();
  factory ReplaceRuleManager() => _instance;
  ReplaceRuleManager._internal();

  bool _initialized = false;

  /// 初始化
  Future<void> init() async {
    if (_initialized) return;
    await DatabaseHelper().init();
    _initialized = true;
  }

  /// 获取所有规则
  Future<List<ReplaceRule>> getAllRules() async {
    final db = DatabaseHelper().replaceDb;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'replace_rules',
      orderBy: 'id ASC',
    );
    
    return maps.map((map) => ReplaceRule.fromMap(map)).toList();
  }

  /// 获取单个规则
  Future<ReplaceRule?> getRule(int ruleId) async {
    final db = DatabaseHelper().replaceDb;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'replace_rules',
      where: 'id = ?',
      whereArgs: [ruleId],
    );
    
    if (maps.isEmpty) return null;
    return ReplaceRule.fromMap(maps.first);
  }

  /// 添加规则
  Future<int> addRule(ReplaceRule rule) async {
    final db = DatabaseHelper().replaceDb;
    
    return await db.insert('replace_rules', rule.toMap());
  }

  /// 更新规则
  Future<bool> updateRule(ReplaceRule rule) async {
    if (rule.id == null) return false;
    
    final db = DatabaseHelper().replaceDb;
    
    final count = await db.update(
      'replace_rules',
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
    
    return count > 0;
  }

  /// 删除规则
  Future<bool> deleteRule(int ruleId) async {
    final db = DatabaseHelper().replaceDb;
    
    final count = await db.delete(
      'replace_rules',
      where: 'id = ?',
      whereArgs: [ruleId],
    );
    
    return count > 0;
  }

  /// 批量删除规则
  Future<bool> deleteRules(List<int> ruleIds) async {
    final db = DatabaseHelper().replaceDb;
    
    final placeholders = List.filled(ruleIds.length, '?').join(',');
    final count = await db.delete(
      'replace_rules',
      where: 'id IN ($placeholders)',
      whereArgs: ruleIds,
    );
    
    return count > 0;
  }

  /// 刷新规则ID使其连续
  Future<bool> refreshRuleIds() async {
    final db = DatabaseHelper().replaceDb;
    
    await db.transaction((txn) async {
      // 获取所有规则
      final rules = await txn.query('replace_rules', orderBy: 'id ASC');
      
      // 删除原表
      await txn.execute('DROP TABLE replace_rules');
      
      // 重新创建表
      await txn.execute('''
        CREATE TABLE replace_rules (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          enabled INTEGER DEFAULT 1,
          scope TEXT DEFAULT 'all_sites',
          scope_value TEXT DEFAULT '',
          book_scope TEXT DEFAULT 'all_books',
          book_name TEXT DEFAULT '',
          replace_type TEXT DEFAULT 'normal',
          find_text TEXT NOT NULL,
          replace_text TEXT DEFAULT ''
        )
      ''');
      
      // 重新插入数据
      for (int i = 0; i < rules.length; i++) {
        final rule = Map<String, dynamic>.from(rules[i]);
        rule.remove('id');
        await txn.insert('replace_rules', rule);
      }
    });
    
    return true;
  }

  /// 导出规则到JSON文件
  Future<bool> exportRules(String filePath) async {
    final rules = await getAllRules();
    
    // 转换为JSON格式（与原应用兼容）
    final jsonRules = rules.map((rule) {
      // 组合书名和网站信息到scope字段
      String scopeText = '';
      if (rule.bookScope == 'specific_book' && rule.bookName.isNotEmpty) {
        scopeText = rule.bookName;
      }
      if (rule.scope == 'specific_site' && rule.scopeValue.isNotEmpty) {
        if (scopeText.isNotEmpty) {
          scopeText += '; ${rule.scopeValue}';
        } else {
          scopeText = rule.scopeValue;
        }
      }
      
      return {
        'id': rule.id,
        'isEnabled': rule.enabled,
        'isRegex': rule.replaceType == 'regex',
        'name': rule.findText.length > 20 
            ? rule.findText.substring(0, 20) 
            : rule.findText.isEmpty ? '未命名' : rule.findText,
        'order': rule.id,
        'pattern': rule.findText,
        'replacement': rule.replaceText,
        'scope': scopeText,
        'scopeContent': true,
        'scopeTitle': false,
        'timeoutMillisecond': 3000,
      };
    }).toList();
    
    final file = File(filePath);
    await file.writeAsString(jsonEncode(jsonRules));
    
    return true;
  }

  /// 从JSON文件导入规则
  Future<bool> importRules(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    
    final content = await file.readAsString();
    final List<dynamic> jsonRules = jsonDecode(content);
    
    final db = DatabaseHelper().replaceDb;
    
    await db.transaction((txn) async {
      for (final jsonRule in jsonRules) {
        // 解析scope字段
        String scopeText = jsonRule['scope'] ?? '';
        String bookScope = 'all_books';
        String bookName = '';
        String scope = 'all_sites';
        String scopeValue = '';
        
        if (scopeText.contains(';')) {
          final parts = scopeText.split(';');
          bookName = parts[0].trim();
          scopeValue = parts[1].trim();
          
          if (bookName.isNotEmpty) {
            bookScope = 'specific_book';
          }
          if (scopeValue.isNotEmpty) {
            scope = 'specific_site';
          }
        } else if (scopeText.isNotEmpty) {
          scope = 'specific_site';
          scopeValue = scopeText;
        }
        
        final rule = ReplaceRule(
          enabled: jsonRule['isEnabled'] ?? true,
          scope: scope,
          scopeValue: scopeValue,
          bookScope: bookScope,
          bookName: bookName,
          replaceType: jsonRule['isRegex'] == true ? 'regex' : 'normal',
          findText: jsonRule['pattern'] ?? '',
          replaceText: jsonRule['replacement'] ?? '',
        );
        
        await txn.insert('replace_rules', rule.toMap());
      }
    });
    
    // 刷新规则ID
    await refreshRuleIds();
    
    return true;
  }

  /// 应用替换规则到文本
  String applyRules(String text, String siteUrl, String bookName) {
    // 由于Dart中无法同步查询数据库，这里返回原文本
    // 实际使用时需要在调用处异步获取规则并应用
    return text;
  }

  /// 应用替换规则（异步版本）
  Future<String> applyRulesAsync(String text, String siteUrl, String bookName) async {
    final db = DatabaseHelper().replaceDb;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'replace_rules',
      where: 'enabled = 1',
    );
    
    String result = text;
    
    for (final map in maps) {
      final rule = ReplaceRule.fromMap(map);
      
      // 检查站点范围
      bool siteMatch = false;
      if (rule.scope == 'all_sites') {
        siteMatch = true;
      } else if (rule.scope == 'specific_site' && siteUrl.contains(rule.scopeValue)) {
        siteMatch = true;
      }
      
      // 检查书籍范围
      bool bookMatch = false;
      if (rule.bookScope == 'all_books') {
        bookMatch = true;
      } else if (rule.bookScope == 'specific_book') {
        if (rule.bookName.isEmpty || rule.bookName == bookName) {
          bookMatch = true;
        }
      }
      
      if (siteMatch && bookMatch) {
        if (rule.replaceType == 'normal') {
          result = result.replaceAll(rule.findText, rule.replaceText);
        } else if (rule.replaceType == 'regex') {
          try {
            final regex = RegExp(rule.findText, multiLine: true);
            result = result.replaceAll(regex, rule.replaceText);
          } catch (e) {
            // 忽略正则错误
          }
        }
      }
    }
    
    return result;
  }
}
