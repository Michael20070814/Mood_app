import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const EmotionApp());
}

class EmotionApp extends StatelessWidget {
  const EmotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '情绪盒子',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF7C4DFF),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const EmotionHomePage(),
    );
  }
}

class Emotion {
  final String emoji;
  final String title;
  final String defaultMessage;
  final Color bgColor;

  const Emotion({
    required this.emoji,
    required this.title,
    required this.defaultMessage,
    required this.bgColor,
  });
}

final emotions = [
  Emotion(
    emoji: "😊",
    title: "开心",
    defaultMessage: "太好了！愿你继续保持这份轻松与快乐～",
    bgColor: Colors.orange.shade100,
  ),
  Emotion(
    emoji: "😢",
    title: "难过",
    defaultMessage: "抱抱你，一切都会慢慢好起来的。",
    bgColor: Colors.blue.shade100,
  ),
  Emotion(
    emoji: "😡",
    title: "生气",
    defaultMessage: "别让情绪困住你，你值得被温柔以待。",
    bgColor: Colors.red.shade100,
  ),
  Emotion(
    emoji: "😴",
    title: "疲惫",
    defaultMessage: "休息一下吧，你已经尽力了。",
    bgColor: Colors.purple.shade100,
  ),
  Emotion(
    emoji: "😰",
    title: "焦虑",
    defaultMessage: "没关系的，慢慢来，一步步都会好。",
    bgColor: Colors.teal.shade100,
  ),
  Emotion(
    emoji: "🤒",
    title: "不舒服",
    defaultMessage: "照顾好自己最重要，好好休息。",
    bgColor: Colors.green.shade100,
  ),
];

class MessageService {
  static const String _cacheKey = 'emotion_messages_cache';
  static const String _lastFetchKey = 'emotion_messages_last_fetch';
  static const Duration _cacheDuration = Duration(hours: 1);

  static const String _remoteUrl =
      'https://raw.githubusercontent.com/yourusername/yourrepo/main/emotion_messages.json';

  static final Map<String, List<String>> _cachedMessages = {};
  static final Random _random = Random();

  static Future<void> initialize() async {
    await _loadCachedMessages();

    final prefs = await SharedPreferences.getInstance();
    final lastFetch = prefs.getInt(_lastFetchKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lastFetch == null ||
        now - lastFetch > _cacheDuration.inMilliseconds) {
      await refreshMessages();
    }
  }

  static Future<void> refreshMessages() async {
    try {
      final response = await http
          .get(Uri.parse(_remoteUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedMessages.clear();

        data.forEach((key, value) {
          if (value is List) {
            _cachedMessages[key] = value.cast<String>();
          }
        });

        await _saveMessagesToCache(data);
      }
    } catch (e) {}
  }

  static String getRandomMessage(String emotionTitle) {
    final messages = _cachedMessages[emotionTitle];
    if (messages != null && messages.isNotEmpty) {
      return messages[_random.nextInt(messages.length)];
    }

    final emotion = emotions.firstWhere(
      (e) => e.title == emotionTitle,
      orElse: () => emotions.first,
    );
    return emotion.defaultMessage;
  }

  static Future<void> _loadCachedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);

    if (cached != null) {
      try {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        _cachedMessages.clear();
        data.forEach((key, value) {
          if (value is List) {
            _cachedMessages[key] = value.cast<String>();
          }
        });
      } catch (_) {}
    }
  }

  static Future<void> _saveMessagesToCache(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data));
    await prefs.setInt(
        _lastFetchKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Map<String, List<String>> get currentCache =>
      Map.unmodifiable(_cachedMessages);
}

class EmotionHomePage extends StatefulWidget {
  const EmotionHomePage({super.key});

  @override
  State<EmotionHomePage> createState() => _EmotionHomePageState();
}

class _EmotionHomePageState extends State<EmotionHomePage>
    with TickerProviderStateMixin {
  final Map<int, int> _counts = {};
  Timer? _timer;
  final Map<int, AnimationController> _pulseControllers = {};
  final Map<int, Animation<double>> _pulseAnimations = {};
  bool _isInitialized = false;
  bool _isLoadingMessages = true;

  bool get _hasEmotions => _counts.values.any((value) => value > 0);

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < emotions.length; i++) {
      _pulseControllers[i] = AnimationController(
        duration: const Duration(milliseconds: 150),
        vsync: this,
      );
      _pulseAnimations[i] = Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: _pulseControllers[i]!, curve: Curves.easeInOut),
      );
    }

    _initializeMessages();
  }

  Future<void> _initializeMessages() async {
    await MessageService.initialize();
    setState(() {
      _isLoadingMessages = false;
      _isInitialized = true;
    });
  }

  Future<void> _refreshMessages() async {
    setState(() => _isLoadingMessages = true);
    await MessageService.refreshMessages();
    setState(() => _isLoadingMessages = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _pulseControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startCounting(int index) {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    _pulseControllers[index]?.forward();
    _startTimer(index);
  }

  void _startTimer(int index) {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      HapticFeedback.lightImpact();
      setState(() {
        int current = _counts[index] ?? 0;
        _counts[index] = current + 1;
      });
    });
  }

  void _stopCounting() {
    _timer?.cancel();
    for (var controller in _pulseControllers.values) {
      controller.reverse();
    }
  }

  void _synthesizeEmotions() {
    HapticFeedback.heavyImpact();
    setState(() {
      _counts.clear();
    });

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const _SuccessAnimation(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.5),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "情绪盒子",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 2,
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          IconButton(
            icon: _isLoadingMessages
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoadingMessages ? null : _refreshMessages,
            tooltip: '刷新消息',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _hasEmotions
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.shade300.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  onPressed: _synthesizeEmotions,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.pink.shade400,
                  elevation: 0,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text(
                    "能量转化",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/home_page1.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isInitialized
                ? _buildBentoGrid()
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _buildBentoGrid() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _hasEmotions ? "选择情绪来释放能量" : "今天感觉怎么样？",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final emotion = emotions[index];
                final count = _counts[index] ?? 0;
                return _EmotionCard(
                  emotion: emotion,
                  count: count,
                  index: index,
                  onLongPressStart: () => _startCounting(index),
                  onLongPressEnd: () => _stopCounting(),
                  pulseAnimation: _pulseAnimations[index],
                );
              },
              childCount: emotions.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmotionCard extends StatelessWidget {
  final Emotion emotion;
  final int count;
  final int index;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final Animation<double>? pulseAnimation;

  const _EmotionCard({
    required this.emotion,
    required this.count,
    required this.index,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: GestureDetector(
        onLongPressStart: (_) => onLongPressStart(),
        onLongPressEnd: (_) => onLongPressEnd(),
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black.withValues(alpha: 0.8),
              barrierDismissible: true,
              transitionDuration: const Duration(milliseconds: 400),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, __, ___) => EmotionDetailPage(emotion: emotion),
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
              builder: (context, child) {
                return Transform.scale(
                  scale: pulseAnimation?.value ?? 1.0,
                  child: child,
                );
              },
              child: Hero(
                tag: emotion.title,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: emotion.bgColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: emotion.bgColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(2, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              emotion.emoji,
                              style: const TextStyle(fontSize: 45),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              emotion.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: -10,
                top: -15,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      "x$count",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmotionDetailPage extends StatefulWidget {
  final Emotion emotion;

  const EmotionDetailPage({super.key, required this.emotion});

  @override
  State<EmotionDetailPage> createState() => _EmotionDetailPageState();
}

class _EmotionDetailPageState extends State<EmotionDetailPage>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late String _message;

  @override
  void initState() {
    super.initState();

    _message = MessageService.getRandomMessage(widget.emotion.title);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _refreshMessage() {
    setState(() {
      _message = MessageService.getRandomMessage(widget.emotion.title);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleUpdate: (details) {
        setState(() {
          _scale = details.scale.clamp(0.5, 1.5);
        });
        if (_scale < 0.6) {
          Navigator.pop(context);
        }
      },
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: () {},
            child: Hero(
              tag: widget.emotion.title,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scale,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.75,
                    minHeight: 350,
                  ),
                  decoration: BoxDecoration(
                    color: widget.emotion.bgColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: widget.emotion.bgColor.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.emotion.emoji,
                              style: const TextStyle(fontSize: 80),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              widget.emotion.title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 1,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 24),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _message,
                                key: ValueKey(_message),
                                style: const TextStyle(
                                  fontSize: 18,
                                  height: 1.6,
                                  color: Colors.black87,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextButton.icon(
                              onPressed: _refreshMessage,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('换一条'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black54,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "点击背景关闭",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black38,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessAnimation extends StatefulWidget {
  const _SuccessAnimation();

  @override
  State<_SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<_SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.pink.shade300,
              Colors.purple.shade300,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.4),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 60,
            ),
            SizedBox(height: 16),
            Text(
              "能量转化成功!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
