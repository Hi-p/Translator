import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../premium/premium_state.dart';
import 'auth_service.dart';
import '../admin/admin_dashboard_modal.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
  });
}

final userProvider = StateProvider<UserProfile?>((ref) => null);

class AuthModal extends ConsumerStatefulWidget {
  const AuthModal({super.key});

  @override
  ConsumerState<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends ConsumerState<AuthModal> {
  bool _isSignUp = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('알림', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (_isSignUp) {
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        _showAlertDialog('이름, 이메일, 비밀번호를 입력해주세요.');
        return;
      }
    } else {
      if (email.isEmpty || password.isEmpty) {
        _showAlertDialog('이메일, 비밀번호를 입력해주세요.');
        return;
      }
    }

    final authService = ref.read(authServiceProvider);

    try {
      UserData? resultUser;
      if (_isSignUp) {
        resultUser = await authService.signUp(email: email, password: password, displayName: name);
      } else {
        resultUser = await authService.signIn(email, password);
      }

      if (resultUser != null) {
        ref.read(userProvider.notifier).state = UserProfile(
          id: resultUser.id,
          email: resultUser.email,
          displayName: resultUser.displayName,
        );
        ref.read(isProUserProvider.notifier).state = resultUser.isPro;
        
        await authService.saveLoginSession(resultUser.id);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${resultUser.displayName}님 환영합니다!')),
          );
        }
      }
    } catch (e) {
      _showAlertDialog(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _cancelSubscription() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('구독 취소', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('정말 PRO 구독을 취소하시겠습니까?\n취소 시 전문 도메인 번역 등 모든 프리미엄 혜택이 즉시 종료됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(isProUserProvider.notifier).state = false;
              
              final user = ref.read(userProvider);
              if (user != null) {
                ref.read(authServiceProvider).updateProStatus(user.id, false);
              }
              
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close auth modal
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('구독이 취소되었습니다. 이용해 주셔서 감사합니다.'),
                  backgroundColor: Colors.grey,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('네, 취소합니다', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isPro = ref.watch(isProUserProvider);

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user == null ? (_isSignUp ? '회원가입' : '로그인') : '내 프로필',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (user == null) ...[
            if (_isSignUp) ...[
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '이름 / 닉네임',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '아이디 / 이메일',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleAuth(),
              decoration: const InputDecoration(
                labelText: '비밀번호',
                prefixIcon: Icon(Icons.lock_outline_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_isSignUp ? '회원가입' : '로그인'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isSignUp ? '이미 계정이 있으신가요? ' : '계정이 없으신가요? ',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(
                      _isSignUp ? '로그인' : '회원가입',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        user.displayName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPro
                                      ? Colors.amber.shade700
                                      : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPro ? 'PRO PLAN' : 'FREE PLAN',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.star_rounded,
                  color: isPro ? Colors.amber : Colors.grey,
                ),
                title: Text(isPro ? 'PRO 멤버십 이용 중' : 'PRO 멤버십 혜택'),
                subtitle: Text(
                  isPro
                      ? '전문 분야 번역 및 무제한 기능 이용 가능'
                      : '기술, 법률, 의료 등 전문 번역 기능 해제',
                ),
                trailing: (isPro && user.id != 'admin_id_000')
                    ? TextButton(
                        onPressed: _cancelSubscription,
                        child: const Text('구독 취소', style: TextStyle(color: Colors.red)),
                      )
                    : null,
              ),
            ),
            if (user.id == 'admin_id_000') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const AdminDashboardModal(),
                    );
                  },
                  icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                  label: const Text('관리자 대시보드 (회원 관리)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(userProvider.notifier).state = null;
                  ref.read(isProUserProvider.notifier).state = false;
                  ref.read(authServiceProvider).clearLoginSession();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그아웃 되었습니다.')),
                  );
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text(
                  '로그아웃',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
