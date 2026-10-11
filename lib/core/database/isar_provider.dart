import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

// Global provider for the Isar instance
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('Isar has not been initialized');
});
