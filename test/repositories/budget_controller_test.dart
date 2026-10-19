import 'package:expense_tracker/core/constants/app_constants.dart';
import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/repositories/budget_repository.dart';
import 'package:expense_tracker/features/budget/providers/budget_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BudgetRepository repository;
  late DateTime clockNow;
  late BudgetController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = BudgetRepository(PrefsDataStore());
    clockNow = DateTime(2026, 10, 18);
    controller = BudgetController(repository, clock: () => clockNow);
  });

  tearDown(() {
    controller.dispose();
  });

  Future<void> bind(int? userId) async {
    controller.bindUser(userId);
    await pumpEventQueue();
  }

  test('chưa đặt: dùng ngân sách mặc định', () async {
    await bind(1);

    expect(controller.isLoaded, isTrue);
    expect(controller.amount, kDefaultMonthlyBudget);
  });

  test('đặt ngân sách rồi tải lại bằng controller mới vẫn còn', () async {
    await bind(1);

    expect(await controller.setAmount(5000000), isNull);
    expect(controller.amount, 5000000);

    final another = BudgetController(repository, clock: () => clockNow);
    addTearDown(another.dispose);

    another.bindUser(1);
    await pumpEventQueue();

    expect(another.amount, 5000000);
  });

  test('mỗi tài khoản có ngân sách riêng', () async {
    await bind(1);
    await controller.setAmount(5000000);

    await bind(2);

    expect(controller.amount, kDefaultMonthlyBudget);

    await controller.setAmount(3000000);
    await bind(1);

    expect(controller.amount, 5000000);
  });

  test('giá trị không hợp lệ bị từ chối và không đổi dữ liệu', () async {
    await bind(1);
    await controller.setAmount(5000000);

    expect(await controller.setAmount(0), isNotNull);
    expect(await controller.setAmount(-10), isNotNull);
    expect(await controller.setAmount(double.nan), isNotNull);
    expect(await controller.setAmount(kMaxMoneyAmount + 1), isNotNull);

    expect(controller.amount, 5000000);
  });

  test('chưa đăng nhập: không đặt được ngân sách', () async {
    await bind(null);

    expect(await controller.setAmount(1000000), isNotNull);
  });

  test('tháng mới kế thừa ngân sách của tháng gần nhất trước đó', () async {
    await bind(1);
    await controller.setAmount(6000000); // Tháng 10.

    clockNow = DateTime(2026, 11, 2);
    await controller.load();

    expect(controller.amount, 6000000);

    // Đặt riêng cho tháng 11 không làm đổi tháng 10.
    await controller.setAmount(7000000);

    clockNow = DateTime(2026, 10, 20);
    await controller.load();

    expect(controller.amount, 6000000);
  });

  test('đổi tài khoản khi đang tải: bỏ kết quả của tài khoản cũ', () async {
    await bind(1);
    await controller.setAmount(5000000);

    controller.bindUser(2);
    controller.bindUser(1);
    await pumpEventQueue();

    expect(controller.amount, 5000000);
  });
}