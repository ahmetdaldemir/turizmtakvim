import 'package:flutter_test/flutter_test.dart';
import 'package:turizmtakvim/main.dart';
import 'package:turizmtakvim/models/session.dart';

void main() {
  testWidgets('Yönetim giriş ekranı görünür', (tester) async {
    final session = SessionController();
    session.restoring = false;
    await tester.pumpWidget(AdminApp(session: session));
    expect(find.text('Yönetim'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
  });
}
