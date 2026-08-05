import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'premium_state.dart';
import '../auth/auth_modal.dart';
import '../auth/auth_service.dart';

class MockIapDialog extends ConsumerStatefulWidget {
  const MockIapDialog({super.key});

  @override
  ConsumerState<MockIapDialog> createState() => _MockIapDialogState();
}

class _MockIapDialogState extends ConsumerState<MockIapDialog> {
  bool _isProcessing = false;
  bool _isSuccess = false;

  final LocalAuthentication auth = LocalAuthentication();

  void _processPayment() async {
    bool authenticated = false;
    
    if (kIsWeb) {
      // 웹 환경에서는 로컬 인증을 우회하고 바로 성공 처리
      authenticated = true;
    } else {
      try {
        final isSupported = await auth.isDeviceSupported();
        if (!isSupported) {
          // 생체 인증이나 패스워드 인증을 지원하지 않는 기기(시뮬레이터 등)일 경우 우회
          authenticated = true;
        } else {
          authenticated = await auth.authenticate(
            localizedReason: 'Translator PRO 결제를 승인해 주세요.',
            biometricOnly: false,
            persistAcrossBackgrounding: true,
          );
        }
      } on PlatformException catch (e) {
        debugPrint('Auth error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('기기 인증에 실패했습니다.')),
          );
        }
      } catch (e) {
        debugPrint('Unknown auth error: $e');
      }
    }

    if (!authenticated) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // 결제 처리 중 시뮬레이션 (1.5초)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _isSuccess = true;
    });

    // 성공 아이콘 띄우고 잠시 대기 (1초)
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;
    
    // PRO 상태로 변경
    ref.read(isProUserProvider.notifier).state = true;
    
    // DB 업데이트
    final user = ref.read(userProvider);
    if (user != null) {
      ref.read(authServiceProvider).updateProStatus(user.id, true);
    }
    
    // 이 창과 아래의 Paywall 창 모두 닫기
    Navigator.of(context).pop();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 결제가 성공적으로 완료되었습니다!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.apple, size: 24),
                const SizedBox(width: 8),
                Text(
                  'App Store',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // App Icon Mock
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.g_translate_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            
            // Item details
            const Text(
              'Translator PRO 구독',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '모든 프리미엄 기능 무제한 해제',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Price
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text('구독 금액', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  SizedBox(height: 4),
                  Text(
                    '₩29,500 / 월',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Payment Button or Status
            SizedBox(
              height: 56,
              width: double.infinity,
              child: _isSuccess
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
                      ],
                    )
                  : _isProcessing
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _processPayment,
                          icon: const Icon(Icons.fingerprint_rounded, size: 28),
                          label: const Text(
                            '결제 승인',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
            ),
            
            if (!_isProcessing && !_isSuccess) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소', style: TextStyle(color: Colors.grey)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
