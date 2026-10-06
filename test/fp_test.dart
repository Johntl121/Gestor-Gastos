import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets('Test file picker mock', (tester) async {
    const MethodChannel filePickerChannel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      filePickerChannel,
      (MethodCall methodCall) async {
        return [
          {
            'path': '/fake/path/backup.gestorbackup',
            'name': 'backup.gestorbackup',
            'size': 100,
            'bytes': null,
          }
        ];
      },
    );

    final result = await FilePicker.pickFiles(type: FileType.any);
    print('RESULT 1 = $result');
  });
}