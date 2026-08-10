import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';

void listenForAuthFeedback(WidgetRef ref, BuildContext context) {
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (previous?.feedbackId == next.feedbackId) {
      return;
    }
    final message = next.errorMessage ?? next.notice;
    if (message == null || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  });
}
