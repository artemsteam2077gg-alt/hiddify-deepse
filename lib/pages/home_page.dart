import 'package:flutter/material.dart';
import 'package:hiddify/core/provider/proxy_manager.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isHunting = false;
  int _huntSeconds = 300; // 5 минут
  Timer? _huntTimer;
  String _status = 'Готов к работе';
  int _currentThemeIndex = 0;
  
  // 10 тем DeepSe
  final List<Color> _themeColors = [
    const Color(0xFF0A1A2A), // DeepSeek Classic
    const Color(0xFF1A0F1F), // Dark Nebula
    const Color(0xFF0A1F0A), // Cyber Green
    const Color(0xFF1A0F2A), // Royal Purple
    const Color(0xFF2A1F0A), // Amber Glow
    const Color(0xFF0A1F2A), // Ocean Deep
    const Color(0xFF2A0F0F), // Ruby Red
    const Color(0xFF0F2A1F), // Emerald
    const Color(0xFF2A1A0F), // Sunset
    const Color(0xFF1A1A1A), // Graphite
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentThemeIndex = prefs.getInt('themeIndex') ?? 0;
    });
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeIndex', _currentThemeIndex);
  }

  void _changeTheme() {
    setState(() {
      _currentThemeIndex = (_currentThemeIndex + 1) % _themeColors.length;
    });
    _saveTheme();
  }

  // === КНОПКА ТУРБО (использует встроенный LowestPing Hiddify) ===
  void _startTurbo() {
    setState(() {
      _status = '🚀 ТУРБО режим активирован';
    });
    
    // Используем встроенную функцию Hiddify [citation:1]
    context.read<ProxyManager>().setAutoSelectMode(true);
    context.read<ProxyManager>().autoSelectLowestPing();
  }

  // === КНОПКА ОХОТНИК (поиск идеального ключа) ===
  void _startHunter() async {
    if (_isHunting) return;
    
    setState(() {
      _isHunting = true;
      _huntSeconds = 300;
      _status = '🔍 ОХОТНИК: ищу ключи...';
    });

    _huntTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_huntSeconds > 0) {
          _huntSeconds--;
        } else {
          _stopHunt('⏰ Время вышло');
        }
      });
    });

    // Запускаем поиск в фоне
    _performHunt();
  }

  void _stopHunt(String message) {
    _huntTimer?.cancel();
    setState(() {
      _isHunting = false;
      _status = message;
    });
  }

  Future<void> _performHunt() async {
    try {
      // Берём подписку пользователя из настроек Hiddify
      final subscriptionUrl = context.read<ProxyManager>().getCurrentSubscriptionUrl();
      if (subscriptionUrl.isEmpty) {
        _stopHunt('❌ Нет подписки');
        return;
      }

      final response = await http.get(Uri.parse(subscriptionUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        _stopHunt('❌ Ошибка загрузки');
        return;
      }

      // Парсим VLESS ключи
      final RegExp exp = RegExp(r'vless://[a-f0-9\-]+@[a-zA-Z0-9\.\-]+:\d+');
      final Iterable<RegExpMatch> matches = exp.allMatches(response.body);
      final List<String> keys = matches.map((m) => m.group(0)!).toList();
      
      setState(() {
        _status = '🔍 Найдено ${keys.length} ключей. Тестирую...';
      });

      // === ПРОВЕРКИ ИЗ GITHUB (быстрый пинг + TCP) ===
      String? bestKey;
      int bestPing = 9999;
      
      for (final key in keys.take(100)) { // Тестируем первые 100
        if (!_isHunting) break;
        
        final ip = key.split('@')[1].split(':')[0];
        final stopwatch = Stopwatch()..start();
        
        try {
          // Тест 1: TCP соединение
          final socket = await Socket.connect(ip, 443, timeout: Duration(seconds: 2));
          socket.destroy();
          
          // Тест 2: HTTP пинг
          final client = HttpClient();
          await client.getUrl(Uri.parse('http://$ip'));
          stopwatch.stop();
          client.close();
          
          final ping = stopwatch.elapsedMilliseconds;
          if (ping < bestPing) {
            bestPing = ping;
            bestKey = key;
          }
        } catch (e) {
          continue;
        }
      }

      if (bestKey != null) {
        setState(() {
          _status = '🏆 НАЙДЕН КЛЮЧ! Пинг: ${bestPing}ms';
        });
        
        // Добавляем найденный ключ как новый профиль
        await context.read<ProxyManager>().addProfileFromUrl(bestKey!);
        await context.read<ProxyManager>().connect();
      } else {
        _stopHunt('❌ Рабочие ключи не найдены');
      }
    } catch (e) {
      _stopHunt('❌ Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DeepSe VPN'),
        backgroundColor: _themeColors[_currentThemeIndex],
        actions: [
          // Кнопка смены темы
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: _changeTheme,
          ),
        ],
      ),
      body: Container(
        color: _themeColors[_currentThemeIndex].withOpacity(0.1),
        child: Column(
          children: [
            // === НАШИ ДВЕ КНОПКИ ===
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isHunting ? null : _startTurbo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 80),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed, size: 32),
                          Text('ТУРБО', style: TextStyle(fontSize: 18)),
                          Text('Автовыбор сервера', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isHunting ? null : _startHunter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 80),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search, size: 32),
                          const Text('ОХОТНИК', style: TextStyle(fontSize: 18)),
                          const Text('Поиск идеального', style: TextStyle(fontSize: 12)),
                          if (_isHunting)
                            Text(
                              '${_huntSeconds ~/ 60}:${(_huntSeconds % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Строка статуса
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _status,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            
            // Остальной интерфейс Hiddify (ProxyList и т.д.)
            Expanded(
              child: _buildHiddifyContent(),
            ),
          ],
        ),
      ),
    );
  }

  // Встроенный контент Hiddify (серверы, статистика)
  Widget _buildHiddifyContent() {
    return Consumer<ProxyManager>(
      builder: (context, proxyManager, child) {
        // Здесь будет стандартный UI Hiddify с серверами
        return proxyManager.proxies.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: proxyManager.proxies.length,
                itemBuilder: (context, index) {
                  final proxy = proxyManager.proxies[index];
                  return ListTile(
                    title: Text(proxy.remark),
                    subtitle: Text('Пинг: ${proxy.ping}ms'),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => proxyManager.connectToProxy(proxy),
                    ),
                  );
                },
              );
      },
    );
  }
}
