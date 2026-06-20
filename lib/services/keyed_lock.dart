import 'dart:async';

/// A dependency-free async mutex keyed by string. Calls to [synchronized] for
/// the same [key] run **one at a time, in arrival order**; different keys never
/// block each other.
///
/// This exists to make a SharedPreferences read-modify-write atomic against
/// itself: loading a JSON blob, mutating it, and writing it back is not atomic,
/// so two concurrent writers to the same key can silently drop one update (the
/// second read happens before the first write lands). Wrapping each such
/// critical section in `synchronized(key, ...)` serialises them.
///
/// Implementation: a per-key tail future that each caller chains onto, then
/// installs itself as the new tail. The tail futures only ever complete
/// **normally** (errors from [action] propagate to that call's caller but are
/// not carried on the chain), so a failing critical section never wedges the
/// queue.
class KeyedLock {
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<T> synchronized<T>(String key, Future<T> Function() action) async {
    final prior = _tails[key];
    final release = Completer<void>();
    _tails[key] = release.future;
    try {
      // Wait for whoever held this key before us (if anyone).
      if (prior != null) await prior;
      return await action();
    } finally {
      // If no later caller chained onto us, the key is now idle — drop it so the
      // map doesn't grow unbounded across many one-off keys.
      if (identical(_tails[key], release.future)) _tails.remove(key);
      release.complete();
    }
  }
}

/// Process-wide lock shared by every persistence read-modify-write, keyed by the
/// SharedPreferences key it guards. Top-level (not per-instance) so the app's
/// many ad-hoc `Service()` constructions all serialise against the same lock.
final KeyedLock prefsWriteLock = KeyedLock();
