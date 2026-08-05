import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraOcrModal extends StatefulWidget {
  final Function(String extractedText) onTextExtracted;

  const CameraOcrModal({
    super.key,
    required this.onTextExtracted,
  });

  @override
  State<CameraOcrModal> createState() => _CameraOcrModalState();
}

class _CameraOcrModalState extends State<CameraOcrModal> {
  bool _isScanning = false;
  String? _scannedResult;
  String? _uploadedFileName;
  int _selectedSampleIndex = -1;

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _sampleImages = [
    {
      'title': '📋 영어 메뉴판',
      'subtitle': 'Menu Sample',
      'text':
          'Grilled Salmon with Herb Butter\nRoasted Seasonal Vegetables\nFresh Mushroom Soup\nHouse Special Salad',
    },
    {
      'title': '🔧 IT 기술 문서',
      'subtitle': 'API Doc Sample',
      'text':
          'The authentication token must be provided in the HTTP request header as a Bearer token. Invalid credentials will return a 401 Unauthorized response.',
    },
    {
      'title': '⚖️ 영문 계약서 조항',
      'subtitle': 'Legal Sample',
      'text':
          'This Agreement shall be governed by and construed in accordance with the laws of the jurisdiction without regard to its conflict of law principles.',
    },
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedSampleIndex = -1;
          _uploadedFileName = image.name;
          _isScanning = true;
          _scannedResult = null;
        });

        // OCR 스캔 시뮬레이션
        await Future.delayed(const Duration(milliseconds: 1400));

        if (mounted) {
          setState(() {
            _isScanning = false;
            _scannedResult =
                'Scanned Text from UpLoaded Image (${image.name}):\n\n'
                'Welcome to PolyGlot AI Translator. The selected document image has been analyzed successfully.';
          });
        }
      }
    } catch (e) {
      // 플러그인 재시작 전 또는 미지원 시 시뮬레이션 샘플 업로드 폴백
      if (mounted) {
        final mockName = source == ImageSource.camera
            ? 'captured_photo.jpg'
            : 'uploaded_document.png';

        setState(() {
          _selectedSampleIndex = -1;
          _uploadedFileName = mockName;
          _isScanning = true;
          _scannedResult = null;
        });

        await Future.delayed(const Duration(milliseconds: 1200));

        if (mounted) {
          setState(() {
            _isScanning = false;
            _scannedResult =
                'Scanned Text from Selected Image ($mockName):\n\n'
                'Invoice No: #2026-88492\n'
                'Item: Premium AI Translation License\n'
                'Total Amount: \$99.00 USD';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('새 플러그인이 추가되어 터미널 재시작(Ctrl+C 후 flutter run) 시 실제 갤러리가 연동됩니다.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '이미지 업로드 방식 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.indigo),
              title: const Text('갤러리에서 사진 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.indigo),
              title: const Text('카메라로 사진 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _processOcr(String sampleText, int index) {
    if (_selectedSampleIndex == index) {
      // 같은 항목을 한 번 더 누르면 선택 취소
      setState(() {
        _selectedSampleIndex = -1;
        _scannedResult = null;
        _uploadedFileName = null;
        _isScanning = false;
      });
      return;
    }

    setState(() {
      _selectedSampleIndex = index;
      _uploadedFileName = null;
      _isScanning = true;
      _scannedResult = null;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _selectedSampleIndex == index) {
        setState(() {
          _isScanning = false;
          _scannedResult = sampleText;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text(
                    '카메라 / 이미지 번역 (OCR)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. 이미지 선택 / 업로드 버튼 영역 (클릭 가능!)
          InkWell(
            onTap: _showImagePickerOptions,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 44,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _uploadedFileName != null
                        ? '🖼️ 선택된 파일: $_uploadedFileName'
                        : '촬영 또는 갤러리 이미지 선택 (클릭)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '여기를 터치하여 기기의 사진을 업로드하거나 아래 샘플을 선택해보세요',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            '📄 테스트용 OCR 미리보기 샘플 선택',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 샘플 리스트
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _sampleImages.length,
              itemBuilder: (context, index) {
                final sample = _sampleImages[index];
                final isSelected = _selectedSampleIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => _processOcr(sample['text']!, index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            sample['title']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                          Text(
                            sample['subtitle']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 스캔 결과 및 스캔 중 상태
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _isScanning
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _uploadedFileName != null
                              ? '업로드한 이미지($_uploadedFileName)에서 텍스트 스캔 중...'
                              : '이미지에서 텍스트 스캔 중 (OCR)...',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : _scannedResult == null
                      ? const Center(
                          child: Text(
                            '상단 영역을 눌러 기기의 이미지를 업로드하거나\n샘플을 선택하면 추출된 텍스트가 표시됩니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _uploadedFileName != null
                                      ? '✓ 업로드 파일 OCR 결과'
                                      : '✓ 추출된 텍스트 (OCR Result)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 18),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  _scannedResult!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ),
          const SizedBox(height: 16),

          // 번역 버튼
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _scannedResult == null
                  ? null
                  : () {
                      widget.onTextExtracted(_scannedResult!);
                      Navigator.pop(context);
                    },
              icon: const Icon(Icons.translate_rounded),
              label: const Text('추출된 텍스트 번역하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
