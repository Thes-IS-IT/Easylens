import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:easylens/services/sms_service.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'MENSAHERO_API_KEY=testkey\nMENSAHERO_BASE_URL=https://test.url');
  });

  group('SmsService Phone Formatting Tests', () {
    late SmsService smsService;

    setUp(() {
      smsService = SmsService();
    });

    test('Should format raw numbers starting with 09 to +639', () {
      expect(smsService.formatPhoneNumber('09123456789'), '+639123456789');
    });

    test('Should format raw numbers starting with 9 to +639', () {
      expect(smsService.formatPhoneNumber('9123456789'), '+639123456789');
    });

    test('Should keep format if starting with +639', () {
      expect(smsService.formatPhoneNumber('+639123456789'), '+639123456789');
    });

    test('Should prepend plus sign if starting with 639', () {
      expect(smsService.formatPhoneNumber('639123456789'), '+639123456789');
    });

    test('Should strip spaces, dashes and non-digit characters correctly', () {
      expect(smsService.formatPhoneNumber('+63 912-345 6789'), '+639123456789');
    });
  });
}
