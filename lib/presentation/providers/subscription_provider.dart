import 'package:flutter/material.dart';
import '../../data/models/subscription.dart';
import '../../core/errors/failure.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../core/services/notification_coordinator.dart';

import '../../domain/usecases/subscriptions/refresh_subscription_cycles_usecase.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionRepository subscriptionRepository;
  final NotificationCoordinator notificationCoordinator;
  final RefreshSubscriptionCyclesUseCase refreshSubscriptionCyclesUseCase;

  SubscriptionProvider({
    required this.subscriptionRepository,
    required this.notificationCoordinator,
    required this.refreshSubscriptionCyclesUseCase,
  }) {
    loadSubscriptions();
  }

  List<Subscription> _subscriptions = [];
  bool _isLoading = false;
  String? errorMessage;

  List<Subscription> get subscriptions => _subscriptions;
  bool get isLoading => _isLoading;

  Future<void> loadSubscriptions() async {
    _isLoading = true;
    notifyListeners();

    final result = await refreshSubscriptionCyclesUseCase(
        RefreshSubscriptionCyclesParams(now: DateTime.now()));

    result.fold(
      (Failure failure) {
        errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
      },
      (subs) {
        _subscriptions = subs;
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> addSubscription(Subscription subscription) async {
    final idx = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (idx != -1) {
      _subscriptions[idx] = subscription;
      await subscriptionRepository.saveSubscription(subscription);
    } else {
      final subWithOrder =
          subscription.copyWith(orderIndex: _subscriptions.length);
      _subscriptions.add(subWithOrder);
      await subscriptionRepository.saveSubscription(subWithOrder);
    }
    notifyListeners();

    await notificationCoordinator.scheduleSubscription(subscription);
  }

  Future<void> removeSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    notifyListeners();
    await subscriptionRepository.deleteSubscription(id);
    await notificationCoordinator.cancelSubscription(id);
  }



  void reorderSubscriptions(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _subscriptions.removeAt(oldIndex);
    _subscriptions.insert(newIndex, item);

    for (int i = 0; i < _subscriptions.length; i++) {
      _subscriptions[i] = _subscriptions[i].copyWith(orderIndex: i);
      subscriptionRepository.saveSubscription(_subscriptions[i]);
    }

    notifyListeners();
  }
}
