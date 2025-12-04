import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late TextEditingController _emailController;
  late TextEditingController _nameController;
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _deletingAccount = false;

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;

    final email = user?.email ?? '';
    final fullName = (user?.userMetadata?['full_name'] as String?) ?? email;

    _emailController = TextEditingController(text: email);
    _nameController = TextEditingController(text: fullName);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  SupabaseClient get _client => Supabase.instance.client;

  /* ───────────── Helpers ───────────── */

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  /* ───────────── Update profile (name + email) ───────────── */

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _savingProfile = true);
    try {
      final email = _emailController.text.trim();
      final fullName = _nameController.text.trim();

      await _client.auth.updateUser(
        UserAttributes(email: email, data: {'full_name': fullName}),
      );

      _showSnack('Profile updated. You may need to verify your new email.');
    } catch (e) {
      _showSnack('Failed to update profile: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  /* ───────────── Change password ───────────── */

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _savingPassword = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _showSnack('No user is logged in.', error: true);
        return;
      }

      final email = user.email;
      if (email == null || email.isEmpty) {
        _showSnack('Cannot change password: missing email.', error: true);
        return;
      }

      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();

      // 1) Re-authenticate with current password
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      // 2) Update password in Supabase
      await _client.auth.updateUser(UserAttributes(password: newPassword));

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showSnack('Password updated successfully.');
    } on AuthException catch (e) {
      // Invalid current password or other auth issue
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Failed to change password: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _savingPassword = false);
      }
    }
  }

  /* ───────────── Delete account flow ───────────── */

  Future<void> _confirmDeleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final email = user.email ?? '';
    final phrase = 'I want to delete my $email account';

    final controller = TextEditingController();
    String? errorText;

    final confirmed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final isPhone = MediaQuery.sizeOf(context).width < 640;

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Delete account'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This will permanently delete your GAMOTPH account and all associated data that you own.\n\n'
                          'To confirm, please type the phrase below exactly:',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            phrase,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Confirmation phrase',
                            errorText: errorText,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () {
                        if (controller.text.trim() != phrase) {
                          setState(() {
                            errorText = 'Phrase does not match exactly.';
                          });
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
                      child: const Text('Delete account'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    await _deleteAccount();
  }

  /// Actually deletes the account using a Supabase Edge Function
  /// called "delete-user" that runs with the service role key.
  Future<void> _deleteAccount() async {
    setState(() => _deletingAccount = true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // This assumes you have an Edge Function named "delete-user"
      // which calls auth.admin.deleteUser(user_id).
      await _client.functions.invoke('delete-user', body: {'user_id': user.id});

      // After deletion, sign out locally and go to login/root.
      await _client.auth.signOut();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } on AuthException catch (e) {
      _showSnack('Failed to delete account: ${e.message}', error: true);
    } catch (e) {
      _showSnack('Failed to delete account: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
    }
  }

  /* ───────────── UI ───────────── */

  @override
  Widget build(BuildContext context) {
    final user = _client.auth.currentUser;
    final email = user?.email ?? '';
    final fullName = (user?.userMetadata?['full_name'] as String?) ?? email;

    final isPhone = MediaQuery.sizeOf(context).width < 640;

    if (user == null) {
      return const Center(child: Text('Not logged in.'));
    }

    return Container(
      color: const Color(0xFFF9F6FF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 16 : 24,
              vertical: isPhone ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top identity row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Account info section
                        Text(
                          'Account Info',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Form(
                              key: _profileFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(Icons.mail_outline),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (val) {
                                      final v = val?.trim() ?? '';
                                      if (v.isEmpty) {
                                        return 'Email is required';
                                      }
                                      if (!v.contains('@')) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Full name',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (val) {
                                      if ((val ?? '').trim().isEmpty) {
                                        return 'Full name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed:
                                          _savingProfile ? null : _saveProfile,
                                      child:
                                          _savingProfile
                                              ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : const Text('Save changes'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Password section
                        Text(
                          'Password',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Form(
                              key: _passwordFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _currentPasswordController,
                                    obscureText: !_showCurrentPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Current password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showCurrentPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _showCurrentPassword =
                                                !_showCurrentPassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (val) {
                                      if ((val ?? '').isEmpty) {
                                        return 'Current password is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _newPasswordController,
                                    obscureText: !_showNewPassword,
                                    decoration: InputDecoration(
                                      labelText: 'New password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showNewPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _showNewPassword =
                                                !_showNewPassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (val) {
                                      final v = val ?? '';
                                      if (v.isEmpty) {
                                        return 'New password is required';
                                      }
                                      if (v.length < 6) {
                                        return 'Password should be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: !_showConfirmPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Confirm new password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showConfirmPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _showConfirmPassword =
                                                !_showConfirmPassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (val) {
                                      final v = val ?? '';
                                      if (v.isEmpty) {
                                        return 'Please confirm your new password';
                                      }
                                      if (v != _newPasswordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      onPressed:
                                          _savingPassword
                                              ? null
                                              : _changePassword,
                                      child:
                                          _savingPassword
                                              ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : const Text('Change password'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Danger zone: delete account
                        Text(
                          'Danger zone',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delete account',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This will permanently delete your account and sign you out.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.black54),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      side: BorderSide(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    onPressed:
                                        _deletingAccount
                                            ? null
                                            : _confirmDeleteAccount,
                                    icon:
                                        _deletingAccount
                                            ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : const Icon(Icons.delete_outline),
                                    label: const Text('Delete account'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
