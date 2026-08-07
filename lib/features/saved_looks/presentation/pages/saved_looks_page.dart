import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/look_card.dart';
import '../../../../shared/widgets/app_ui.dart';

class SavedLooksPage extends StatelessWidget {
  const SavedLooksPage({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    index: 1,
    child: SafeArea(
      child: PageFrame(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Text(
                'Saved looks',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
            const SliverToBoxAdapter(
              child: Text('Your personal edit, ready whenever you are.'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: .72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildListDelegate.fixed(const [
                LookCard(title: 'Soft Glam', date: 'Today'),
                LookCard(title: 'Clean Girl', date: 'Monday'),
                LookCard(title: 'Date Night', date: 'Aug 1'),
                LookCard(title: 'Natural', date: 'Jul 28'),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}
