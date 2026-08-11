import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/errors/auth_failure.dart';

abstract final class AuthErrorMapper {
  static AuthFailure map(Object error) {
    if (error is AuthFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return const AuthFailure(
        'That request is taking too long. Check your connection and try again.',
      );
    }
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return const AuthFailure('Email or password is incorrect.');
      }
      if (message.contains('email not confirmed')) {
        return const AuthFailure('Confirm your email before signing in.');
      }
      if (message.contains('user already registered')) {
        return const AuthFailure('An account already exists for this email.');
      }
      if (message.contains('password')) {
        return const AuthFailure(
          'That password cannot be used. Try a stronger password.',
        );
      }
      if (message.contains('rate') || message.contains('too many')) {
        return const AuthFailure(
          'Too many attempts. Please wait a moment and try again.',
        );
      }
      if (message.contains('anonymous') || message.contains('provider')) {
        return const AuthFailure('This sign-in method is not enabled yet.');
      }
      if (message.contains('network') || message.contains('socket')) {
        return const AuthFailure(
          'Check your internet connection and try again.',
        );
      }
      return const AuthFailure(
        'We could not complete that sign-in request. Please try again.',
      );
    }
    return const AuthFailure(
      'Something went wrong. Please check your connection and try again.',
    );
  }
}
