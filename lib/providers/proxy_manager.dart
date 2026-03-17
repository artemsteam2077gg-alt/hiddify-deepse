import 'package:flutter/material.dart';

class ProxyManager extends ChangeNotifier {
  List<Proxy> _proxies = [];
  bool _isConnected = false;
  String _subscriptionUrl = '';
  
  List<Proxy> get proxies => _proxies;
  bool get isConnected => _isConnected;
  String get subscriptionUrl => _subscriptionUrl;
  
  void setAutoSelectMode(bool enabled) {
    // Здесь будет логика автовыбора
    notifyListeners();
  }
  
  void autoSelectLowestPing() {
    // Здесь будет логика выбора сервера с наименьшим пингом
    notifyListeners();
  }
  
  Future<void> addProfileFromUrl(String url) async {
    _subscriptionUrl = url;
    // Здесь будет загрузка и добавление профиля
    notifyListeners();
  }
  
  Future<void> connect() async {
    _isConnected = true;
    notifyListeners();
  }
  
  void connectToProxy(Proxy proxy) {
    // Подключение к конкретному прокси
    notifyListeners();
  }
}

class Proxy {
  final String remark;
  final int ping;
  
  Proxy({required this.remark, required this.ping});
}
