import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../../theme/app_tokens.dart';

class LookCard extends StatelessWidget {
  const LookCard({required this.title, required this.date, super.key});
  final String title;
  final String date;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 168,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppConstants.previewRoute),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.asset(
                'assets/images/beauty_portrait.png',
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          date,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: AppColors.rose,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
