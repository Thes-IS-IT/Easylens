import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudflareR2Service {
  static final CloudflareR2Service _instance = CloudflareR2Service._internal();
  factory CloudflareR2Service() => _instance;
  CloudflareR2Service._internal();

  /// Uploads a user's avatar image to Cloudflare R2 bucket.
  /// Returns the public URL of the uploaded image.
  Future<String> uploadAvatar(File file, String userId) async {
    final accountId = dotenv.env['ACCOUNT_ID'] ?? '';
    final accessKeyId = dotenv.env['ACCESS_KEY_ID'] ?? '';
    final secretAccessKey = dotenv.env['SECRET_ACCESS_KEY'] ?? '';
    final bucketName = dotenv.env['BUCKET_NAME'] ?? 'easylens';
    final publicUrl = dotenv.env['CLOUDFLARE_R2_PUBLIC_URL'] ?? '';

    if (accountId.isEmpty || accessKeyId.isEmpty || secretAccessKey.isEmpty) {
      print('Warning: Cloudflare R2 credentials missing. Running in mock mode.');
      return 'https://mock-cloudflare-storage.easylens.internal/users/$userId/avatar.png';
    }

    // The object key (path inside the bucket — no leading slash for key)
    final objectKey = 'users/$userId/avatar.png';

    // R2 S3-compatible host
    final host = '$accountId.r2.cloudflarestorage.com';

    // Canonical URI is /<bucket>/<objectKey>
    final canonicalUri = '/$bucketName/$objectKey';

    final now = DateTime.now().toUtc();
    final amzDate = _toAmzDate(now);   // e.g. 20240101T120000Z
    final dateStamp = _toDateStamp(now); // e.g. 20240101

    final fileBytes = await file.readAsBytes();
    final payloadHash = sha256.convert(fileBytes).toString();
    final contentLength = fileBytes.length.toString();

    // ── Step 1: Canonical Request ──────────────────────────────────────────
    // Headers must be sorted alphabetically
    final canonicalHeaders =
        'content-length:$contentLength\n'
        'content-type:image/png\n'
        'host:$host\n'
        'x-amz-content-sha256:$payloadHash\n'
        'x-amz-date:$amzDate\n';
    const signedHeaders = 'content-length;content-type;host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest =
        'PUT\n'
        '$canonicalUri\n'
        '\n' // empty query string
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';

    // ── Step 2: String to Sign ─────────────────────────────────────────────
    const region = 'auto'; // Cloudflare R2 uses 'auto' region
    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final hashedCanonicalRequest =
        sha256.convert(utf8.encode(canonicalRequest)).toString();
    final stringToSign =
        'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n$hashedCanonicalRequest';

    // ── Step 3: Signing Key ────────────────────────────────────────────────
    final signingKey = _getSigningKey(secretAccessKey, dateStamp, region, 's3');

    // ── Step 4: Signature ──────────────────────────────────────────────────
    final signatureBytes = _hmacSha256(signingKey, stringToSign);
    final signature = signatureBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // ── Step 5: PUT request ────────────────────────────────────────────────
    final requestUrl = 'https://$host/$bucketName/$objectKey';
    final uri = Uri.parse(requestUrl);

    try {
      print('Uploading avatar to R2: $requestUrl');
      final response = await http.put(
        uri,
        headers: {
          'Host': host,
          'Content-Length': contentLength,
          'Content-Type': 'image/png',
          'x-amz-content-sha256': payloadHash,
          'x-amz-date': amzDate,
          'Authorization':
              'AWS4-HMAC-SHA256 Credential=$accessKeyId/$credentialScope, '
              'SignedHeaders=$signedHeaders, Signature=$signature',
        },
        body: fileBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('Cloudflare R2: Upload succeeded.');
        if (publicUrl.isNotEmpty) {
          return '$publicUrl/$objectKey';
        }
        return 'https://pub-$accountId.r2.dev/$objectKey';
      } else {
        print('Cloudflare R2: Upload failed ${response.statusCode}: ${response.body}');
        throw Exception('R2 upload failed: Status ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading to Cloudflare R2: $e');
      rethrow;
    }
  }

  // ── AWS Sig V4 helpers ─────────────────────────────────────────────────

  String _toAmzDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${y}${mo}${d}T${h}${mi}${s}Z';
  }

  String _toDateStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$mo$d';
  }

  List<int> _hmacSha256(List<int> key, String data) {
    return Hmac(sha256, key).convert(utf8.encode(data)).bytes;
  }

  List<int> _getSigningKey(
      String secretKey, String dateStamp, String region, String service) {
    final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), dateStamp);
    final kRegion = _hmacSha256(kDate, region);
    final kService = _hmacSha256(kRegion, service);
    return _hmacSha256(kService, 'aws4_request');
  }
}
