import '../helpers/data_isolation_suite.dart';
import '../helpers/test_stores.dart';

void main() {
  runDataIsolationSuite('Web storage', createPrefsTestStore);
}