import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/user_account.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../firebase/firebase_providers.dart';
import '../../../firebase/firebase_runtime_config.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreatingAccount = false;
  bool _isWorking = false;
  String? _message;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate(AuthRepository repository) async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    await _runAction(() async {
      if (_isCreatingAccount) {
        await repository.createAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        _message = 'Hesabın oluşturuldu. Öğrenci doğrulaması isteğe bağlıdır.';
      } else {
        await repository.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        _message = 'Giriş yapıldı.';
      }
    });
  }

  Future<void> _requestStudentVerification(AuthRepository repository) async {
    await _runAction(() async {
      await repository.requestStudentEmailVerification();
      _message = 'Doğrulama bağlantısı e-posta adresine gönderildi.';
    });
  }

  Future<void> _refreshStudentVerification(AuthRepository repository) async {
    await _runAction(() async {
      final verified = await repository.refreshStudentVerification();
      _message = verified
          ? 'Öğrenci e-postası doğrulandı.'
          : 'E-postadaki bağlantıyı açtıktan sonra tekrar kontrol et.';
    });
  }

  Future<void> _signOut(AuthRepository repository) async {
    await _runAction(() async {
      await repository.signOut();
      _message = 'Çıkış yapıldı.';
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _isWorking = true;
      _errorMessage = null;
      _message = null;
    });
    try {
      await action();
    } on FirebaseConfigurationException catch (error) {
      _errorMessage = error.toString();
    } on AuthenticationRequiredException catch (error) {
      _errorMessage = error.toString();
    } on StudentEmailNotEligibleException catch (error) {
      _errorMessage = error.toString();
    } on FirebaseException catch (error) {
      _errorMessage = error.message ?? error.code;
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Widget _buildAccountState(AuthRepository repository, UserAccount? account) {
    if (account == null) {
      return _buildAuthenticationForm(repository);
    }

    final validator = ref.watch(studentEmailDomainValidatorProvider);
    final isEligible = validator.isEligible(account.email ?? '');
    final hasVerifiedStudentBadge = account.emailVerified && isEligible;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(account.email ?? account.id),
        const SizedBox(height: 8),
        Text(
          hasVerifiedStudentBadge
              ? 'Doğrulanmış öğrenci rozeti'
              : 'Öğrenci rozeti isteğe bağlıdır.',
        ),
        if (isEligible && !account.emailVerified) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isWorking
                ? null
                : () => _requestStudentVerification(repository),
            child: const Text('Öğrenci e-postasını doğrula'),
          ),
          OutlinedButton(
            onPressed: _isWorking
                ? null
                : () => _refreshStudentVerification(repository),
            child: const Text('Doğrulamayı yenile'),
          ),
        ] else if (!isEligible) ...[
          const SizedBox(height: 8),
          const Text(
            'Bu e-posta alan adı öğrenci doğrulaması için yapılandırılmamış. '
            'Uygulamanın diğer özellikleri herkese açıktır.',
          ),
        ],
        if (_isWorking) const LinearProgressIndicator(),
        if (_message case final message?) ...[
          const SizedBox(height: 12),
          Text(message),
        ],
        if (_errorMessage case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: _isWorking ? null : () => _signOut(repository),
          child: const Text('Çıkış yap'),
        ),
      ],
    );
  }

  Widget _buildAuthenticationForm(AuthRepository repository) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _isCreatingAccount ? 'Hesap oluştur' : 'Giriş yap',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'E-posta',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'E-posta adresini gir.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: 'Şifre',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Şifreni gir.' : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isWorking ? null : () => _authenticate(repository),
            child: Text(_isCreatingAccount ? 'Hesap oluştur' : 'Giriş yap'),
          ),
          TextButton(
            onPressed: _isWorking
                ? null
                : () => setState(() {
                    _isCreatingAccount = !_isCreatingAccount;
                    _message = null;
                    _errorMessage = null;
                  }),
            child: Text(
              _isCreatingAccount
                  ? 'Zaten hesabın var mı? Giriş yap'
                  : 'Hesabın yok mu? Oluştur',
            ),
          ),
          if (_isWorking) const LinearProgressIndicator(),
          if (_message case final message?) ...[
            const SizedBox(height: 12),
            Text(message),
          ],
          if (_errorMessage case final message?) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(authRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap')),
      body: repository.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Hesap hizmeti kullanılamıyor: $error'),
          ),
        ),
        data: (authRepository) => StreamBuilder<UserAccount?>(
          stream: authRepository.watchUser(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Hesap durumu okunamadı: ${snapshot.error}'),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildAccountState(authRepository, snapshot.data);
          },
        ),
      ),
    );
  }
}
