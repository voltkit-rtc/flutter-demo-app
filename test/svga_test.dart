import 'dart:io';

import 'package:flutter_svga/flutter_svga.dart';
import 'package:flutter_test/flutter_test.dart';

// The backend's own gift files, read by the player this app uses. Their format is SVGA 2.0, written by tools/art.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final files = Directory('test/fixtures').listSync().whereType<File>().where((f) => f.path.endsWith('.svga')).toList();

  test('there are gift files to check', () => expect(files, isNotEmpty));

  for (final file in files) {
    testWidgets('plays ${file.uri.pathSegments.last}', (tester) async {
      await tester.runAsync(() async {
        final movie = await SVGAParser.shared.decodeFromBuffer(file.readAsBytesSync());
        expect(movie.params.frames, greaterThan(0));
        expect(movie.params.viewBoxWidth, greaterThan(0));
        expect(movie.sprites, isNotEmpty);
        movie.dispose();
      });
    });
  }
}
