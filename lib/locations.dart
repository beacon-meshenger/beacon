import 'package:geolocator/geolocator.dart';

Future<Position> getCurrentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.deniedForever) return null;
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) return null;
  }
  return await Geolocator.getCurrentPosition();
}
