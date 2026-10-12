import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import '../../../../core/database/isar_models.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/localization/app_localizations.dart';

class LessonFlashcardScreen extends ConsumerStatefulWidget {
  final String lessonUuid;
  final String stepUuid;
  const LessonFlashcardScreen({super.key, required this.lessonUuid, required this.stepUuid});

  @override
  ConsumerState<LessonFlashcardScreen> createState() => _LessonFlashcardScreenState();
}

class _LessonFlashcardScreenState extends ConsumerState<LessonFlashcardScreen> {
  List<FlashcardTemplateLocal> _templates = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isLoading = true;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isar = ref.read(isarProvider);
    
    // Find unitUuid via lessonUuid
    final lesson = await isar.lessonLocals.where().uuidEqualTo(widget.lessonUuid).findFirst();
    if (lesson == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Load templates for this unit
    final templates = await isar.flashcardTemplateLocals
        .where()
        .unitUuidEqualTo(lesson.unitUuid)
        .findAll();

    if (mounted) {
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    }
  }

  void _flipCard() {
    setState(() => _isFlipped = !_isFlipped);
  }

  Future<void> _rateCard(int quality) async {
    final template = _templates[_currentIndex];
    final isar = ref.read(isarProvider);

    // Load or create UserFlashcardLocal
    var userCard = await isar.userFlashcardLocals
        .where()
        .cardTemplateUuidEqualTo(template.uuid)
        .findFirst();

    userCard ??= UserFlashcardLocal()
      ..uuid = 'uf_${template.uuid}'
      ..cardTemplateUuid = template.uuid
      ..easeFactor = 2.5
      ..intervalDays = 0
      ..repetitions = 0
      ..nextReviewAt = DateTime.now()
      ..isDeleted = false;

    // SM-2 Algorithm
    double ef = userCard.easeFactor;
    int interval = userCard.intervalDays;
    int repetitions = userCard.repetitions;

    if (quality >= 3) {
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * ef).round();
      }
      repetitions++;
    } else {
      repetitions = 0;
      interval = 1;
    }

    ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (ef < 1.3) ef = 1.3;

    userCard
      ..easeFactor = ef
      ..intervalDays = interval
      ..repetitions = repetitions
      ..nextReviewAt = DateTime.now().add(Duration(days: interval))
      ..lastReviewedAt = DateTime.now()
      ..isDirty = true
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.userFlashcardLocals.put(userCard!);
    });

    if (_currentIndex < _templates.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      setState(() => _isFinished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_templates.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.tr('emptyStateTitle'))),
      );
    }

    if (_isFinished) {
      return _buildFinishedView();
    }

    final template = _templates[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('${context.tr('flashcardStep')} (${_currentIndex + 1}/${_templates.length})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _flipCard,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final rotate = Tween(begin: pi, end: 0.0).animate(animation);
                    return AnimatedBuilder(
                      animation: rotate,
                      child: child,
                      builder: (context, child) {
                        final isUnder = (ValueKey(_isFlipped) != child!.key);
                        final value = isUnder ? min(rotate.value, pi / 2) : rotate.value;
                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(value),
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                    );
                  },
                  child: _isFlipped ? _buildCardSide(template.backText.getLocalized(context.currentLocale), true) 
                                   : _buildCardSide(template.frontText.getLocalized(context.currentLocale), false),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (!_isFlipped)
              Text(
                context.tr('tapToFlip'), 
                style: TextStyle(
                  color: Colors.grey.shade600, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            if (_isFlipped)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRatingButton(context.tr('flashcardHard'), 2, Colors.red.shade400),
                  _buildRatingButton(context.tr('flashcardGood'), 4, Colors.orange.shade400),
                  _buildRatingButton(context.tr('flashcardEasy'), 5, Colors.green.shade400),
                ],
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSide(String text, bool isBack) {
    return Container(
      key: ValueKey(isBack),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08), 
            blurRadius: 15, 
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isBack ? Theme.of(context).primaryColor.withValues(alpha: 0.3) : Colors.grey.shade200, 
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (isBack ? Theme.of(context).primaryColor : Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isBack ? 'ANSWER' : 'QUESTION',
                style: TextStyle(
                  color: isBack ? Theme.of(context).primaryColor : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26, 
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton(String label, int quality, Color color) {
    return ElevatedButton(
      onPressed: () => _rateCard(quality),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildFinishedView() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 100, color: Colors.green),
                const SizedBox(height: 32),
                Text(
                  context.tr('flashcardComplete'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'You have reviewed all ${_templates.length} cards in this unit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(context.tr('finish'), style: const TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
