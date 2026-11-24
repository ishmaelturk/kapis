import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../application/user_error_message.dart';
import '../../../domain/models/listing.dart';
import '../../../domain/models/user_account.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../firebase/firebase_providers.dart';
import '../../../firebase/firebase_runtime_config.dart';
import '../../legal/presentation/legal_information_screen.dart';

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

  Future<void> _sendPasswordReset(AuthRepository repository) async {
    final validation = _validateEmail(_emailController.text);
    if (validation != null) {
      setState(() => _errorMessage = validation);
      return;
    }
    await _runAction(() async {
      await repository.sendPasswordResetEmail(_emailController.text.trim());
      _message = 'Şifre yenileme bağlantısı e-posta adresine gönderildi.';
    });
  }

  Future<void> _deleteAccount(AuthRepository authRepository) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabın silinsin mi?'),
        content: const Text(
          'Bağış ilanların yayından kaldırılacak, ayırtmaların iptal edilecek '
          've hesabın silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hesabımı sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _runAction(() async {
      final listingRepository = await ref.read(
        listingRepositoryProvider.future,
      );
      final handoverRepository = await ref.read(
        handoverRepositoryProvider.future,
      );
      final myListings = await listingRepository.getAllMyListings();
      final myReservations = await handoverRepository
          .watchMyReservations()
          .first;

      for (final listing in myListings) {
        switch (listing.status) {
          case ListingStatus.available:
            await listingRepository.withdraw(listing.id);
          case ListingStatus.reserved:
            await handoverRepository.releaseReservation(
              listing.id,
              withdraw: true,
            );
          case ListingStatus.handedOver || ListingStatus.withdrawn:
            break;
        }
      }
      for (final listing in myReservations) {
        await handoverRepository.cancelReservation(listing.id);
      }
      await authRepository.deleteAccount();
      _message = 'Hesabın silindi.';
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
      _errorMessage = userMessageFor(error);
    } on AuthenticationRequiredException catch (error) {
      _errorMessage = userMessageFor(error);
    } on StudentEmailNotEligibleException catch (error) {
      _errorMessage = userMessageFor(error);
    } on FirebaseException catch (error) {
      _errorMessage = userMessageFor(error);
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
              ? 'Öğrenci e-postası doğrulandı. Bu rozet yalnızca sana '
                    'gösterilir; diğer kullanıcılara aktarılmaz.'
              : 'Öğrenci rozeti isteğe bağlıdır ve yalnızca hesabında görünür.',
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
        TextButton(
          onPressed: _isWorking ? null : () => _deleteAccount(repository),
          child: const Text('Hesabımı sil'),
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
                : _validateEmail(value),
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Şifreni gir.';
              }
              if (_isCreatingAccount && value.length < 8) {
                return 'Şifren en az 8 karakter olmalı.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isWorking ? null : () => _authenticate(repository),
            child: Text(_isCreatingAccount ? 'Hesap oluştur' : 'Giriş yap'),
          ),
          if (!_isCreatingAccount)
            TextButton(
              onPressed: _isWorking
                  ? null
                  : () => _sendPasswordReset(repository),
              child: const Text('Şifremi unuttum'),
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
          if (_isCreatingAccount)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LegalInformationScreen(),
                ),
              ),
              child: const Text('Gizlilik ve kullanım koşullarını oku'),
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

  String? _validateEmail(String value) {
    final email = value.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    return null;
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
            child: Text(userMessageFor(error)),
          ),
        ),
        data: (authRepository) => StreamBuilder<UserAccount?>(
          stream: authRepository.watchUser(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(userMessageFor(snapshot.error!)));
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
