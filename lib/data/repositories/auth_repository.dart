import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/json_utils.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Creates the account and, through a database trigger, the organization.
  Future<AuthResponse> registerOrganization({
    required String email,
    required String password,
    required String fullName,
    required String organizationName,
    String? businessType,
    String? country,
    String? phone,
    String? timezone,
    String? currency,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'registration_type': 'organization',
        'full_name': fullName.trim(),
        'org_name': organizationName.trim(),
        if (businessType != null) 'business_type': businessType,
        if (country != null) 'country': country,
        if (phone != null) 'phone': phone,
        if (timezone != null) 'timezone': timezone,
        if (currency != null) 'currency': currency,
      },
    );
  }

  /// Creates an account that will be linked to an invited employee record.
  Future<AuthResponse> registerWithInvite({
    required String email,
    required String password,
    required String inviteCode,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'invite_code': inviteCode.trim().toUpperCase()},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? Uri.base.origin : null,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  /// Invite code stored in the sign-up metadata, used when e-mail
  /// confirmation delayed the first login.
  String? get pendingInviteCode {
    final value = _client.auth.currentUser?.userMetadata?['invite_code'];
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<Json?> loadContext() async {
    final result = await _client.rpc('current_context');
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  Future<void> claimInvite(String code) async {
    await _client.rpc('claim_invite', params: {'p_code': code.trim()});
  }
}
