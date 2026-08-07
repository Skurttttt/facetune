import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../shared/widgets/look_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    index: 0,
    child: SafeArea(
      child: PageFrame(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning, Mia',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'What beauty mood are you in?',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.taupe),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => context.push(AppConstants.settingsRoute),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(child: _ScanHero()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Recent looks',
                action: 'View all',
                onAction: () => context.go(AppConstants.historyRoute),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 232,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    LookCard(title: 'Soft Glam', date: 'Today'),
                    SizedBox(width: 12),
                    LookCard(title: 'Clean Girl', date: 'Mon'),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            const SliverToBoxAdapter(child: SectionHeader('Picked for you')),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            SliverToBoxAdapter(
              child: AppCard(
                color: AppColors.petal,
                child: Row(
                  children: [
                    const Icon(
                      Icons.wb_sunny_outlined,
                      color: AppColors.gold,
                      size: 32,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Warm tones will glow on you',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Try peach blush with a soft cocoa liner.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScanHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.roseDark, AppColors.rose],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      boxShadow: [
        BoxShadow(
          color: AppColors.rose.withValues(alpha: .24),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.face_retouching_natural_rounded,
          color: Colors.white,
          size: AppIconSizes.hero,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Discover your\nsignature look',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'A personalized beauty analysis in a few simple steps.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.roseDark,
          ),
          onPressed: () => context.push(AppConstants.scanRoute),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Start Scan'),
        ),
      ],
    ),
  );
}
