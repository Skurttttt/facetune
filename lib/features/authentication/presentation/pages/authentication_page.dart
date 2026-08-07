import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_ui.dart';

class AuthenticationPage extends StatelessWidget {
  const AuthenticationPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageFrame(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.rose),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'FaceTune',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const BeautyImage(height: 300),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Meet the look\nmade for you.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Personalized makeup inspiration, guided by your unique features.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.taupe),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Continue with email',
                icon: Icons.mail_outline_rounded,
                onPressed: () => context.go(AppConstants.homeRoute),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                onPressed: () => context.go(AppConstants.homeRoute),
              ),
              TextButton(
                onPressed: () => context.go(AppConstants.homeRoute),
                child: const Text('Explore as a guest'),
              ),
              Text(
                'Static preview â€” no account data is collected.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
