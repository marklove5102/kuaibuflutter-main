import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import 'bookshelf_page.dart';
import 'explore.dart';
import 'source_edit.dart';
import 'reader_tab_page.dart';
import 'replace_rules_page.dart';

/// 阅读选项卡信息
class ReaderTab {
  final String id; // 唯一标识
  final String title; // 选项卡标题
  final Book book; // 书籍信息

  ReaderTab({
    required this.id,
    required this.title,
    required this.book,
  });
}

/// 主选项卡控制器 - 管理所有选项卡包括动态阅读选项卡
class MainTabController extends StatefulWidget {
  const MainTabController({super.key});

  @override
  State<MainTabController> createState() => _MainTabControllerState();
}

class _MainTabControllerState extends State<MainTabController>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<Widget> _tabs = [];
  final List<String> _tabTitles = [];
  final List<ReaderTab> _readerTabs = []; // 动态阅读选项卡列表
  int _currentIndex = 0; // 当前选中的索引
  int _totalChapters = 0;
  int _downloadedChapters = 0;

  // 固定选项卡数量
  static const int _fixedTabCount = 3;

  @override
  void initState() {
    super.initState();
    _initTabs();
  }

  void _initTabs() {
    // 初始化固定选项卡
    _tabs.add(BookshelfPage(key: BookshelfPage.bookshelfKey));
    _tabTitles.add('我的书架');

    _tabs.add(const ExplorePage());
    _tabTitles.add('网上搜书');

    _tabs.add(const SourceEditPage());
    _tabTitles.add('书源编辑');

    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index != _currentIndex) {
      setState(() {
        _currentIndex = _tabController.index;
      });
    }
  }

  /// 打开书籍阅读选项卡
  void openBook(Book book) {
    // 检查是否已存在该书籍的选项卡
    final existingIndex = _readerTabs.indexWhere((tab) =>
        tab.book.title == book.title &&
        tab.book.sourceUrl == book.sourceUrl);

    if (existingIndex != -1) {
      // 已存在，切换到该选项卡
      final tabIndex = _fixedTabCount + existingIndex;
      _tabController.animateTo(tabIndex);
      return;
    }

    // 创建新的阅读选项卡
    final readerTab = ReaderTab(
      id: '${book.title}_${DateTime.now().millisecondsSinceEpoch}',
      title: book.title,
      book: book,
    );

    // 计算新选项卡的索引
    final newIndex = _tabs.length;

    setState(() {
      _readerTabs.add(readerTab);
      _tabs.add(ReaderTabPage(
        book: book,
        onClose: () => _closeReaderTab(readerTab),
      ));
      _tabTitles.add(book.title);
      _currentIndex = newIndex;
    });

    // 更新 TabController 长度并跳转
    _tabController.dispose();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: newIndex,
    );
    _tabController.addListener(_onTabChanged);
  }

  /// 关闭阅读选项卡
  void _closeReaderTab(ReaderTab readerTab) {
    final index = _readerTabs.indexOf(readerTab);
    if (index == -1) return;

    final tabIndex = _fixedTabCount + index;

    setState(() {
      _readerTabs.removeAt(index);
      _tabs.removeAt(tabIndex);
      _tabTitles.removeAt(tabIndex);

      // 关闭后跳转到书架（index 0）
      _currentIndex = 0;
    });

    // 更新 TabController
    _tabController.dispose();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: _currentIndex,
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainTabControllerProvider(
      state: this,
      child: Scaffold(
        body: SafeArea(
          top: true,
          child: Column(
            children: [
              // 选项卡区域
              _buildTabBar(),
              // 页面内容 - 使用 IndexedStack 保持状态
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _tabs,
                ),
              ),
              // 状态栏
              _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建选项卡栏
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: _tabTitles.asMap().entries.map((entry) {
                final index = entry.key;
                final title = entry.value;
                final isReaderTab = index >= _fixedTabCount;

                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onLongPress: () {
                          if (isReaderTab) {
                            final readerTabIndex = index - _fixedTabCount;
                            if (readerTabIndex >= 0 && readerTabIndex < _readerTabs.length) {
                              final readerTab = _readerTabs[readerTabIndex];
                              final bookName = readerTab.title;
                              final sourceUrl = readerTab.book.sourceUrl ?? '';
                              showMenu(
                                context: context,
                                position: const RelativeRect.fromLTRB(100, 100, 100, 100),
                                items: [
                                  PopupMenuItem(
                                    child: const Text('复制书名'),
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: bookName));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('已复制书名'), duration: Duration(seconds: 1)),
                                      );
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Text('复制目录网址'),
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: sourceUrl));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('已复制目录网址'), duration: Duration(seconds: 1)),
                                      );
                                    },
                                  ),
                                ],
                              );
                            }
                          }
                        },
                        child: Text(title),
                      ),
                      if (isReaderTab) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            final readerTabIndex = index - _fixedTabCount;
                            if (readerTabIndex >= 0 &&
                                readerTabIndex < _readerTabs.length) {
                              _closeReaderTab(_readerTabs[readerTabIndex]);
                            }
                          },
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          TextButton(
            onPressed: () {
              String? currentSiteUrl;
              String? currentBookName;

              if (_currentIndex >= _fixedTabCount) {
                final readerIndex = _currentIndex - _fixedTabCount;
                if (readerIndex < _readerTabs.length) {
                  final readerTab = _readerTabs[readerIndex];
                  currentBookName = readerTab.title;
                  final sourceUrl = readerTab.book.sourceUrl;
                  if (sourceUrl != null && sourceUrl.isNotEmpty) {
                    try {
                      final uri = Uri.parse(sourceUrl);
                      currentSiteUrl = uri.host;
                    } catch (e) {
                      currentSiteUrl = sourceUrl;
                    }
                  }
                }
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReplaceRulesPage(
                    currentSiteUrl: currentSiteUrl,
                    currentBookName: currentBookName,
                  ),
                ),
              );
            },
            child: const Text('正文处理', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// 构建状态栏
  Widget _buildStatusBar() {
    final isReaderTab = _currentIndex >= _fixedTabCount;
    String bookInfo;

    if (isReaderTab && _readerTabs.isNotEmpty) {
      final readerIndex = _currentIndex - _fixedTabCount;
      if (readerIndex >= 0 && readerIndex < _readerTabs.length) {
        final bookName = _readerTabs[readerIndex].title;
        bookInfo = '《$bookName》总章数: $_totalChapters | 已下载: $_downloadedChapters';
      } else {
        bookInfo = '总章数: 0 | 已下载: 0';
      }
    } else {
      bookInfo = '总章数: 0 | 已下载: 0';
    }

    return Container(
      height: 24,
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Text(
            '就绪',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const Spacer(),
          Text(
            bookInfo,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  /// 更新阅读选项卡的状态栏信息
  void updateReaderTabStatus(int totalChapters, int downloadedChapters) {
    if (_currentIndex >= _fixedTabCount) {
      setState(() {
        _totalChapters = totalChapters;
        _downloadedChapters = downloadedChapters;
      });
    }
  }
}

/// 全局访问主选项卡控制器的方法
class MainTabControllerProvider extends InheritedWidget {
  final _MainTabControllerState? state;

  const MainTabControllerProvider({
    super.key,
    this.state,
    required super.child,
  });

  static _MainTabControllerState? of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<MainTabControllerProvider>();
    return provider?.state;
  }

  @override
  bool updateShouldNotify(MainTabControllerProvider oldWidget) => true;
}
