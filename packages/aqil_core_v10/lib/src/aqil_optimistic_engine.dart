import 'dart:async';
import 'package:flutter/foundation.dart';
import 'aqil_haptic_choreographer.dart';

/// Status of an optimistic mutation.
enum AqilMutationStatus {
  idle,
  optimistic,
  committed,
  rolledBack,
}

/// Represents an optimistic transaction with rollback capability.
class AqilOptimisticTransaction<T> {
  final String id;
  final T previousState;
  final T optimisticState;
  final Future<void> Function() remoteOperation;
  final void Function(T rolledBackState)? onRollback;

  AqilOptimisticTransaction({
    required this.id,
    required this.previousState,
    required this.optimisticState,
    required this.remoteOperation,
    this.onRollback,
  });
}

/// Autonomous Offline-First Optimistic UI Store.
/// Applies local mutations immediately for zero perceived latency (Linear / Superhuman standard),
/// triggers tactile haptics, and autonomously rolls back to previous state if network fails.
class AqilOptimisticStore<T> extends ValueNotifier<T> {
  AqilMutationStatus _status = AqilMutationStatus.idle;
  AqilMutationStatus get status => _status;

  final List<AqilOptimisticTransaction<T>> _transactionQueue = [];

  AqilOptimisticStore(super.initialState);

  /// Executes an optimistic mutation immediately.
  /// If [remoteCall] succeeds, commits the state.
  /// If [remoteCall] throws, automatically restores previous state and executes rollback callback.
  Future<bool> mutateOptimistically({
    required String mutationId,
    required T Function(T current) applyOptimisticChange,
    required Future<void> Function() remoteCall,
    void Function(T restoredState)? onRollback,
  }) async {
    final previous = value;
    final optimistic = applyOptimisticChange(previous);

    // 1. Instant local mutation (zero UI latency)
    value = optimistic;
    _status = AqilMutationStatus.optimistic;
    notifyListeners();

    // 2. Tactile micro-haptic confirmation
    await AqilHapticChoreographer.tap();

    final tx = AqilOptimisticTransaction<T>(
      id: mutationId,
      previousState: previous,
      optimisticState: optimistic,
      remoteOperation: remoteCall,
      onRollback: onRollback,
    );
    _transactionQueue.add(tx);

    try {
      // 3. Background remote call
      await remoteCall();
      _status = AqilMutationStatus.committed;
      _transactionQueue.remove(tx);
      notifyListeners();
      return true;
    } catch (error) {
      // 4. Automatic rollback upon failure
      value = previous;
      _status = AqilMutationStatus.rolledBack;
      _transactionQueue.remove(tx);
      onRollback?.call(previous);
      notifyListeners();

      // Tactile error alert
      await AqilHapticChoreographer.error();
      return false;
    }
  }
}
