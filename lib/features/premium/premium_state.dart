import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 현재 유저가 PRO 버전을 구독했는지 여부를 관리하는 Provider
final isProUserProvider = StateProvider<bool>((ref) => false);
