import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_ui.dart';

/// Shown when the analysis or style this palette belongs to is gone, as it is
/// after the process dies: all three are held in memory together.
class CustomPaletteNotReadyState extends StatelessWidget {
  const CustomPaletteNotReadyState({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: FaceTuneTopBar(title: title),
    body: SafeArea(
      child: PageFrame(
        child: Center(
          child: StatusState(
            title: 'Your scan is not ready',
            message: 'Complete your analysis and choose a makeup style first.',
            icon: Icons.info_outline_rounded,
            actionLabel: 'Choose a style',
            onAction: () => context.go(AppConstants.stylesRoute),
          ),
        ),
      ),
    ),
  );
}
