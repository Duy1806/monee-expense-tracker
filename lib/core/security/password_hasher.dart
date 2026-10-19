import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class PasswordHash {
  const PasswordHash({required this.hash, required this.salt});

    /// Dạng: `pbkdf2_sha256$<số vòng lặp>$<base64 của khóa dẫn xuất>`
  final String hash;

  /// Salt ngẫu nhiên, mã hóa base64.
  final String salt;
}

/// PBKDF2-HMAC-SHA256 viết bằng Dart thuần (dùng package crypto cho HMAC).
Uint8List pbkdf2Sha256(
  List<int> password,
  List<int> salt,
  int iterations,
  int keyLength,
) {
  final hmac = Hmac(sha256, password);
  const hashLength = 32;
  final blockCount = (keyLength + hashLength - 1) ~/ hashLength;
  final output = <int>[];

  for (var block = 1; block <= blockCount; block++) {
    final blockSalt = <int>[
      ...salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ];

    var u = hmac.convert(blockSalt).bytes;
    final t = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;

      for (var k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }

    output.addAll(t);
  }

  return Uint8List.fromList(output.sublist(0, keyLength));
}

Uint8List _deriveInIsolate(List<Object> args) {
  return pbkdf2Sha256(
    args[0] as List<int>,
    args[1] as List<int>,
    args[2] as int,
    32,
  );
}

class PasswordHasher {
  const PasswordHasher({
    this.iterations = defaultIterations,
    this.useIsolate = true,
  });

  /// Mức cân bằng cho Dart thuần trên điện thoại; thấp hơn khuyến nghị
  /// cho server. Xem phần hạn chế trong tài liệu kỹ thuật.
  static const int defaultIterations = 60000;

  static const int _maxIterations = 2000000;
  static const String _scheme = 'pbkdf2_sha256';
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  final int iterations;

  /// Chạy trong isolate để không treo giao diện. Test đặt false.
  final bool useIsolate;

  Future<PasswordHash> hash(String password) async {
    final salt = _randomBytes(_saltLength);
    final key = await _derive(utf8.encode(password), salt, iterations);

    return PasswordHash(
      hash: '$_scheme\$$iterations\$${base64.encode(key)}',
      salt: base64.encode(salt),
    );
  }

  Future<bool> verify(
    String password, {
    required String storedHash,
    required String storedSalt,
  }) async {
    final parts = storedHash.split(r'$');

    if (parts.length != 3 || parts[0] != _scheme) {
      return false;
    }

    final storedIterations = int.tryParse(parts[1]);

    if (storedIterations == null ||
        storedIterations < 1 ||
        storedIterations > _maxIterations) {
      return false;
    }

    final expected = _tryDecode(parts[2]);
    final salt = _tryDecode(storedSalt);

    if (expected == null || salt == null) {
      return false;
    }

    final actual = await _derive(
      utf8.encode(password),
      salt,
      storedIterations,
    );

    return _constantTimeEquals(actual, expected);
  }

  Future<Uint8List> _derive(
    List<int> password,
    Uint8List salt,
    int rounds,
  ) {
    if (useIsolate) {
      return compute(
        _deriveInIsolate,
        <Object>[Uint8List.fromList(password), salt, rounds],
      );
    }

    return Future<Uint8List>.value(
      pbkdf2Sha256(password, salt, rounds, _keyLength),
    );
  }

  Uint8List? _tryDecode(String value) {
    try {
      return base64.decode(value);
    } on FormatException {
      return null;
    }
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();

    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }

    var diff = 0;

    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }

    return diff == 0;
  }
}