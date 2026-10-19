import '../core/security/password_hasher.dart';
import '../data/database/data_store.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/avatar_storage_service.dart';
import '../services/gemini_service.dart';
import '../services/receipt_storage_service.dart';

class AppDependencies {
  AppDependencies._({
    required this.store,
    required this.settings,
    required this.accounts,
    required this.expenses,
    required this.budgets,
    required this.receiptStorage,
    required this.avatarStorage,
    required this.analyzer,
  });

  factory AppDependencies.create({
    required DataStore store,
    SpendingAnalyzer? analyzer,
    PasswordHasher? hasher,
    ReceiptStorageService? receiptStorage,
    AvatarStorageService? avatarStorage,
  }) {
    final settings = SettingsRepository(store);

    return AppDependencies._(
      store: store,
      settings: settings,
      accounts: AccountRepository(
        store,
        settings,
        hasher ?? const PasswordHasher(),
      ),
      expenses: ExpenseRepository(store, settings),
      budgets: BudgetRepository(store),
      receiptStorage: receiptStorage ?? ReceiptStorageService(),
      avatarStorage: avatarStorage ?? AvatarStorageService(),
      analyzer: analyzer ?? GeminiService(),
    );
  }

  final DataStore store;
  final SettingsRepository settings;
  final AccountRepository accounts;
  final ExpenseRepository expenses;
  final BudgetRepository budgets;
  final ReceiptStorageService receiptStorage;
  final AvatarStorageService avatarStorage;
  final SpendingAnalyzer analyzer;
}