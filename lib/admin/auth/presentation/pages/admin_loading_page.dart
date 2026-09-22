import 'package:flutter/material.dart';

/// Shown while the server has not yet answered for the current session.
///
/// Deliberately renders nothing about the account: no email, no role, no
/// data. The authorization decision has not been made.
class AdminLoadingPage extends StatelessWidget {
  const AdminLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(semanticsLabel: 'Checking authorization'),
            SizedBox(height: 16),
            Text('Checking authorization…'),
          ],
        ),
      ),
    );
  }
}
