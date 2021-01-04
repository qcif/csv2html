import 'package:test/test.dart';

import 'package:csv2html/csv_data.dart';

//----------------------------------------------------------------

void emptyTemplates() {
  group('bad templates', () {
    const testCases = [
      ['no header row', ''],
      ['no items', 'TEMPLATE'],
      ['no items', 'TEMPLATE\n'],
      ['too many fields', 'TEMPLATE\ntext,name,enum,notes,unexpected', 2],
    ];

    for (final testCase in testCases) {
      final name = testCase[0];
      final input = testCase[1];
      final badRow = 2 < testCase.length ? testCase[2] : 1;

      test(name, () {
        try {
          final t = RecordTemplate.load(input);
        } on TemplateException catch (e) {
          expect(e.lineNum, equals(badRow));
        }
      });
    }
  });
}

//----------------------------------------------------------------

void example() {
  group('readme example', () {
    test('readme', () {
      final d = RecordTemplate.load('''
Display text,   Property,       Enumeration,    Notes

_TITLE,         My Books
_SUBTITLE,      An example

_SORT,          title
_SORT,          subtitle

_IDENTIFIER,    title

Book title,     title
Subtitle,       subtitle

Author,         ,               ,               Start of a group
Given name,     author_givenname
Family name,    author_familyname

ISBN,           isbn
Publisher,      publisher_name
Format,         format,         , hc=Hard cover;pb=Paperback
_UNUSED,        id
_UNUSED,        timestamp

#
  #
#Comment
   # Comment
#,Comment
''');

      expect(d.title, equals('My Books'));
      expect(d.subtitle, equals('An example'));
      expect(d.sortProperties, equals(['title', 'subtitle']));
      expect(d.identifierProperties, equals(['title']));
      expect(d.items.length, equals(8));

      final item = d.items[0];
      if (item is TemplateItemScalar) {
        expect(item.propertyName, equals('title'));
        expect(item.displayText, equals('Book title'));
        expect(item.enumerations, isNull);
      } else {
        fail('not a TemplateItemScalar');
      }

      // TODO: test other items

      expect(d.items[7], isA<TemplateItemIgnore>());
    });
  });
}
//----------------------------------------------------------------

void main() {
  emptyTemplates();
  example();
}
