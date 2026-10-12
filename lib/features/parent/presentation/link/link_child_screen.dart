import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/auth_provider.dart';

class LinkChildScreen extends ConsumerStatefulWidget {
  const LinkChildScreen({super.key});

  @override
  ConsumerState<LinkChildScreen> createState() => _LinkChildScreenState();
}

class _LinkChildScreenState extends ConsumerState<LinkChildScreen> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _linkStudent() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid 6-digit code')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(remoteApiServiceProvider);
      final isar = ref.read(isarProvider);
      final auth = ref.read(authProvider);
      final parentUuid = auth.profile?.uuid;

      if (parentUuid == null) {
        throw Exception('Parent profile not found');
      }

      // 1. Verify code with backend
      final response = await api.verifyLinkCode(code: code);
      final studentUuid = response['student_id'] as String?;

      if (studentUuid == null) {
        throw Exception('Invalid link code or student not found');
      }

      // 2. Create link locally
      final link = ParentStudentLinkLocal()
        ..uuid = 'link_${DateTime.now().millisecondsSinceEpoch}'
        ..parentUuid = parentUuid
        ..studentUuid = studentUuid
        ..linkCode = code
        ..linkedAt = DateTime.now()
        ..isDirty = true
        ..isDeleted = false
        ..updatedAt = DateTime.now();

      await isar.writeTxn(() => isar.parentStudentLinkLocals.put(link));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student linked successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to link student: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('addChild'))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.link, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              context.tr('parentCode'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter the 6-digit code from your child\'s profile to link their account and track their progress.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                hintText: 'e.g. 123456',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.vpn_key_outlined),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _linkStudent,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting 
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(context.tr('link')),
            ),
          ],
        ),
      ),
    );
  }
}
