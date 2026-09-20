import 'package:flutter_test/flutter_test.dart';
import 'package:musteri/main.dart';
import 'package:musteri/session.dart';

void main() {
  testWidgets('Müşteri giriş ekranı', (tester) async {
    final session = CustomerSession();
    session.restoring = false;
    await tester.pumpWidget(CustomerApp(session: session));
    expect(find.text('Giriş yap'), findsOneWidget);
  });
}
