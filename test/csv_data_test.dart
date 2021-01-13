import 'package:test/test.dart';

import 'package:csv2html/csv_data.dart';

//----------------------------------------------------------------

void badHeader() {
  group('bad header', () {
    const testCases = [
      ['empty file', ''],
      ['no header', '\nfoo'],
      ['blank first variable name', ',two'],
      ['blank second variable name', 'first,    ,third'],
      ['blank third variable name', 'first,second,'],
      ['duplicate variable name', 'bad,good,bad'],
    ];

    for (final testCase in testCases) {
      final name = testCase[0];
      final input = testCase[1];

      test(name, () {
        try {
          CsvData.load(input);
          fail('did not throw exception');
        } on CsvDataException catch (e) {
          expect(e.lineNum, equals(1));
        }
      });
    }
  });
}

//----------------------------------------------------------------

void noRecords() {
  group('no records', () {
    const testCases = [
      ['header only', 'foo'],
      ['blank row', 'foo\n'],
      ['blank rows', 'foo\n\n\n'],
      ['blank fields', 'foo\n,     ,\t\t\t \t,,,,,'],
    ];

    for (final testCase in testCases) {
      final name = testCase[0];
      final input = testCase[1];

      test(name, () {
        final d = CsvData.load(input);
        expect(d.records, isEmpty);
      });
    }
  });
}

//----------------------------------------------------------------

void general() {
  group('general', () {
    test('good', () {
      final d = CsvData.load('''
foo,bar,baz
1,2,3
4,5
''');
      expect(d.records.length, equals(2));
      expect(d.records.first['foo'], equals('1'));
      expect(d.records.first['bar'], equals('2'));
      expect(d.records.first['baz'], equals('3'));
      expect(d.records.first['unknown'], equals(''));
    });

    test('bad', () {
      try {
         CsvData.load('''
foo,bar,baz
1,2,3
4,5,6,7
''');
      } on CsvDataException catch (e) {
        expect(e.lineNum, equals(3));
      }
    });
  });
}

//----------------------------------------------------------------

void main() {
  badHeader();
  noRecords();
  general();
}
