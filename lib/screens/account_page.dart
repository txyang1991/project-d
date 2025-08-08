import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isSignedIn = user != null && !user.isAnonymous;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSignedIn
                    ? 'Signed in as: ${user.email ?? user.displayName ?? user.uid}'
                    : (user?.isAnonymous ?? false)
                        ? 'Guest User'
                        : 'Not signed in',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              if (user == null) ...[
                CustomButton(
                  text: 'Continue as Guest',
                  onPressed: () async => await AuthService.signInAnonymously(),
                ),
                const SizedBox(height: 12),
                if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)
                  ElevatedButton.icon(
                    onPressed: () async => await AuthService.signInWithGoogle(),
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
              ],

              if (user != null) ...[
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Sign Out',
                  onPressed: () async => await AuthService.signOut(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
