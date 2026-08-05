import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserData {
  final String id;
  final String email;
  final String password;
  final String displayName;
  final bool isPro;
  final String createdAt;

  UserData({
    required this.id,
    required this.email,
    required this.password,
    required this.displayName,
    this.isPro = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'password': password,
    'displayName': displayName,
    'isPro': isPro,
    'createdAt': createdAt,
  };

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
    id: json['id'],
    email: json['email'],
    password: json['password'],
    displayName: json['displayName'],
    isPro: json['isPro'] ?? false,
    createdAt: json['createdAt'] ?? '',
  );
}

class AuthService {
  static const String _usersKey = 'mock_users_db';

  Future<List<UserData>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString(_usersKey);
    if (usersJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(usersJson);
    return decoded.map((e) => UserData.fromJson(e)).toList();
  }

  Future<void> _saveAllUsers(List<UserData> users) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(users.map((e) => e.toJson()).toList());
    await prefs.setString(_usersKey, encoded);
  }

  Future<UserData?> signUp({
    required String email, 
    required String password, 
    required String displayName
  }) async {
    if (email == 'kjo030629@gmail.com') {
      throw Exception('이 이메일은 관리자 전용으로 사용할 수 없습니다.');
    }

    final users = await getAllUsers();
    if (users.any((u) => u.email == email)) {
      throw Exception('이미 가입된 이메일입니다.');
    }

    final newUser = UserData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email,
      password: password,
      displayName: displayName,
      createdAt: DateTime.now().toIso8601String(),
    );

    users.add(newUser);
    await _saveAllUsers(users);
    return newUser;
  }

  Future<UserData?> signIn(String email, String password) async {
    // 관리자 하드코딩
    if (email == 'kjo030629@gmail.com' && password == '1234') {
      return UserData(
        id: 'admin_id_000',
        email: email,
        password: password,
        displayName: '치킨너겟',
        isPro: true,
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    final users = await getAllUsers();
    try {
      final user = users.firstWhere((u) => u.email == email && u.password == password);
      return user;
    } catch (e) {
      throw Exception('이메일 혹은 비밀번호가 틀렸습니다.');
    }
  }

  Future<void> updateProStatus(String id, bool isPro) async {
    if (id == 'admin_id_000') return;
    final users = await getAllUsers();
    final index = users.indexWhere((u) => u.id == id);
    if (index != -1) {
      final user = users[index];
      users[index] = UserData(
        id: user.id,
        email: user.email,
        password: user.password,
        displayName: user.displayName,
        isPro: isPro,
        createdAt: user.createdAt,
      );
      await _saveAllUsers(users);
    }
  }

  Future<void> deleteUser(String id) async {
    if (id == 'admin_id_000') return;
    final users = await getAllUsers();
    users.removeWhere((u) => u.id == id);
    await _saveAllUsers(users);
  }

  static const String _sessionKey = 'current_user_session';

  Future<void> saveLoginSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, userId);
  }

  Future<void> clearLoginSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<UserData?> getLoginSession() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userId = prefs.getString(_sessionKey);
    if (userId == null) return null;

    if (userId == 'admin_id_000') {
      return UserData(
        id: 'admin_id_000',
        email: 'kjo030629@gmail.com',
        password: '1234',
        displayName: '치킨너겟',
        isPro: true,
        createdAt: DateTime.now().toIso8601String(),
      );
    }

    final users = await getAllUsers();
    try {
      return users.firstWhere((u) => u.id == userId);
    } catch (e) {
      return null;
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
