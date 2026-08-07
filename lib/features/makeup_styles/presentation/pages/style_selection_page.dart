import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_ui.dart';

class StyleSelectionPage extends StatefulWidget {
  const StyleSelectionPage({super.key});

  @override
  State<StyleSelectionPage> createState() => _StyleSelectionPageState();
}

class _StyleSelectionPageState extends State<StyleSelectionPage> {
  String selected = 'Soft Glam';
  static const styles = [
    'Natural',
    'Everyday',
    'Office',
    'Soft Glam',
    'Full Glam',
    'Bridal',
    'Korean',
    'Clean Girl',
    'Party',
    'Date Night',
    'No Makeup Makeup',
    'Old Money',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose your mood')),
    body: SafeArea(
      child: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Which look feels like you?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('You can explore a different variation later.'),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: styles.length,
                itemBuilder: (context, index) {
                  final style = styles[index];
                  final active = style == selected;
                  return AppCard(
                    onTap: () => setState(() => selected = style),
                    color: active ? AppColors.petal : null,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          active
                              ? Icons.check_circle_rounded
                              : Icons.auto_awesome_outlined,
                          color: active ? AppColors.rose : AppColors.taupe,
                        ),
                        Text(
                          style,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Analyze my features',
              onPressed: () => context.push(AppConstants.analysisRoute),
            ),
          ],
        ),
      ),
    ),
  );
}
