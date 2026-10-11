import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('navSearch'),
              style: AppTheme.getHeadingStyle(context: context, fontSize: 24),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: context.tr('searchHint'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: AppTheme.borderRadius,
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text('Search results will appear here'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
