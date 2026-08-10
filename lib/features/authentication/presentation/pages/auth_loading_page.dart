import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';

class AuthLoadingPage extends StatelessWidget {
  const AuthLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(child: LoadingState(label: 'Restoring your session…')),
      ),
    );
  }
}
