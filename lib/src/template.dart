part of csv_data;

//################################################################
/// Base class for a template item.

abstract class TemplateItem {}

//################################################################
/// Item to indicate a property is to be ignored.

class TemplateItemIgnore extends TemplateItem {
  TemplateItemIgnore(this.propertyName, this.enumerations);

  final String propertyName;
  final Map<String, String>? enumerations;
}

//################################################################
/// Item to indicate a single property.

class TemplateItemScalar extends TemplateItem {
  TemplateItemScalar(this.propertyName, this.displayText, this.enumerations);

  final String propertyName;

  final Map<String, String>? enumerations;

  final String displayText;
}

//################################################################
/// Item to indicate a group of properties.

class TemplateItemGroup extends TemplateItem {
  TemplateItemGroup(this.displayText, this.members);

  final String displayText;

  final List<TemplateItemScalar> members;
}

//################################################################
/// Exception thrown when there is a problem with a template.

class TemplateException implements Exception {
  TemplateException(this.lineNum, this.message);

  final int lineNum;
  final String message;
}

//################################################################
/// Template for a record.
///
/// A template identifies properties and how they are to be interpreted.
///
/// The main part of a template is an ordered list of [items]. These identify
/// individual properties [TemplateItemScalar], groups of properties
/// [TemplateItemGroup], or properties that are to be ignored
/// [TemplateItemIgnore].
///
/// The template has a list of [sortProperties] that can be used to sort
/// the records and a list of [identifierProperties] that are used to identify
/// a record.
///
/// The template also specifies a [title] and [subtitle].

class RecordTemplate {
  //================================================================

  //----------------------------------------------------------------
  /// Create a default template based on the CSV data.
  ///
  /// The default template uses each of the data's property names as an item
  /// (in the same order), and the first property as the identifying property.
  /// There are no sort properties.

  RecordTemplate(CsvData data) {
    for (final propertyName in data.propertyNames) {
      items.add(TemplateItemScalar(propertyName, propertyName, null));

      if (identifierProperties.isEmpty) {
        // Use first property as the identifier
        identifierProperties.add(propertyName);
      }
    }
  }

  //----------------------------------------------------------------
  /// Create a template by loading it from a file.

  RecordTemplate.load(String specification) {
    // Parse specification as CSV

    final data = CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(specification);

    // Ignore header row
    // - column name
    // - label
    // - enumeration

    // Extract template items from all the other rows

    String? groupLabel;
    List<TemplateItemScalar>? groupItems;

    var lineNum = 1;
    for (final row in data.getRange(1, data.length)) {
      lineNum++;

      final displayText = row[0];
      final propertyName = row[1];
      final enumStr = row[2];
      // 4th column is for comments

      if (4 < row.length) {
        throw TemplateException(lineNum, 'too many fields in row $lineNum');
      }

      final enumerations = _parseEnum(lineNum, enumStr);

      if (propertyName == '#TITLE') {
        title = displayText;
      } else if (propertyName == '#SUBTITLE') {
        subtitle = displayText;
      } else if (displayText == '#UNUSED') {
        items.add(TemplateItemIgnore(propertyName, enumerations));
      } else if (displayText == '#SORT') {
        if (sortProperties.contains(propertyName)) {
          throw TemplateException(
              lineNum, 'duplicate sort property: $propertyName');
        }
        sortProperties.add(propertyName);
      } else if (displayText == '#IDENTIFIER') {
        identifierProperties.add(propertyName);
      } else if (displayText.startsWith('#')) {
        throw TemplateException(
            lineNum, 'Unexpected display text: $displayText');
      } else if (propertyName.startsWith('#')) {
        throw TemplateException(
            lineNum, 'Unexpected property name: $propertyName');
      } else if (propertyName.isNotEmpty || displayText.isNotEmpty) {
        if (groupItems == null) {
          if (propertyName.isNotEmpty) {
            // Simple item

            final item =
                TemplateItemScalar(propertyName, displayText, enumerations);

            items.add(item);
          } else {
            // Start of group
            groupLabel = displayText;
            groupItems = [];
          }
        } else {
          // Add to group
          final item =
              TemplateItemScalar(propertyName, displayText, enumerations);
          groupItems.add(item);
        }
      } else {
        // Blank line
        if (groupItems != null) {
          // Complete the group
          items.add(
              TemplateItemGroup(groupLabel ?? 'Unnamed group', groupItems));
          groupItems = null;
        }
      }
    }

    if (groupItems != null) {
      // Complete the last group
      items.add(TemplateItemGroup(groupLabel ?? 'Unnamed group', groupItems));
      groupItems = null;
    }

    // Make sure there is at least one identifier property to use

    if (identifierProperties.isEmpty) {
      // Default to first property as the identifier property

      for (final item in items) {
        if (item is TemplateItemScalar) {
          identifierProperties.add(item.propertyName);
          break;
        } else if (item is TemplateItemIgnore) {
          identifierProperties.add(item.propertyName);
          break;
        }
      }

      if (identifierProperties.isEmpty) {
        throw TemplateException(lineNum, 'no identifier column');
      }
    }
  }

  //================================================================
  // Members

  String title = '';

  String subtitle = '';

  final List<String> sortProperties = [];

  final List<String> identifierProperties = [];

  final List<TemplateItem> items = [];

  //================================================================

  Map<String, String>? _parseEnum(int lineNum, String str) {
    final result = <String, String>{};

    for (final pair
        in str.split(';').map((x) => x.trim()).where((y) => y.isNotEmpty)) {
      final equalsIndex = pair.indexOf('=');
      if (0 < equalsIndex) {
        final key = pair.substring(0, equalsIndex).trim();
        final label = pair.substring(equalsIndex + 1).trim();

        if (result.containsKey(key)) {
          throw TemplateException(lineNum, 'duplicate key in enum: $key');
        }
        result[key] = label;
      } else {
        throw TemplateException(lineNum, 'bad enum missing equals: $pair');
      }
    }

    return result.isNotEmpty ? result : null;
  }

  //----------------------------------------------------------------
  /// Identify any properties in the data that do not appear in the template.

  Set<String> unusedProperties(CsvData data) {
    final usedColumns = <String>{};

    for (final item in items) {
      if (item is TemplateItemScalar) {
        usedColumns.add(item.propertyName);
      } else if (item is TemplateItemGroup) {
        for (final member in item.members) {
          usedColumns.add(member.propertyName);
        }
      } else if (item is TemplateItemIgnore) {
        usedColumns.add(item.propertyName);
      }
    }

    final unusedColumns = <String>{};

    for (final propertyName in data.propertyNames) {
      if (!usedColumns.contains(propertyName)) {
        unusedColumns.add(propertyName);
      }
    }

    return unusedColumns;
  }
}