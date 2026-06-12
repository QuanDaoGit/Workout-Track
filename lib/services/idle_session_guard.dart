/// Process-wide guard that makes idle-session auto-save handling idempotent.
///
/// Two surfaces can detect the same timed-out session at nearly the same moment
/// — `ActiveWorkoutPage` (its foreground timer and its resume check) when the
/// workout page is still on top, and `RootPage` (its open/resume hooks) when the
/// app was killed and relaunched. Each claims the session id before showing the
/// reveal and releases it after the user acts, so the reveal and its single
/// commit can never double-fire.
class IdleSessionGuard {
  IdleSessionGuard._();

  static final IdleSessionGuard instance = IdleSessionGuard._();

  String? _handlingSessionId;

  /// True while any session's idle reveal is in flight.
  bool get isHandling => _handlingSessionId != null;

  /// Claim [sessionId] for handling. Returns false if another claim is active
  /// (including a different session) so callers stand down.
  bool claim(String sessionId) {
    if (_handlingSessionId != null) return false;
    _handlingSessionId = sessionId;
    return true;
  }

  /// Release [sessionId] once the user has acted. No-op if a different id holds
  /// the claim.
  void release(String sessionId) {
    if (_handlingSessionId == sessionId) _handlingSessionId = null;
  }
}
