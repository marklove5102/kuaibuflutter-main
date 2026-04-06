import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/replace_rule_manager.dart';

/// 替换规则列表页面
class ReplaceRulesPage extends StatefulWidget {
  final String? currentSiteUrl;
  final String? currentBookName;

  const ReplaceRulesPage({
    super.key,
    this.currentSiteUrl,
    this.currentBookName,
  });

  @override
  State<ReplaceRulesPage> createState() => _ReplaceRulesPageState();
}

class _ReplaceRulesPageState extends State<ReplaceRulesPage> {
  final ReplaceRuleManager _ruleManager = ReplaceRuleManager();
  List<ReplaceRule> _rules = [];
  final Set<int> _selectedIds = {};
  bool _isLoading = true;
  final ScrollController _verticalScrollController = ScrollController();

  String? get _currentSiteUrl => widget.currentSiteUrl;
  String? get _currentBookName => widget.currentBookName;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    try {
      await _ruleManager.init();
      final rules = await _ruleManager.getAllRules();
      setState(() {
        _rules = rules;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载规则失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要删除的规则')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 条规则吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _ruleManager.deleteRules(_selectedIds.toList());
      await _ruleManager.refreshRuleIds();
      _selectedIds.clear();
      await _loadRules();
    }
  }

  Future<void> _toggleRule(ReplaceRule rule) async {
    rule.enabled = !rule.enabled;
    await _ruleManager.updateRule(rule);
    await _loadRules();
  }

  Future<void> _exportToJsonFile() async {
    try {
      final rules = _selectedIds.isEmpty
          ? _rules
          : _rules.where((r) => _selectedIds.contains(r.id)).toList();

      if (rules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可导出的规则')),
        );
        return;
      }

      final jsonList = rules.map((r) {
        String scopeText = '';
        if (r.bookScope == 'specific_book' && r.bookName.isNotEmpty) {
          scopeText = r.bookName;
        }
        if (r.scope == 'specific_site' && r.scopeValue.isNotEmpty) {
          if (scopeText.isNotEmpty) {
            scopeText += '; ${r.scopeValue}';
          } else {
            scopeText = r.scopeValue;
          }
        }
        return {
          'id': r.id,
          'isEnabled': r.enabled,
          'isRegex': r.replaceType == 'regex',
          'name': r.findText.length > 20 ? r.findText.substring(0, 20) : (r.findText.isEmpty ? '未命名' : r.findText),
          'order': r.id,
          'pattern': r.findText,
          'replacement': r.replaceText,
          'scope': scopeText,
          'scopeContent': true,
          'scopeTitle': false,
          'timeoutMillisecond': 3000,
        };
      }).toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出规则',
        fileName: 'replace_rules.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(jsonString),
      );

      if (outputPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已导出到JSON文件')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  Future<void> _exportToClipboard() async {
    try {
      final rules = _selectedIds.isEmpty
          ? _rules
          : _rules.where((r) => _selectedIds.contains(r.id)).toList();

      if (rules.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可导出的规则')),
        );
        return;
      }

      final jsonList = rules.map((r) {
        String scopeText = '';
        if (r.bookScope == 'specific_book' && r.bookName.isNotEmpty) {
          scopeText = r.bookName;
        }
        if (r.scope == 'specific_site' && r.scopeValue.isNotEmpty) {
          if (scopeText.isNotEmpty) {
            scopeText += '; ${r.scopeValue}';
          } else {
            scopeText = r.scopeValue;
          }
        }
        return {
          'id': r.id,
          'isEnabled': r.enabled,
          'isRegex': r.replaceType == 'regex',
          'name': r.findText.length > 20 ? r.findText.substring(0, 20) : (r.findText.isEmpty ? '未命名' : r.findText),
          'order': r.id,
          'pattern': r.findText,
          'replacement': r.replaceText,
          'scope': scopeText,
          'scopeContent': true,
          'scopeTitle': false,
          'timeoutMillisecond': 3000,
        };
      }).toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      await Clipboard.setData(ClipboardData(text: jsonString));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出${rules.length}条规则到剪贴板')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  ReplaceRule _parseRuleFromJson(Map<String, dynamic> json) {
    bool enabled = true;
    String scope = 'all_sites';
    String scopeValue = '';
    String bookScope = 'all_books';
    String bookName = '';
    String replaceType = 'normal';
    String findText = '';
    String replaceText = '';

    if (json.containsKey('isEnabled')) {
      enabled = json['isEnabled'] ?? true;
    } else if (json.containsKey('enabled')) {
      enabled = json['enabled'] ?? true;
    }

    if (json.containsKey('isRegex')) {
      replaceType = json['isRegex'] == true ? 'regex' : 'normal';
    } else if (json.containsKey('replaceType')) {
      replaceType = json['replaceType'] ?? 'normal';
    }

    if (json.containsKey('pattern')) {
      findText = json['pattern'] ?? '';
    } else if (json.containsKey('findText')) {
      findText = json['findText'] ?? '';
    }

    if (json.containsKey('replacement')) {
      replaceText = json['replacement'] ?? '';
    } else if (json.containsKey('replaceText')) {
      replaceText = json['replaceText'] ?? '';
    }

    if (json.containsKey('scope') && !json.containsKey('scopeValue')) {
      String scopeText = json['scope'] ?? '';
      if (scopeText.contains(';')) {
        List<String> parts = scopeText.split(';');
        bookName = parts[0].trim();
        scopeValue = parts.sublist(1).join(';').trim();
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
      scopeValue = scopeValue.replaceAll('`', '').trim();
    } else {
      scope = json['scope'] ?? 'all_sites';
      scopeValue = json['scopeValue'] ?? '';
      bookScope = json['bookScope'] ?? 'all_books';
      bookName = json['bookName'] ?? '';
    }

    return ReplaceRule(
      enabled: enabled,
      scope: scope,
      scopeValue: scopeValue,
      bookScope: bookScope,
      bookName: bookName,
      replaceType: replaceType,
      findText: findText,
      replaceText: replaceText,
    );
  }

  Future<void> _importFromJsonFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入规则',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final List<dynamic> jsonList = const JsonDecoder().convert(content);
      int count = 0;

      for (final json in jsonList) {
        final rule = _parseRuleFromJson(json as Map<String, dynamic>);
        await _ruleManager.addRule(rule);
        count++;
      }

      await _ruleManager.refreshRuleIds();
      await _loadRules();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 $count 条规则')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  Future<void> _importFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';

      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板为空')),
        );
        return;
      }

      final List<dynamic> jsonList = const JsonDecoder().convert(text);
      int count = 0;

      for (final json in jsonList) {
        final rule = _parseRuleFromJson(json as Map<String, dynamic>);
        await _ruleManager.addRule(rule);
        count++;
      }

      await _ruleManager.refreshRuleIds();
      await _loadRules();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 $count 条规则')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  Future<void> _showRuleDialog({ReplaceRule? rule}) async {
    final isEdit = rule != null;
    final findTextController = TextEditingController(text: rule?.findText ?? '');
    final replaceTextController = TextEditingController(text: rule?.replaceText ?? '');
    final scopeValueController = TextEditingController(text: rule?.scopeValue ?? '');
    final bookNameController = TextEditingController(text: rule?.bookName ?? '');
    bool enabled = rule?.enabled ?? true;
    String scope = rule?.scope ?? 'all_sites';
    String bookScope = rule?.bookScope ?? 'all_books';
    String replaceType = rule?.replaceType ?? 'normal';

    final testTextController = TextEditingController();
    final testResultController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? '编辑规则' : '添加规则'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: const Text('启用'),
                    value: enabled,
                    onChanged: (v) => setDialogState(() => enabled = v ?? true),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  const Text('替换范围:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'all_sites',
                        groupValue: scope,
                        onChanged: (v) => setDialogState(() => scope = v!),
                      ),
                      const Text('全部站点'),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'specific_site',
                        groupValue: scope,
                        onChanged: (v) => setDialogState(() => scope = v!),
                      ),
                      const Text('特定站点'),
                    ],
                  ),
                  if (scope == 'specific_site')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: scopeValueController,
                              decoration: const InputDecoration(
                                hintText: '站点URL关键字',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              if (_currentSiteUrl != null) {
                                setDialogState(() {
                                  scopeValueController.text = _currentSiteUrl!;
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('无法获取当前网站信息')),
                                );
                              }
                            },
                            child: const Text('本站'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text('替换书籍:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'all_books',
                        groupValue: bookScope,
                        onChanged: (v) => setDialogState(() => bookScope = v!),
                      ),
                      const Text('全部书籍'),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'specific_book',
                        groupValue: bookScope,
                        onChanged: (v) => setDialogState(() => bookScope = v!),
                      ),
                      const Text('某本书名'),
                    ],
                  ),
                  if (bookScope == 'specific_book')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: bookNameController,
                              decoration: const InputDecoration(
                                hintText: '书籍名称',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              if (_currentBookName != null) {
                                setDialogState(() {
                                  bookNameController.text = _currentBookName!;
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('无法获取当前书籍信息')),
                                );
                              }
                            },
                            child: const Text('本书'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text('替换类型:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'normal',
                        groupValue: replaceType,
                        onChanged: (v) => setDialogState(() => replaceType = v!),
                      ),
                      const Text('普通替换'),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'regex',
                        groupValue: replaceType,
                        onChanged: (v) => setDialogState(() => replaceType = v!),
                      ),
                      const Text('正则替换'),
                    ],
                  ),
                  if (replaceType == 'regex') ...[
                    const SizedBox(height: 12),
                    const Text('快捷插入:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildQuickButton('.*?', '单行', findTextController),
                        _buildQuickButton(r'[\S\s]*?', '多行', findTextController),
                        _buildQuickButton('^', '行首', findTextController),
                        _buildQuickButton(r'$', '行尾', findTextController),
                        _buildQuickButton('?', '0或1', findTextController),
                        _buildQuickButton(r'\d', '数字', findTextController),
                        _buildQuickButton(r'\s', '空白', findTextController),
                        _buildQuickButton(r'\S', '非空白', findTextController),
                        _buildQuickButton(r'[A-Za-z0-9]', '字母数字', findTextController),
                        _buildQuickButton(r'\w', '字母数字_', findTextController),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text('被替换文本:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: findTextController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  const Text('替换为:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: replaceTextController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  if (replaceType == 'regex') ...[
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('正则调试:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('原文本:'),
                          TextField(
                            controller: testTextController,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.all(8),
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          const Text('替换结果:'),
                          TextField(
                            controller: testResultController,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.all(8),
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                            readOnly: true,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  final text = testTextController.text;
                                  final pattern = findTextController.text;
                                  final replacement = replaceTextController.text;
                                  try {
                                    final regex = RegExp(pattern, multiLine: true);
                                    final result = text.replaceAll(regex, replacement);
                                    testResultController.text = result;
                                  } catch (e) {
                                    testResultController.text = '正则错误: $e';
                                  }
                                },
                                child: const Text('测试替换'),
                              ),
                              TextButton(
                                onPressed: () {
                                  testTextController.clear();
                                  testResultController.clear();
                                },
                                child: const Text('清空结果'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final text = data?.text ?? '';
                if (text.isNotEmpty) {
                  try {
                    final json = const JsonDecoder().convert(text);
                    if (json is Map) {
                      final parsedRule = _parseRuleFromJson(Map<String, dynamic>.from(json));
                      findTextController.text = parsedRule.findText;
                      replaceTextController.text = parsedRule.replaceText;
                      setDialogState(() {
                        enabled = parsedRule.enabled;
                        scope = parsedRule.scope;
                        bookScope = parsedRule.bookScope;
                        replaceType = parsedRule.replaceType;
                      });
                      scopeValueController.text = parsedRule.scopeValue;
                      bookNameController.text = parsedRule.bookName;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已从剪贴板导入规则')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('剪贴板数据解析失败: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('剪贴板为空')),
                  );
                }
              },
              child: const Text('从剪贴板导入'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final findText = findTextController.text.trim();
                if (findText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('被替换文本不能为空')),
                  );
                  return;
                }

                final newRule = ReplaceRule(
                  id: rule?.id,
                  enabled: enabled,
                  scope: scope,
                  scopeValue: scopeValueController.text.trim(),
                  bookScope: bookScope,
                  bookName: bookNameController.text.trim(),
                  replaceType: replaceType,
                  findText: findText,
                  replaceText: replaceTextController.text,
                );

                if (isEdit) {
                  await _ruleManager.updateRule(newRule);
                } else {
                  await _ruleManager.addRule(newRule);
                }

                if (mounted) {
                  Navigator.pop(context);
                  await _loadRules();
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String insert, String label, TextEditingController controller) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: () {
        final text = controller.text;
        final selection = controller.selection;
        final start = selection.start >= 0 ? selection.start : text.length;
        final end = selection.end >= 0 ? selection.end : text.length;
        controller.text = text.replaceRange(start, end, insert);
        controller.selection = TextSelection.collapsed(offset: start + insert.length);
      },
    );
  }

  String _getScopeText(ReplaceRule rule) {
    if (rule.scope == 'all_sites') return '全部';
    return rule.scopeValue;
  }

  String _getBookScopeText(ReplaceRule rule) {
    if (rule.bookScope == 'all_books') return '全部';
    return rule.bookName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('正文处理'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _rules.isEmpty
                      ? const Center(
                          child: Text('暂无规则，点击下方按钮添加', style: TextStyle(color: Colors.grey)),
                        )
                      : Scrollbar(
                          controller: _verticalScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 12,
                                columns: const [
                                  DataColumn(label: SizedBox(width: 30, child: Text('ID'))),
                                  DataColumn(label: SizedBox(width: 40, child: Text('启用'))),
                                  DataColumn(label: SizedBox(width: 200, child: Text('网站范围'))),
                                  DataColumn(label: SizedBox(width: 120, child: Text('书籍范围'))),
                                  DataColumn(label: SizedBox(width: 60, child: Text('替换类型'))),
                                  DataColumn(label: SizedBox(width: 240, child: Text('被替换文本'))),
                                  DataColumn(label: Text('替换为')),
                                ],
                                rows: _rules.map((rule) {
                                  final isSelected = _selectedIds.contains(rule.id);
                                  return DataRow(
                                    selected: isSelected,
                                    onSelectChanged: (selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedIds.add(rule.id!);
                                        } else {
                                          _selectedIds.remove(rule.id!);
                                        }
                                      });
                                    },
                                    cells: [
                                      DataCell(SizedBox(width: 30, child: Text('${rule.id}'))),
                                      DataCell(
                                        SizedBox(
                                          width: 40,
                                          child: InkWell(
                                            onTap: () => _toggleRule(rule),
                                            child: Text(rule.enabled ? '是' : '否',
                                                style: TextStyle(
                                                  color: rule.enabled ? Colors.green : Colors.grey,
                                                )),
                                          ),
                                        ),
                                      ),
                                      DataCell(SizedBox(width: 200, child: Text(_getScopeText(rule), overflow: TextOverflow.ellipsis))),
                                      DataCell(SizedBox(width: 120, child: Text(_getBookScopeText(rule), overflow: TextOverflow.ellipsis))),
                                      DataCell(SizedBox(width: 60, child: Text(rule.replaceType == 'regex' ? '正则' : '普通'))),
                                      DataCell(SizedBox(width: 240, child: Text(rule.findText, overflow: TextOverflow.ellipsis))),
                                      DataCell(Text(rule.replaceText.isEmpty ? '(空)' : rule.replaceText, overflow: TextOverflow.ellipsis)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showRuleDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('新建'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _selectedIds.length == 1
                            ? () {
                                final rule = _rules.firstWhere((r) => _selectedIds.contains(r.id));
                                _showRuleDialog(rule: rule);
                              }
                            : null,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('编辑'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('删除'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: _selectedIds.isNotEmpty ? Colors.red : null,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('批量删除'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: _selectedIds.isNotEmpty ? Colors.red : null,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _exportToJsonFile,
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('导出到JSON'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _exportToClipboard,
                        icon: const Icon(Icons.content_copy, size: 18),
                        label: const Text('导出到剪贴板'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _importFromJsonFile,
                        icon: const Icon(Icons.file_open, size: 18),
                        label: const Text('从JSON导入'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
