import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _wrap(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } on Exception catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _emailPasswordFields() {
    return Column(
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pwdCtrl,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
      ],
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('OR'),
        ),
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isAnonymous = user?.isAnonymous ?? false;
        final isSignedIn = user != null && !isAnonymous;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSignedIn
                    ? 'Signed in as: ${user!.email ?? user.displayName ?? user.uid}'
                    : isAnonymous
                        ? 'Guest User'
                        : 'Not signed in',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              // --- Not signed in: show Email/Password + Google + Guest ---
              if (user == null) ...[
                _emailPasswordFields(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Sign In',
                        onPressed: () {
                          if (_busy) return;
                          _wrap(() async {
                            await AuthService.signInWithEmailPassword(
                              _emailCtrl.text.trim(),
                              _pwdCtrl.text,
                            );
                            _toast('Signed in');
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Create Account',
                        onPressed: () {
                          if (_busy) return;
                          _wrap(() async {
                            await AuthService.registerWithEmailPassword(
                              _emailCtrl.text.trim(),
                              _pwdCtrl.text,
                            );
                            _toast('Account created & signed in');
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      if (_busy) return;
                      _wrap(() async {
                        final email = _emailCtrl.text.trim();
                        if (email.isEmpty) {
                          _toast('Enter your email first.');
                          return;
                        }
                        await AuthService.sendPasswordReset(email);
                        _toast('Password reset email sent.');
                      });
                    },
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 16),
                _orDivider(),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Continue with Google',
                  onPressed: () {
                    if (_busy) return;
                    _wrap(() async {
                      await AuthService.signInWithGoogle();
                      _toast('Signed in with Google');
                    });
                  },
                ),
                const SizedBox(height: 8),
                CustomButton(
                  text: 'Continue as Guest',
                  onPressed: () {
                    if (_busy) return;
                    _wrap(() async {
                      await AuthService.signInAnonymously();
                      _toast('Signed in as guest');
                    });
                  },
                ),
              ],

              // --- Guest: allow upgrade/link + Sign Out ---
              if (isAnonymous) ...[
                const SizedBox(height: 24),
                Text(
                  'Upgrade your guest account',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _emailPasswordFields(),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Link Email & Password',
                  onPressed: () {
                    if (_busy) return;
                    _wrap(() async {
                      await AuthService.linkAnonymousWithEmailPassword(
                        _emailCtrl.text.trim(),
                        _pwdCtrl.text,
                      );
                      _toast('Guest account upgraded');
                    });
                  },
                ),
                const SizedBox(height: 8),
                CustomButton(
                  text: 'Link Google',
                  onPressed: () {
                    if (_busy) return;
                    _wrap(() async {
                      await AuthService.linkAnonymousWithGoogle();
                      _toast('Guest account linked to Google');
                    });
                  },
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Sign Out',
                  onPressed: () {
                    if (_busy) return;
                    _wrap(() async {
                      await AuthService.signOut();
                      _toast('Signed out');
                    });
                  },
                ),
              ],

              // --- Signed in (email/google/etc): only Sign Out ---
              if (isSignedIn) ...[
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Sign Out',
                  onPressed: () {
                    if (_busy) return;
                    _wrap(() async {
                      await AuthService.signOut();
                      _toast('Signed out');
                    });
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
