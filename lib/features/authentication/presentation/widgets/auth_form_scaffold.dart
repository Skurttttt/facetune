import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import 'brand_mark.dart';

/// The common frame for every auth form.
///
/// One frame for sign-in, registration, and both password screens, so the four
/// read as one flow rather than four pages that happen to have fields on them.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: PageFrame(
        child: ListView(
          children: [
            const Center(child: BrandMark(size: BrandMarkSize.compact)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.muted(context)),
            ),
            const SizedBox(height: AppSpacing.xl),
            child,
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    ),
  );
}
