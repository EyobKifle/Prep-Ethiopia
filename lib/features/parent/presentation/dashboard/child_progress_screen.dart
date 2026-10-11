import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/auth_provider.dart';

class ChildProgressScreen extends ConsumerStatefulWidget {
  final String studentUuid;
  const ChildProgressScreen({super.key, required this.studentUuid});

  @override
  ConsumerState<ChildProgressScreen> createState() => _ChildProgressScreenState();
}

class _ChildProgressScreenState extends ConsumerState<ChildProgressScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _subjectProgress = [];

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(remoteApiServiceProvider);
      final progress = await api.fetchChildProgress(studentUuid: widget.studentUuid);
      setState(() {
        _subjectProgress = progress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Child Progress Detail')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _subjectProgress.length,
              itemBuilder: (context, index) {
                final item = _subjectProgress[index];
                final double percent = (item['completed_steps'] ?? 0) / (item['total_steps'] ?? 1);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['subject_name'] ?? 'Subject',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: percent,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${(percent * 100).toInt()}% Completed'),
                            Text('${item['completed_steps']} / ${item['total_steps']} steps'),
                          ],
                        ),
                        if (item['last_quiz_score'] != null) ...[
                          const Divider(height: 24),
                          Text('Last Quiz Score: ${item['last_quiz_score']}%'),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
