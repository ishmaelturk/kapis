import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import '../domain/repositories/auth_repository.dart';
import '../domain/services/pickup_proximity_service.dart';
import '../firebase/firebase_runtime_config.dart';

String userMessageFor(Object error) {
  if (error is FirebaseConfigurationException) {
    return 'Firebase ayarları tamamlanmamış. Uygulama yöneticisi '
        'firebase.local.json dosyasını yapılandırmalı.';
  }
  if (error is AuthenticationRequiredException) {
    return 'Bu işlem için hesabına giriş yap.';
  }
  if (error is StudentEmailNotEligibleException) {
    return 'Bu e-posta alan adı öğrenci doğrulaması için uygun değil.';
  }
  if (error is PickupLocationAccessException) {
    return error.message;
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'E-posta adresini kontrol et.',
      'user-disabled' => 'Bu hesap kullanıma kapatılmış.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'E-posta veya şifre hatalı.',
      'requires-recent-login' =>
        'Güvenlik için çıkış yapıp yeniden giriş yaptıktan sonra hesabını sil.',
      'email-already-in-use' => 'Bu e-posta adresi zaten kullanılıyor.',
      'weak-password' => 'Daha güçlü bir şifre belirle.',
      'too-many-requests' =>
        'Çok fazla deneme yapıldı. Daha sonra tekrar dene.',
      'network-request-failed' => 'Bağlantını kontrol edip tekrar dene.',
      'operation-not-allowed' => 'Bu giriş yöntemi şu anda kullanılamıyor.',
      _ => 'Hesap işlemi tamamlanamadı. Bilgilerini kontrol edip tekrar dene.',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' || 'unauthenticated' =>
        'Bu işlem için yetkin yok. Hesabını ve erişim iznini kontrol et.',
      'unavailable' || 'network-request-failed' =>
        'Bağlantı kurulamadı. İnternet bağlantını kontrol edip tekrar dene.',
      'not-found' => 'İstenen kayıt bulunamadı.',
      'resource-exhausted' => 'Hizmet şu anda yoğun. Daha sonra tekrar dene.',
      _ => 'İşlem tamamlanamadı. Daha sonra tekrar dene.',
    };
  }
  if (error is TimeoutException || error is SocketException) {
    return 'İstek zaman aşımına uğradı. Bağlantını kontrol edip tekrar dene.';
  }
  if (error is ArgumentError || error is FormatException) {
    return 'Girilen bilgileri kontrol et.';
  }
  if (error is StateError) {
    return 'İşlem şu anda tamamlanamıyor. Sayfayı yenileyip tekrar dene.';
  }
  if (error is UnsupportedError) {
    return 'Bu özellik bu platformda kullanılamıyor.';
  }
  return 'Beklenmeyen bir sorun oluştu. Daha sonra tekrar dene.';
}
