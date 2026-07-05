import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_bloc.dart';
import 'package:vybin/features/auth/bloc/auth_event.dart';
import 'package:vybin/features/auth/bloc/auth_state.dart';
import 'package:vybin/shared/theme/vybin_theme.dart';

class IdentityImportScreen extends StatefulWidget {
  const IdentityImportScreen({super.key});

  @override
  State<IdentityImportScreen> createState() => _IdentityImportScreenState();
}

class _IdentityImportScreenState extends State<IdentityImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _blobController = TextEditingController();
  bool _obscureBlob = true;

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            IdentityImportSubmitted(
              identityBlob: _blobController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: VybinTheme.darkCharcoal,
      appBar: AppBar(
        title: const Text('Restore Identity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.errorMessage)),
                  ],
                ),
                backgroundColor: VybinTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else if (state is AuthNetworkError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.errorMessage)),
                  ],
                ),
                backgroundColor: VybinTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.cloud_sync_outlined,
                        color: VybinTheme.whatsappGreen,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Restore Chat History',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.bold,
                      ) ?? const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Zero-Server-Escrow E2EE Warning Card
                    Card(
                      color: Colors.amber.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.amber, width: 1),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                                SizedBox(width: 8),
                                Text(
                                  'ZERO-SERVER-ESCROW ARCHITECTURE',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              'VYBIN uses zero-server-escrow end-to-end encryption. Your private key never touches our servers. To restore your messages on this device, you must manually import your identity.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Monospace text area instruction
                    const Text(
                      'Paste your exported Cryptographic Identity Blob here to restore your chat history.',
                      style: TextStyle(
                        color: VybinTheme.secondaryText,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Encrypted Key Input Block
                    TextFormField(
                      controller: _blobController,
                      obscureText: _obscureBlob,
                      maxLines: _obscureBlob ? 1 : 6,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. U2FsdGVkX19...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        fillColor: VybinTheme.inputCharcoal,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: VybinTheme.dividerCharcoal),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: VybinTheme.whatsappTeal),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureBlob ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureBlob = !_obscureBlob;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Cryptographic Identity Blob is required';
                        }
                        if (value.trim().length < 50) {
                          return 'Invalid Identity Blob length';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VybinTheme.whatsappTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Restore Chat History',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: VybinTheme.errorColor,
                      ),
                      onPressed: isLoading
                          ? null
                          : () {
                              context.read<AuthBloc>().add(LogoutRequested());
                            },
                      child: const Text('Cancel / Log Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
