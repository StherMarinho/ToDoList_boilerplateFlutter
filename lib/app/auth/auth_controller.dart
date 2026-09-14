import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/data/user_profile_repository.dart';
import 'package:synergia_flutter_meteor_boilerplate/modules/user_profile/domain/user_profile.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/auth/meteor_auth_service.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_error_mapper.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/meteor/meteor_subscription.dart';

enum AuthStatus { bootstrapping, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.userProfile,
    this.profileLoading = false,
    this.failure,
    this.submitting = false,
  });

  const AuthState.bootstrapping() : this(status: AuthStatus.bootstrapping);
  const AuthState.unauthenticated({MeteorFailure? failure})
    : this(status: AuthStatus.unauthenticated, failure: failure);

  final AuthStatus status;
  final UserProfile? userProfile;
  final bool profileLoading;
  final MeteorFailure? failure;
  final bool submitting;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? userProfile,
    bool clearUserProfile = false,
    bool? profileLoading,
    MeteorFailure? failure,
    bool clearFailure = false,
    bool? submitting,
  }) {
    return AuthState(
      status: status ?? this.status,
      userProfile: clearUserProfile ? null : userProfile ?? this.userProfile,
      profileLoading: profileLoading ?? this.profileLoading,
      failure: clearFailure ? null : failure ?? this.failure,
      submitting: submitting ?? this.submitting,
    );
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  MeteorSubscription? _profileSubscription;
  StreamSubscription<UserProfile?>? _profileListener;
  StreamSubscription<bool>? _profileReadyListener;
  StreamSubscription<Object>? _profileErrorListener;
  String? _activeUserId;
  bool _profileReady = false;
  bool _remoteProfileReceived = false;
  bool _invalidatingProfile = false;

  MeteorAuthService get _authService => ref.read(meteorAuthServiceProvider);
  UserProfileRepository get _profileRepository =>
      ref.read(userProfileRepositoryProvider);

  @override
  AuthState build() {
    ref.onDispose(_disposeProfile);
    Future<void>.microtask(_restore);
    return const AuthState.bootstrapping();
  }

  Future<void> _restore() async {
    try {
      final session = await _authService.restoreSession();
      if (session == null) {
        state = const AuthState.unauthenticated();
        return;
      }
      _activate(session);
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(submitting: true, clearFailure: true);
    try {
      final session = await _authService.loginWithPassword(
        email: email,
        password: password,
      );
      _activate(session);
      return true;
    } catch (error) {
      state = AuthState.unauthenticated(failure: MeteorErrorMapper.map(error));
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(submitting: true, clearFailure: true);
    await _authService.logout();
    await _profileRepository.clearCache();
    _disposeProfile();
    state = const AuthState.unauthenticated();
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);

  void _activate(MeteorAuthSession session) {
    _disposeProfile();
    _activeUserId = session.userId;
    state = AuthState(
      status: AuthStatus.authenticated,
      userProfile: UserProfile.placeholder(session.userId),
      profileLoading: true,
    );

    Future<void>.microtask(() => _restoreCachedProfile(session.userId));
    _profileSubscription = _profileRepository.subscribeCurrent();
    _profileListener = _profileRepository
        .observeCurrent(session.userId)
        .listen(
          (profile) {
            if (_activeUserId != session.userId) return;
            if (profile == null || profile.isDisabled) {
              if (_profileReady) {
                unawaited(_invalidateProfile(session.userId));
              }
              return;
            }
            _acceptRemoteProfile(session.userId, profile);
          },
          onError: (Object error, StackTrace _) {
            unawaited(
              _invalidateProfile(
                session.userId,
                failure: MeteorErrorMapper.map(error),
              ),
            );
          },
        );
    _profileReadyListener = _profileSubscription!.ready
        .where((ready) => ready)
        .take(1)
        .listen((_) {
          _profileReady = true;
          if (_activeUserId != session.userId || _remoteProfileReceived) return;
          final current = _profileRepository.current(session.userId);
          if (current != null && !current.isDisabled) {
            _acceptRemoteProfile(session.userId, current);
          } else {
            unawaited(_invalidateProfile(session.userId));
          }
        });
    _profileErrorListener = _profileSubscription!.errors.listen((error) {
      unawaited(
        _invalidateProfile(
          session.userId,
          failure: MeteorErrorMapper.map(error),
        ),
      );
    });
  }

  Future<void> _restoreCachedProfile(String userId) async {
    final cached = await _profileRepository.readCached(userId);
    if (cached == null || _activeUserId != userId || !ref.mounted) return;
    // Não substitui um perfil remoto que tenha chegado enquanto o cache era
    // lido; o remoto é sempre a versão preferencial quando disponível.
    if (!state.profileLoading) return;
    state = AuthState(status: AuthStatus.authenticated, userProfile: cached);
  }

  void _acceptRemoteProfile(String userId, UserProfile profile) {
    if (_activeUserId != userId) return;
    _remoteProfileReceived = true;
    unawaited(_profileRepository.cache(userId, profile));
    state = AuthState(status: AuthStatus.authenticated, userProfile: profile);
  }

  Future<void> _invalidateProfile(
    String userId, {
    MeteorFailure? failure,
  }) async {
    if (_activeUserId != userId || _invalidatingProfile) return;
    _invalidatingProfile = true;
    final effectiveFailure =
        failure ??
        const MeteorFailure(
          message: 'Não existe um perfil ativo vinculado a esta conta.',
          kind: MeteorFailureKind.authentication,
          code: 'profile-not-found',
        );
    _disposeProfile(resetInvalidating: false);
    state = AuthState.unauthenticated(failure: effectiveFailure);
    try {
      await _profileRepository.clearCache();
    } finally {
      await _authService.logout();
    }
  }

  void _disposeProfile({bool resetInvalidating = true}) {
    _activeUserId = null;
    _profileListener?.cancel();
    _profileListener = null;
    _profileReadyListener?.cancel();
    _profileReadyListener = null;
    _profileErrorListener?.cancel();
    _profileErrorListener = null;
    _profileSubscription?.stop();
    _profileSubscription = null;
    _profileReady = false;
    _remoteProfileReceived = false;
    if (resetInvalidating) _invalidatingProfile = false;
  }
}
