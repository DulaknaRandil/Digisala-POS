import 'package:permission_handler/permission_handler.dart';

Future<bool> _requestStoragePermission() async {
  final status = await Permission.storage.request();
  return status.isGranted;
}
