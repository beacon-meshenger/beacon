import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

class QRCode extends StatelessWidget {
  final String publicKey;

  QRCode({Key key, @required this.publicKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.7,
      child: QrImage(
        data: publicKey,
        version: QrVersions.auto,
        backgroundColor: Colors.white,
        errorStateBuilder: (cxt, err) {
          return Container(
            child: Center(
              child: Text(
                "Uh oh! Something went wrong...",
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<String> qrScan(Color color) async {
  String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
    '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    "Cancel",
    false,
    ScanMode.QR,
  );
  return barcodeScanRes;
}
