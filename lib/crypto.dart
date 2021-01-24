import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

import "package:pointycastle/export.dart";
import "package:asn1lib/asn1lib.dart";
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRSAkeyPair(
    {int bitLength = 2048}) {
  print('Generating RSA Key pair...');

  // Create an RSA key generator and initialize it

  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
        _secureRandom()));

  // Use the generator

  final pair = keyGen.generateKeyPair();

  // Cast the generated key pair into the RSA key types

  final myPublic = pair.publicKey as RSAPublicKey;
  final myPrivate = pair.privateKey as RSAPrivateKey;

  return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(myPublic, myPrivate);
}

SecureRandom _secureRandom() {
  final secureRandom = FortunaRandom();

  final seedSource = Random.secure();
  final seeds = <int>[];
  for (int i = 0; i < 32; i++) {
    seeds.add(seedSource.nextInt(255));
  }
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

  return secureRandom;
}

encodePublicKeyToPem(RSAPublicKey publicKey) {
  var algorithmSeq = new ASN1Sequence();
  var algorithmAsn1Obj = new ASN1Object.fromBytes(Uint8List.fromList([0x6, 0x9, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0xd, 0x1, 0x1, 0x1]));
  var paramsAsn1Obj = new ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
  algorithmSeq.add(algorithmAsn1Obj);
  algorithmSeq.add(paramsAsn1Obj);

  var publicKeySeq = new ASN1Sequence();
  publicKeySeq.add(ASN1Integer(publicKey.modulus));
  publicKeySeq.add(ASN1Integer(publicKey.exponent));
  var publicKeySeqBitString = new ASN1BitString(Uint8List.fromList(publicKeySeq.encodedBytes));

  var topLevelSeq = new ASN1Sequence();
  topLevelSeq.add(algorithmSeq);
  topLevelSeq.add(publicKeySeqBitString);
  var dataBase64 = base64.encode(topLevelSeq.encodedBytes);

  return """-----BEGIN PUBLIC KEY-----\r\n$dataBase64\r\n-----END PUBLIC KEY-----""";
}

encodePrivateKeyToPem(RSAPrivateKey privateKey) {
  var version = ASN1Integer(BigInt.from(0));

  var algorithmSeq = new ASN1Sequence();
  var algorithmAsn1Obj = new ASN1Object.fromBytes(Uint8List.fromList([0x6, 0x9, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0xd, 0x1, 0x1, 0x1]));
  var paramsAsn1Obj = new ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
  algorithmSeq.add(algorithmAsn1Obj);
  algorithmSeq.add(paramsAsn1Obj);

  var privateKeySeq = new ASN1Sequence();
  var modulus = ASN1Integer(privateKey.n);
  var publicExponent = ASN1Integer(BigInt.parse('65537'));
  var privateExponent = ASN1Integer(privateKey.d);
  var p = ASN1Integer(privateKey.p);
  var q = ASN1Integer(privateKey.q);
  var dP = privateKey.d % (privateKey.p - BigInt.from(1));
  var exp1 = ASN1Integer(dP);
  var dQ = privateKey.d % (privateKey.q - BigInt.from(1));
  var exp2 = ASN1Integer(dQ);
  var iQ = privateKey.q.modInverse(privateKey.p);
  var co = ASN1Integer(iQ);

  privateKeySeq.add(version);
  privateKeySeq.add(modulus);
  privateKeySeq.add(publicExponent);
  privateKeySeq.add(privateExponent);
  privateKeySeq.add(p);
  privateKeySeq.add(q);
  privateKeySeq.add(exp1);
  privateKeySeq.add(exp2);
  privateKeySeq.add(co);
  var publicKeySeqOctetString = new ASN1OctetString(Uint8List.fromList(privateKeySeq.encodedBytes));

  var topLevelSeq = new ASN1Sequence();
  topLevelSeq.add(version);
  topLevelSeq.add(algorithmSeq);
  topLevelSeq.add(publicKeySeqOctetString);
  var dataBase64 = base64.encode(topLevelSeq.encodedBytes);

  return """-----BEGIN PRIVATE KEY-----\r\n$dataBase64\r\n-----END PRIVATE KEY-----""";
}

List<int> decodePEM(String pem) {
  var startsWith = [
    "-----BEGIN PUBLIC KEY-----",
    "-----BEGIN PRIVATE KEY-----"
  ];
  var endsWith = [
    "-----END PUBLIC KEY-----",
    "-----END PRIVATE KEY-----"
  ];
  bool isOpenPgp = pem.indexOf('BEGIN PGP') != -1;

  for (var s in startsWith) {
    if (pem.startsWith(s)) {
      pem = pem.substring(s.length);
    }
  }

  for (var s in endsWith) {
    if (pem.endsWith(s)) {
      pem = pem.substring(0, pem.length - s.length);
    }
  }

  if (isOpenPgp) {
    var index = pem.indexOf('\r\n');
    pem = pem.substring(0, index);
  }

  pem = pem.replaceAll('\n', '');
  pem = pem.replaceAll('\r', '');

  return base64.decode(pem);
}

parsePublicKeyFromPem(pemString) {
  List<int> publicKeyDER = decodePEM(pemString);
  var asn1Parser = new ASN1Parser(publicKeyDER);
  var topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
  var publicKeyBitString = topLevelSeq.elements[1];

  var publicKeyAsn = new ASN1Parser(publicKeyBitString.contentBytes());
  ASN1Sequence publicKeySeq = publicKeyAsn.nextObject();
  var modulus = publicKeySeq.elements[0] as ASN1Integer;
  var exponent = publicKeySeq.elements[1] as ASN1Integer;

  RSAPublicKey rsaPublicKey = RSAPublicKey(
      modulus.valueAsBigInteger,
      exponent.valueAsBigInteger
  );

  return rsaPublicKey;
}

parsePrivateKeyFromPem(pemString) {
  List<int> privateKeyDER = decodePEM(pemString);
  var asn1Parser = new ASN1Parser(privateKeyDER);
  var topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
  var version = topLevelSeq.elements[0];
  var algorithm = topLevelSeq.elements[1];
  var privateKey = topLevelSeq.elements[2];

  asn1Parser = new ASN1Parser(privateKey.contentBytes());
  var pkSeq = asn1Parser.nextObject() as ASN1Sequence;

  version = pkSeq.elements[0];
  var modulus = pkSeq.elements[1] as ASN1Integer;
  var publicExponent = pkSeq.elements[2] as ASN1Integer;
  var privateExponent = pkSeq.elements[3] as ASN1Integer;
  var p = pkSeq.elements[4] as ASN1Integer;
  var q = pkSeq.elements[5] as ASN1Integer;
  var exp1 = pkSeq.elements[6] as ASN1Integer;
  var exp2 = pkSeq.elements[7] as ASN1Integer;
  var co = pkSeq.elements[8] as ASN1Integer;

  RSAPrivateKey rsaPrivateKey = RSAPrivateKey(
      modulus.valueAsBigInteger,
      privateExponent.valueAsBigInteger,
      p.valueAsBigInteger,
      q.valueAsBigInteger
  );

  return rsaPrivateKey;
}

Uint8List rsaSign(RSAPrivateKey privateKey, Uint8List dataToSign) {

  final signer = RSASigner(SHA256Digest(), '0609608648016503040201');

  signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey)); // true=sign

  final sig = signer.generateSignature(dataToSign);

  return sig.bytes;
}

bool rsaVerify(
    RSAPublicKey publicKey, Uint8List signedData, Uint8List signature) {
  final sig = RSASignature(signature);

  final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');

  verifier.init(false, PublicKeyParameter<RSAPublicKey>(publicKey)); // false=verify

  try {
    return verifier.verifySignature(signedData, sig);
  } on ArgumentError {
    return false; // for Pointy Castle 1.0.2 when signature has been modified
  }
}

Uint8List rsaEncrypt(RSAPublicKey encryptionPublicKey, Uint8List dataToEncrypt) {
  final encryptor = OAEPEncoding(RSAEngine())
    ..init(true, PublicKeyParameter<RSAPublicKey>(encryptionPublicKey)); // true=encrypt

  return _processInBlocks(encryptor, dataToEncrypt);
}

Uint8List rsaDecrypt(RSAPrivateKey myPrivate, Uint8List cipherText) {
  final decryptor = OAEPEncoding(RSAEngine())
    ..init(false, PrivateKeyParameter<RSAPrivateKey>(myPrivate)); // false=decrypt

  return _processInBlocks(decryptor, cipherText);
}

Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
  final numBlocks = input.length ~/ engine.inputBlockSize +
    ((input.length % engine.inputBlockSize != 0) ? 1 : 0);

  final output = Uint8List(numBlocks * engine.outputBlockSize);

  var inputOffset = 0;
  var outputOffset = 0;
  while (inputOffset < input.length) {
    final chunkSize = (inputOffset + engine.inputBlockSize <= input.length)
      ? engine.inputBlockSize
      : input.length - inputOffset;

    outputOffset += engine.processBlock(
      input, inputOffset, chunkSize, output, outputOffset);

    inputOffset += chunkSize;
  }

  return (output.length == outputOffset)
    ? output
    : output.sublist(0, outputOffset);
}