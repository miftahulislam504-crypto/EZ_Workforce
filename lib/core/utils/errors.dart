import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts backend and network errors into short, readable messages.
String friendlyError(Object error) {
  if (error is AuthException) {
    final message = error.message;
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email address first. Check your inbox.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('password') && lower.contains('characters')) {
      return message;
    }
    return message;
  }

  if (error is PostgrestException) {
    final message = error.message;
    final details = '${error.details ?? ''} $message'.toLowerCase();
    if (error.code == '23505') {
      if (details.contains('uq_branches')) {
        return 'A branch with this name or code already exists.';
      }
      if (details.contains('uq_departments')) {
        return 'A department with this name or code already exists.';
      }
      if (details.contains('uq_designations')) {
        return 'A designation with this title already exists.';
      }
      if (details.contains('uq_roles')) {
        return 'A role with this name already exists.';
      }
      if (details.contains('uq_employees_org_email')) {
        return 'An employee with this work email already exists.';
      }
      if (details.contains('uq_employees_org_code')) {
        return 'This employee ID is already in use.';
      }
      return 'This value already exists. Please use a different one.';
    }
    if (error.code == '42501' ||
        message.toLowerCase().contains('row-level security')) {
      return 'You do not have permission to do that.';
    }
    if (error.code == '23503' &&
        !message.toLowerCase().contains('does not belong')) {
      return 'This record is still in use and cannot be removed.';
    }
    // Messages raised by our own database rules are written for people.
    return message;
  }

  if (error is StorageException) {
    return 'File upload failed: ${error.message}';
  }

  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException') ||
      text.contains('XMLHttpRequest')) {
    return 'No connection. Check your internet and try again.';
  }
  return 'Something went wrong. Please try again.';
}
