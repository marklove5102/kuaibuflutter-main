import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../services/bookshelf_manager.dart';
import '../services/chapter_downloader.dart';
import '../services/reading_progress_manager.dart';
import '../services/source_manager.dart';
import '../services/reader_config_manager.dart';
import '../services/read_aloud.dart';
import '../services/read_aloud_service.dart';
import '../services/tts_engine_manager.dart';
import 'main_tab_controller.dart';
import 'tts_engine_page.dart';

/// 阅读选项卡页面 - 嵌入选项卡中的阅读器
class ReaderTabPage extends StatefulWidget {
  final Book book;
  final VoidCallback? onClose;

  const ReaderTabPage({
    super.key,
    required this.book,
    this.onClose,
  });

  @override
  State<ReaderTabPage> createState() => _ReaderTabPageState();
}

class _ReaderTabPageState extends State<ReaderTabPage> {
  final BookshelfManager _bookshelfManager = BookshelfManager();
  final ChapterDownloader _chapterDownloader = ChapterDownloader();
  final ReadingProgressManager _progressManager = ReadingProgressManager();
  final ReaderConfigManager _configManager = ReaderConfigManager();
  final ReadAloud _readAloud = ReadAloud();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  String _content = '';
  String _chapterTitle = '';
  int _currentChapterIndex = 0;
  List<Map<String, String>> _chapters = [];
  Set<int> _downloadedChapters = {}; // 已下载章节索引集合
  bool _showChapterPanel = false; // 章节列表面板显示状态
  double _fontSize = 16;
  bool _isDarkMode = false;
  double _scrollPosition = 0.0; // 滚动位置
  bool _hasUserScrolled = false; // 用户是否已滚动（用于判断是否保存进度）
  bool _autoScrollEnabled = false; // 自动滚屏开关
  int _scrollSpeed = 1600; // 滚动速度
  bool _autoPageEnabled = false; // 自动翻页开关
  int _autoPageSpeed = 10000; // 自动翻页速度（毫秒）
  bool _autoPageAtEnd = false; // 自动翻页是否已到达章节末尾
  double _lineHeight = 1.8; // 行间距
  Color _bgColor = const Color(0xFFFFFCE6); // 背景颜色
  Color _textColor = const Color(0xFF000000); // 文字颜色
  String? _bgImagePath; // 背景图片路径
  bool _isReadAloudPlaying = false; // 是否正在朗读
  bool _isReadAloudPaused = false; // 是否暂停朗读
  int _currentReadAloudIndex = -1; // 当前朗读的句子索引
  List<String> _readAloudSentences = []; // 朗读分割后的句子列表

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = 0;
    _chapterTitle = '第一章';
    _scrollController.addListener(_onScrollPositionChanged);
    _initProgressManager();
    _loadConfig();
  }

  Future<void> _initProgressManager() async {
    await _progressManager.init();
  }

  Future<void> _loadConfig() async {
    await _configManager.init();
    setState(() {
      _fontSize = _configManager.fontSize;
      _lineHeight = _configManager.lineHeight;
      _scrollSpeed = _configManager.scrollSpeed;
      _autoPageSpeed = _configManager.autoPageSpeed;
      _bgColor = Color(_configManager.bgColor);
      _textColor = Color(_configManager.textColor);
      _bgImagePath = _configManager.bgImagePath;
    });
    _loadChaptersAndChapterWithProgress();
  }

  void _onScrollPositionChanged() {
    if (_scrollController.hasClients) {
      _scrollPosition = _scrollController.position.pixels;
      _hasUserScrolled = true;
    }
  }

  /// 加载章节列表和当前章节（带进度恢复）
  Future<void> _loadChaptersAndChapterWithProgress() async {
    await _loadChapters();

    // 尝试恢复阅读进度
    await _restoreReadingProgress();

    await _loadChapter(restoreProgress: true);
  }

  /// 恢复阅读进度
  Future<void> _restoreReadingProgress() async {
    if (widget.book.sourceUrl == null || widget.book.sourceUrl!.isEmpty) {
      return;
    }

    try {
      await _progressManager.reload();

      final progress = await _progressManager.getProgress(
        widget.book.title,
        widget.book.sourceUrl!,
      );

      if (progress != null) {
        int targetIndex = progress.chapterIndex;

        // 如果章节索引为0或无效，尝试通过章节标题查找
        if (targetIndex <= 0 && _chapters.isNotEmpty && progress.chapterTitle.isNotEmpty) {
          for (int i = 0; i < _chapters.length; i++) {
            if (_chapters[i]['title'] == progress.chapterTitle) {
              targetIndex = i;
              break;
            }
          }
        }

        // 恢复章节索引
        if (targetIndex >= 0 && targetIndex < _chapters.length) {
          _currentChapterIndex = targetIndex;
          _chapterTitle = progress.chapterTitle;
          _scrollPosition = progress.scrollPosition;
        }
      }
    } catch (e, stack) {
    }
  }

  /// 加载章节列表
  Future<void> _loadChapters() async {
    try {
      final sourceUrl = widget.book.sourceUrl;
      if (sourceUrl == null || sourceUrl.isEmpty) {
        return;
      }

      final chapters = await _bookshelfManager.getChapters(sourceUrl);
      if (chapters.isNotEmpty) {
        setState(() {
          _chapters = chapters.map((c) => {
            'url': c['url']?.toString() ?? '',
            'title': c['title']?.toString() ?? '',
          }).toList();
        });
        // 检查下载状态
        await _checkDownloadedChapters();_updateStatusBar();
      }
    } catch (e) {
    }
  }

  /// 检查已下载的章节
  Future<void> _checkDownloadedChapters() async {
    final downloaded = <int>{};
    for (int i = 0; i < _chapters.length; i++) {
      final isDownloaded = await _chapterDownloader.isChapterDownloaded(
        widget.book.title,
        i,
      );
      if (isDownloaded) {
        downloaded.add(i);
      }
    }
    setState(() {
      _downloadedChapters = downloaded;
    });
    _updateStatusBar();
  }

  void _updateStatusBar() {
    final controller = MainTabControllerProvider.of(context);
    controller?.updateReaderTabStatus(_chapters.length, _downloadedChapters.length);
  }

  Future<void> _loadChapter({bool restoreProgress = false}) async {
    _autoPageAtEnd = false;
    setState(() => _isLoading = true);

    // 先尝试从本地读取
    final localContent = await _bookshelfManager.readChapterContent(
      widget.book.title,
      _currentChapterIndex,
    );

    if (localContent != null) {
      setState(() {
        _content = localContent;
        _isLoading = false;
      });
      if (restoreProgress) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _restoreScrollPosition();
        });
      } else if (_autoPageEnabled && _scrollController.hasClients) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollController.jumpTo(0);
        });
      }
      _prefetchNextChapters();
      return;
    }

    // 本地没有，从网络下载
    await _downloadAndLoadChapter(restoreProgress: restoreProgress);
  }

  Future<void> _downloadAndLoadChapter({bool restoreProgress = false}) async {
    setState(() => _content = '正在下载章节内容...');

    try {
      // 获取书源（书源仅用于搜索/发现，不影响阅读）
      final sourceManager = SourceManager();
      final sourceName = widget.book.sourceName;
      BookSource? source;
      
      if (sourceName != null && sourceName.isNotEmpty) {
        source = sourceManager.getSourceByName(sourceName);
      }
      
      // 如果没有书源，创建通用书源用于阅读
      source ??= BookSource(
        sourceName: '通用解析',
        websiteEncoding: 'UTF-8',
      );

      // 获取章节URL
      final sourceUrl = widget.book.sourceUrl;
      if (sourceUrl == null || sourceUrl.isEmpty) {
        setState(() {
          _content = '无法获取书籍URL';
          _isLoading = false;
        });
        return;
      }

      final chapters = await _bookshelfManager.getChapters(sourceUrl);
      if (chapters.isEmpty || _currentChapterIndex >= chapters.length) {
        setState(() {
          _content = '无法获取章节列表';
          _isLoading = false;
        });
        return;
      }

      // 转换章节列表为 Map<String, String>
      final stringChapters = chapters.map((c) => {
        'url': c['url']?.toString() ?? '',
        'title': c['title']?.toString() ?? '',
      }).toList();

      final chapter = stringChapters[_currentChapterIndex];
      final chapterUrl = chapter['url'] ?? '';
      _chapterTitle = chapter['title'] ?? '第${_currentChapterIndex + 1}章';

      if (chapterUrl.isEmpty) {
        setState(() {
          _content = '章节URL为空';
          _isLoading = false;
        });
        return;
      }

      // 下载章节
      final downloader = ChapterDownloader();
      final success = await downloader.downloadChapter(
        chapterUrl: chapterUrl,
        chapterTitle: _chapterTitle,
        bookTitle: widget.book.title,
        chapterIndex: _currentChapterIndex,
        source: source,
        downloadAllPages: true,
      );

      if (success) {
        // 重新读取本地文件
        final content = await _bookshelfManager.readChapterContent(
          widget.book.title,
          _currentChapterIndex,
        );

        setState(() {
          _content = content ?? '章节内容为空';
          _isLoading = false;
          _downloadedChapters.add(_currentChapterIndex); // 标记为已下载
        });

        _updateProgress();
        if (restoreProgress) {
          _restoreScrollPosition();
        } else if (_autoPageEnabled && _scrollController.hasClients) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            _scrollController.jumpTo(0);
          });
        }

        // 预下载后续章节（提升阅读体验）
        _prefetchNextChapters();
      } else {
        setState(() {
          _content = '章节下载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _content = '加载章节失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 预下载后续章节
  Future<void> _prefetchNextChapters() async {
    if (_chapters.isEmpty) return;

    try {
      final sourceManager = SourceManager();
      final sourceName = widget.book.sourceName;
      BookSource? source;
      
      if (sourceName != null && sourceName.isNotEmpty) {
        source = sourceManager.getSourceByName(sourceName);
      }
      
      // 如果没有书源，创建通用书源用于阅读
      source ??= BookSource(
        sourceName: '通用解析',
        websiteEncoding: 'UTF-8',
      );

      final downloader = ChapterDownloader();

      // 预下载后续3章（异步进行），每个章节下载完成后立即刷新状态
      downloader.prefetchChapters(
        chapters: _chapters,
        bookTitle: widget.book.title,
        source: source,
        startIndex: _currentChapterIndex + 1,
        count: 3,
        onChapterDownloaded: (chapterIndex) {
          if (mounted) {
            setState(() {
              _downloadedChapters.add(chapterIndex);
            });
            _updateStatusBar();
          }
        },
      );
    } catch (e) {
    }
  }

  /// 更新阅读进度
  Future<void> _updateProgress() async {
    if (!_hasUserScrolled) {
      return;
    }
    if (widget.book.sourceUrl == null || widget.book.sourceUrl!.isEmpty) {
      return;
    }

    try {
      String chapterUrl = '';
      if (_currentChapterIndex >= 0 && _currentChapterIndex < _chapters.length) {
        chapterUrl = _chapters[_currentChapterIndex]['url'] ?? '';
      }

      final progress = ReadingProgress(
        bookName: widget.book.title,
        bookUrl: widget.book.sourceUrl!,
        chapterTitle: _chapterTitle,
        chapterUrl: chapterUrl,
        chapterIndex: _currentChapterIndex,
        scrollPosition: _scrollPosition,
      );

      await _progressManager.saveProgress(progress);
    } catch (e, stack) {
    }
  }

  /// 恢复滚动位置
  void _restoreScrollPosition() {
    if (_scrollPosition > 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients && mounted) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final targetPosition = _scrollPosition.clamp(0.0, maxScroll);
          _scrollController.jumpTo(targetPosition);
        }
      });
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      setState(() {
        _currentChapterIndex--;
        _chapterTitle = _chapters.isNotEmpty
            ? (_chapters[_currentChapterIndex]['title'] ?? '第${_currentChapterIndex + 1}章')
            : '第${_currentChapterIndex + 1}章';
      });
      _loadChapter();
    }
  }

  void _nextChapter() {
    if (_chapters.isNotEmpty && _currentChapterIndex < _chapters.length - 1) {
      _autoPageAtEnd = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      setState(() {
        _currentChapterIndex++;
        _chapterTitle = _chapters[_currentChapterIndex]['title'] ?? '第${_currentChapterIndex + 1}章';
      });
      _loadChapter();
    }
  }

  /// 切换章节列表面板
  void _toggleChapterPanel() {
    setState(() => _showChapterPanel = !_showChapterPanel);
  }

  /// 选择章节
  void _selectChapter(int index) {
    if (index >= 0 && index < _chapters.length) {
      setState(() {
        _currentChapterIndex = index;
        _chapterTitle = _chapters[index]['title'] ?? '第${index + 1}章';
        _showChapterPanel = false;
      });
      _loadChapter();
    }
  }

  void _toggleAutoScroll() {
    if (_autoScrollEnabled) {
      _stopAutoScroll();
      setState(() => _autoScrollEnabled = false);
    } else {
      setState(() => _autoScrollEnabled = true);
      _startAutoScroll();
    }
  }

  void _toggleAutoPage() {
    if (_autoPageEnabled) {
      _stopAutoPage();
      setState(() => _autoPageEnabled = false);
    } else {
      setState(() => _autoPageEnabled = true);
      _startAutoPage();
    }
  }

  Future<Color?> _showColorPicker(Color currentColor) async {
    return showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Colors.white,
                  Colors.black,
                  Colors.red,
                  Colors.pink,
                  Colors.purple,
                  Colors.deepPurple,
                  Colors.indigo,
                  Colors.blue,
                  Colors.lightBlue,
                  Colors.cyan,
                  Colors.teal,
                  Colors.green,
                  Colors.lightGreen,
                  Colors.lime,
                  Colors.yellow,
                  Colors.amber,
                  Colors.orange,
                  Colors.deepOrange,
                  Colors.brown,
                  Colors.grey,
                  Colors.blueGrey,
                  const Color(0xFFFFE),
                  const Color(0xFFF0F0F0),
                ].map((color) {
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(
                          color: currentColor == color ? Colors.blue : Colors.grey,
                          width: currentColor == color ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('阅读设置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('字体设置', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('字体大小:'),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 12,
                          max: 32,
                          divisions: 20,
                          label: _fontSize.round().toString(),
                          onChanged: (value) {
                            setDialogState(() => _fontSize = value);
                            setState(() {});
                          },
                        ),
                      ),
                      Text(_fontSize.round().toString()),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('行间距:'),
                      Expanded(
                        child: Slider(
                          value: _lineHeight,
                          min: 1.0,
                          max: 3.0,
                          divisions: 20,
                          label: _lineHeight.toStringAsFixed(1),
                          onChanged: (value) {
                            setDialogState(() => _lineHeight = value);
                            setState(() {});
                          },
                        ),
                      ),
                      Text(_lineHeight.toStringAsFixed(1)),
                    ],
                  ),
                  const Divider(),
                  const Text('颜色设置', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('背景颜色:'),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final color = await _showColorPicker(_bgColor);
                          if (color != null) {
                            setDialogState(() => _bgColor = color);
                            setState(() {});
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _bgColor,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('文字颜色:'),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final color = await _showColorPicker(_textColor);
                          if (color != null) {
                            setDialogState(() => _textColor = color);
                            setState(() {});
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _textColor,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text('背景图片', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _bgImagePath ?? '未选择图片',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                          );
                          if (result != null && result.files.single.path != null) {
                            setDialogState(() => _bgImagePath = result.files.single.path);
                            setState(() {});
                          }
                        },
                        child: const Text('选择图片'),
                      ),
                      if (_bgImagePath != null)
                        TextButton(
                          onPressed: () {
                            setDialogState(() => _bgImagePath = null);
                            setState(() {});
                          },
                          child: const Text('清除'),
                        ),
                    ],
                  ),
                  const Divider(),
                  const Text('自动滚屏速度', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('速度:'),
                      Expanded(
                        child: Slider(
                          value: _scrollSpeed.toDouble(),
                          min: 100,
                          max: 3000,
                          divisions: 29,
                          label: _scrollSpeed.toString(),
                          onChanged: (value) {
                            setDialogState(() => _scrollSpeed = value.round());
                            setState(() {});
                          },
                        ),
                      ),
                      Text(_scrollSpeed.toString()),
                    ],
                  ),
                  const Divider(),
                  const Text('自动翻页间隔', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('间隔(秒):'),
                      Expanded(
                        child: Slider(
                          value: _autoPageSpeed.toDouble(),
                          min: 1000,
                          max: 60000,
                          divisions: 59,
                          label: (_autoPageSpeed / 1000).toStringAsFixed(1),
                          onChanged: (value) {
                            setDialogState(() => _autoPageSpeed = value.round());
                            setState(() {});
                          },
                        ),
                      ),
                      Text('${(_autoPageSpeed / 1000).toStringAsFixed(1)}秒'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _configManager.setFontSize(_fontSize);
                  _configManager.setLineHeight(_lineHeight);
                  _configManager.setScrollSpeed(_scrollSpeed);
                  _configManager.setAutoPageSpeed(_autoPageSpeed);
                  _configManager.setBgColor(_bgColor.toARGB32());
                  _configManager.setTextColor(_textColor.toARGB32());
                  _configManager.setBgImagePath(_bgImagePath);
                  Navigator.pop(dialogContext);
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  Timer? _autoScrollTimer;
  Timer? _autoPageTimer;

  void _startAutoScroll() {
    _stopAutoScroll();
    if (!_scrollController.hasClients) return;

    final step = _scrollSpeed ~/ 100;
    final intervalMs = 1000 ~/ max(1, _scrollSpeed ~/ 100);

    _autoScrollTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted || !_scrollController.hasClients) {
        _stopAutoScroll();
        return;
      }

      final position = _scrollController.position;
      final currentPixels = _scrollController.position.pixels;
      final maxPixels = position.maxScrollExtent;

      if (currentPixels + step < maxPixels) {
        _scrollController.jumpTo(currentPixels + step);
      } else {
        _stopAutoScroll();
        if (_autoPageEnabled) {
          _autoTurnPage();
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _startAutoPage() {
    _stopAutoPage();
    if (!_scrollController.hasClients) return;
    _autoPageAtEnd = false;

    final pageStep = (_scrollController.position.viewportDimension * 0.98).round();

    _autoPageTimer = Timer.periodic(Duration(milliseconds: _autoPageSpeed), (timer) {
      if (!mounted || !_scrollController.hasClients) {
        _stopAutoPage();
        return;
      }

      if (_autoPageAtEnd) return;

      final position = _scrollController.position;
      final currentPixels = position.pixels;
      final maxPixels = position.maxScrollExtent;

      if (currentPixels + pageStep < maxPixels) {
        _scrollController.jumpTo(currentPixels + pageStep);
      } else if (currentPixels < maxPixels) {
        _scrollController.jumpTo(maxPixels);
        _autoPageAtEnd = true;
        _autoTurnPage();
      } else {
        _autoPageAtEnd = true;
        _autoTurnPage();
      }
    });
  }

  void _stopAutoPage() {
    _autoPageTimer?.cancel();
    _autoPageTimer = null;
  }

  void _autoTurnPage() {
    if (_chapters.isEmpty || _currentChapterIndex >= _chapters.length - 1) {
      _stopAutoPage();
      _stopAutoScroll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已到最后一章')),
      );
      return;
    }
    _nextChapter();
  }

  Future<void> _saveBookmark() async {
    try {
      final bookmarkName = '$_chapterTitle - ${DateTime.now().toString().substring(11, 19)}';
      final bookmark = Bookmark(
        bookTitle: widget.book.title,
        chapterTitle: _chapterTitle,
        chapterIndex: _currentChapterIndex,
        scrollPosition: _scrollPosition,
        bookmarkName: bookmarkName,
      );

      await _progressManager.saveBookmark(bookmark);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('书签已保存: $bookmarkName'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: '查看',
              onPressed: _showBookmarkManager,
            ),
          ),
        );
      }
    } catch (e, stack) {
    }
  }

  Future<void> _showBookmarkManager() async {

    try {
      final bookmarks = await _progressManager.getBookmarks(widget.book.title);

      if (!mounted) return;

      if (bookmarks.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('书签管理'),
            content: const Text('暂无书签'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (dialogContext) => _BookmarkManagerDialog(
          bookmarks: bookmarks,
          onJump: (bookmark) {
            Navigator.pop(dialogContext);
            _jumpToBookmark(bookmark);
          },
          onDelete: (bookmark) async {
            await _progressManager.deleteBookmark(widget.book.title, bookmark.createTime);
            Navigator.pop(dialogContext);
            _showBookmarkManager();
          },
        ),
      );
    } catch (e, stack) {
    }
  }

  void _jumpToBookmark(Bookmark bookmark) {
    if (bookmark.chapterIndex != _currentChapterIndex) {
      _goToChapter(bookmark.chapterIndex);
      Future.delayed(const Duration(milliseconds: 500), () {
        _scrollController.jumpTo(bookmark.scrollPosition);
      });
    } else {
      _scrollController.jumpTo(bookmark.scrollPosition);
    }
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= _chapters.length) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      _currentChapterIndex = index;
      _chapterTitle = _chapters[index]['title'] ?? '第${index + 1}章';
    });
    _loadChapter();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? Colors.black : _bgColor;
    final textColor = _isDarkMode ? Colors.white : _textColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // 章节列表面板（可折叠）
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _showChapterPanel ? 200 : 0,
            child: _showChapterPanel
                ? Container(
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.grey[900] : Colors.grey[100],
                      border: Border(
                        right: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Column(
                      children: [
                        // 面板标题
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '章节目录',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_downloadedChapters.length}/${_chapters.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              if (_currentChapterIndex >= 0 && _currentChapterIndex < _chapters.length)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '当前: ${_chapters[_currentChapterIndex]['title'] ?? '第${_currentChapterIndex + 1}章'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // 章节列表
                        Expanded(
                          child: _chapters.isEmpty
                              ? Center(
                                  child: Text(
                                    '加载中...',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _chapters.length,
                                  itemBuilder: (context, index) {
                                    final chapter = _chapters[index];
                                    final isSelected = index == _currentChapterIndex;
                                    final isDownloaded = _downloadedChapters.contains(index);

                                    return ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      selectedTileColor: Colors.blue.withOpacity(0.1),
                                      leading: isDownloaded
                                          ? const Icon(Icons.check_circle, size: 16, color: Colors.green)
                                          : const Icon(Icons.circle_outlined, size: 16, color: Colors.grey),
                                      title: Text(
                                        chapter['title'] ?? '第${index + 1}章',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected ? Colors.blue : textColor,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _selectChapter(index),
                                      onLongPress: () {
                                        final url = chapter['url'] ?? '';
                                        if (url.isNotEmpty) {
                                          Clipboard.setData(ClipboardData(text: url));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('已复制章节链接'), duration: Duration(seconds: 1)),
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          // 阅读区域
          Expanded(
            child: Column(
              children: [
                // 工具栏
                Container(
                  height: 40,
                  color: _isDarkMode ? Colors.grey[900] : Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        // 目录按钮
                        IconButton(
                          icon: Icon(
                            _showChapterPanel ? Icons.menu_open : Icons.menu,
                            size: 20,
                          ),
                          onPressed: _toggleChapterPanel,
                          tooltip: '目录',
                        ),
                        const SizedBox(width: 4),
                        // 章节标题
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            _chapterTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // 上一章/下一章
                        IconButton(
                          icon: const Icon(Icons.skip_previous, size: 20),
                          onPressed: _currentChapterIndex > 0 ? _previousChapter : null,
                          tooltip: '上一章',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        Text(
                          '${_currentChapterIndex + 1}/${_chapters.length}',
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, size: 20),
                          onPressed: (_chapters.isNotEmpty && _currentChapterIndex < _chapters.length - 1)
                              ? _nextChapter
                              : null,
                          tooltip: '下一章',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        // 自动滚屏
                        IconButton(
                          icon: Icon(
                            _autoScrollEnabled ? Icons.vertical_align_bottom : Icons.vertical_align_top,
                            size: 20,
                            color: _autoScrollEnabled ? Colors.blue : textColor,
                          ),
                          onPressed: _toggleAutoScroll,
                          tooltip: '自动滚屏',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        // 自动翻页
                        IconButton(
                          icon: Icon(
                            _autoPageEnabled ? Icons.book : Icons.book_outlined,
                            size: 20,
                            color: _autoPageEnabled ? Colors.blue : textColor,
                          ),
                          onPressed: _toggleAutoPage,
                          tooltip: '自动翻页',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        // 设置
                        IconButton(
                          icon: const Icon(Icons.settings, size: 20),
                          onPressed: _showSettings,
                          tooltip: '设置',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        // 书签下拉菜单
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.bookmark, size: 20),
                          tooltip: '书签',
                          onSelected: (value) {
                            if (value == 'add') {
                              _saveBookmark();
                            } else if (value == 'manage') {
                              _showBookmarkManager();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'add', child: Text('添加书签')),
                            const PopupMenuItem(value: 'manage', child: Text('书签管理')),
                          ],
                        ),
                        // 朗读按钮组 - 4个独立按钮
                        if (!_isReadAloudPlaying && !_isReadAloudPaused) ...[
                            IconButton(
                            icon: const Icon(Icons.volume_up, size: 20),
                            tooltip: '开始朗读',
                            onPressed: () {
                              _startReadAloud();
                            },
                          ),
                        ],
                        if (_isReadAloudPlaying) ...[
                          IconButton(
                            icon: const Icon(Icons.pause, size: 20, color: Colors.green),
                            tooltip: '暂停朗读',
                            onPressed: _pauseReadAloud,
                          ),
                        ],
                        if (_isReadAloudPaused) ...[
                          IconButton(
                            icon: const Icon(Icons.play_arrow, size: 20, color: Colors.orange),
                            tooltip: '继续朗读',
                            onPressed: _resumeReadAloud,
                          ),
                        ],
                        if (_isReadAloudPlaying || _isReadAloudPaused) ...[
                          IconButton(
                            icon: const Icon(Icons.stop, size: 20, color: Colors.red),
                            tooltip: '停止朗读',
                            onPressed: _stopReadAloud,
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.settings, size: 20),
                          tooltip: '朗读配置',
                          onPressed: _showReadAloudConfig,
                        ),
                      ],
                    ),
                  ),
                ),

                // 内容区域
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          children: [
                            if (_bgImagePath != null && !_isDarkMode)
                              Positioned.fill(
                                child: Image.file(
                                  File(_bgImagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                ),
                              ),
                            Positioned.fill(
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                child: _isReadAloudPlaying || _isReadAloudPaused
                                  ? _buildHighlightedText(textColor)
                                  : SelectableText(
                                      _content,
                                      style: TextStyle(
                                        fontSize: _fontSize,
                                        height: _lineHeight,
                                        color: textColor,
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _stopAutoPage();
    _stopReadAloudForDispose();
    _saveReadingProgressSync();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopReadAloudForDispose() {
    _readAloud.stop();
    _isReadAloudPlaying = false;
    _isReadAloudPaused = false;
    _currentReadAloudIndex = -1;
  }

  void _saveReadingProgressSync() {
    if (widget.book.sourceUrl == null || widget.book.sourceUrl!.isEmpty) {
      return;
    }

    try {
      String chapterUrl = '';
      if (_currentChapterIndex >= 0 && _currentChapterIndex < _chapters.length) {
        chapterUrl = _chapters[_currentChapterIndex]['url'] ?? '';
      }

      final progress = ReadingProgress(
        bookName: widget.book.title,
        bookUrl: widget.book.sourceUrl!,
        chapterTitle: _chapterTitle,
        chapterUrl: chapterUrl,
        chapterIndex: _currentChapterIndex,
        scrollPosition: _scrollPosition,
      );

      _progressManager.saveProgressSync(progress);
    } catch (e, stack) {
    }
  }

  Future<void> _startReadAloud() async {
    if (_content.isEmpty) {
      return;
    }

    final sentences = _splitContentForReadAloud(_content);

    setState(() {
      _readAloudSentences = sentences;
      _currentReadAloudIndex = 0;
    });

    _readAloud.tts.onComplete = () {
      if (mounted) {
        // 判断是否是正常朗读完成（读到最后一句）
        final isNormalComplete = _currentReadAloudIndex >= _readAloudSentences.length - 1;
        
        setState(() {
          _isReadAloudPlaying = false;
          _isReadAloudPaused = false;
          _currentReadAloudIndex = -1;
        });
        
        // 只有正常朗读完成后才自动翻页到下一章
        if (isNormalComplete && _currentChapterIndex < _chapters.length - 1) {
          _nextChapter();
        }
      }
    };

    _readAloud.tts.onStateChanged = (state) {
      if (mounted) {
        setState(() {
          _isReadAloudPlaying = state == 'playing';
          _isReadAloudPaused = state == 'paused';
        });
      }
    };

    _readAloud.tts.onSentenceStart = (index, text) {
      if (mounted) {
        setState(() {
          _currentReadAloudIndex = index;
        });
        _scrollToCurrentSentence(index);
      }
    };

    try {
      await _readAloud.playList(
        sentences,
        bookTitle: widget.book.title,
        pageIndex: _currentChapterIndex,
      );
    } catch (e, stackTrace) {
    }

    setState(() {
      _isReadAloudPlaying = true;
      _isReadAloudPaused = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('开始朗读'), duration: Duration(seconds: 1)),
    );
  }

  void _pauseReadAloud() {
    _readAloud.pause();
    setState(() {
      _isReadAloudPlaying = false;
      _isReadAloudPaused = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('暂停朗读'), duration: Duration(seconds: 1)),
    );
  }

  void _resumeReadAloud() {
    _readAloud.resume();
    setState(() {
      _isReadAloudPlaying = true;
      _isReadAloudPaused = false;
    });
  }

  void _stopReadAloud() {
    _readAloud.stop();
    setState(() {
      _isReadAloudPlaying = false;
      _isReadAloudPaused = false;
      _currentReadAloudIndex = -1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('停止朗读'), duration: Duration(seconds: 1)),
    );
  }

  void _scrollToCurrentSentence(int index) {
    // 朗读时不再需要滚动，因为只显示当前句子及后面的内容
  }

  Widget _buildHighlightedText(Color textColor) {
    if (_readAloudSentences.isEmpty || _currentReadAloudIndex < 0) {
      return SelectableText(
        _content,
        style: TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: textColor,
        ),
      );
    }

    // 保持原有文本内容不变，只高亮当前句子
    final currentSentence = _readAloudSentences[_currentReadAloudIndex];
    
    // 浅色模式：浅蓝色背景，暗色模式：浅黄色背景
    final highlightBgColor = _isDarkMode 
        ? const Color(0xFF3D3D00)  // 暗色模式：浅黄背景
        : const Color(0xFFADD8E6); // 浅色模式：浅蓝背景
    final highlightTextColor = _isDarkMode 
        ? Colors.yellow 
        : Colors.blue;

    // 在原文中查找当前句子的位置
    final textWithoutNewlines = _content.replaceAll('\n', '');

    int searchStart = 0;
    for (int i = 0; i < _currentReadAloudIndex; i++) {
      final prevSentence = _readAloudSentences[i];
      final idx = textWithoutNewlines.indexOf(prevSentence, searchStart);
      if (idx != -1) {
        searchStart = idx + prevSentence.length;
      }
    }

    final sentenceStartInPlain = textWithoutNewlines.indexOf(currentSentence, searchStart);

    if (sentenceStartInPlain == -1) {
      // 如果找不到句子，直接显示原文
      return SelectableText(
        _content,
        style: TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: textColor,
        ),
      );
    }

    // 将无换行的位置转换为实际文本位置
    int actualStart = 0;
    int plainPos = 0;
    for (int i = 0; i < _content.length && plainPos < sentenceStartInPlain; i++) {
      if (_content[i] != '\n') {
        plainPos++;
      }
      actualStart++;
    }

    // 找到句子结束的实际位置
    int actualEnd = actualStart;
    int matchedChars = 0;
    for (int i = actualStart; i < _content.length && matchedChars < currentSentence.length; i++) {
      if (_content[i] != '\n') {
        matchedChars++;
      }
      actualEnd++;
    }
    
    // 高亮范围多加2个字符
    actualEnd = (actualEnd + 2).clamp(actualEnd, _content.length);

    // 构建 TextSpan：朗读时只显示当前句子及后面的内容
    final List<TextSpan> spans = [];

    // 高亮的当前句子
    spans.add(TextSpan(
      text: _content.substring(actualStart, actualEnd),
      style: TextStyle(
        fontSize: _fontSize,
        height: _lineHeight,
        color: highlightTextColor,
        fontWeight: FontWeight.bold,
        backgroundColor: highlightBgColor,
      ),
    ));

    // 高亮后的文本
    if (actualEnd < _content.length) {
      spans.add(TextSpan(
        text: _content.substring(actualEnd),
        style: TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: textColor,
        ),
      ));
    }

    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: TextStyle(
          fontSize: _fontSize,
          height: _lineHeight,
          color: textColor,
        ),
      ),
    );
  }

  void _showReadAloudConfig() {
    showDialog(
      context: context,
      builder: (context) => const _ReadAloudConfigDialog(),
    );
  }

  List<String> _splitContentForReadAloud(String content) {
    final sentenceParts = content.split(RegExp(r'([。！？\n])'));
    
    final sentences = <String>[];
    for (int i = 0; i < sentenceParts.length; i++) {
      final part = sentenceParts[i].trim();
      if (part.isNotEmpty) {
        sentences.add(part);
      }
    }
    
    return sentences;
  }
}

class _ReadAloudConfigDialog extends StatefulWidget {
  const _ReadAloudConfigDialog();

  @override
  State<_ReadAloudConfigDialog> createState() => _ReadAloudConfigDialogState();
}

class _ReadAloudConfigDialogState extends State<_ReadAloudConfigDialog> {
  double _speechRate = 1.0;
  double _volume = 1.0;
  String _engineName = '系统默认';

  @override
  void initState() {
    super.initState();
    final tts = TTSReadAloudService();
    _speechRate = tts.speechRate;
    _volume = tts.volume;
    _engineName = TTSEngineManager().getEngineDisplayName();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('朗读配置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: const Text('朗读引擎'),
            subtitle: Text(_engineName),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TTSEnginePage()),
              );
              setState(() {
                _engineName = TTSEngineManager().getEngineDisplayName();
              });
            },
          ),
          const Divider(),
          _buildSlider('语速', _speechRate, 0.5, 2.0, 15, (v) => _speechRate = v, '慢', '快'),
          const SizedBox(height: 20),
          _buildSlider('音量', _volume, 0.0, 2.0, 20, (v) => _volume = v, '小', '大'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveConfig,
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, int divisions, Function(double) onChanged, String left, String right) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(left), Text(value.toStringAsFixed(1)), Text(right)],
        ),
      ],
    );
  }

  void _saveConfig() {
    final tts = TTSReadAloudService();
    tts.setSpeechRate(_speechRate);
    tts.setVolume(_volume);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('朗读配置已保存 (语速: ${_speechRate.toStringAsFixed(1)}, 音量: ${_volume.toStringAsFixed(1)})')),
    );
  }
}

class _BookmarkManagerDialog extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final Function(Bookmark) onJump;
  final Function(Bookmark) onDelete;

  const _BookmarkManagerDialog({
    required this.bookmarks,
    required this.onJump,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('书签管理'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return ListTile(
              title: Text(
                bookmark.bookmarkName,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                '${bookmark.chapterTitle} (${bookmark.createTime.toString().substring(0, 19)})',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 20),
                    onPressed: () => onJump(bookmark),
                    tooltip: '跳转到',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => onDelete(bookmark),
                    tooltip: '删除',
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
