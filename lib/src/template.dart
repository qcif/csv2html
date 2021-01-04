part of csv_data;

//################################################################
/// Base class for a template item.

abstract class TemplateItem {}

//################################################################
/// Item to indicate a property is to be ignored.

class TemplateItemIgnore extends TemplateItem {
  TemplateItemIgnore(this.propertyName, this.enumerations);

  final String propertyName;

  /// Optional enumerations
  final Map<String, String> enumerations;
}

//################################################################
/// Item to indicate a single property.

class TemplateItemScalar extends TemplateItem {
  TemplateItemScalar(this.propertyName, this.displayText, this.enumerations);

  final String propertyName;

  /// Optional enumerations
  final Map<String, String> enumerations;

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

  @override
  String toString() => 'line $lineNum: $message';
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
    // - notes

    // Extract template items from all the other rows

    String groupLabel;
    List<TemplateItemScalar> groupItems;
    var lineNum = 1;

    if (1 < data.length) {
      for (final row in data.getRange(1, data.length)) {
        lineNum++;

        final displayText = (row.isNotEmpty) ? row[0].trim() : '';
        final propertyName = (row.length >= 2) ? row[1].trim() : '';
        final enumStr = (row.length >= 3) ? row[2].trim() : '';
        // 4th column is for comments

        if (4 < row.length) {
          throw TemplateException(lineNum, 'too many fields in row');
        }

        final enumerations = _parseEnum(lineNum, enumStr);

        if (displayText.startsWith('#')) {
          // Comment row: ignore

          if (displayText == '#TITLE' || displayText == '#UNUSED') {
            throw TemplateException(
                lineNum, 'old template syntax: change #COMMAND to _COMMAND');
          }
        } else if (displayText.startsWith('_')) {
          // Command row
          _processCommand(lineNum, displayText, propertyName, enumerations);
        } else if (propertyName.isNotEmpty || displayText.isNotEmpty) {
          // Template entry row

          if (groupItems == null) {
            if (propertyName.isNotEmpty) {
              // Singular item

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
          // Blank row

          if (enumerations != null) {
            throw TemplateException(lineNum, 'enumeration without property');
          }

          if (groupItems != null) {
            // Complete the group
            items.add(
                TemplateItemGroup(groupLabel ?? 'Unnamed group', groupItems));
            groupItems = null;
          }
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

  //----------------

  void _processCommand(int lineNum, String command, String param,
      Map<String, String> enumerations) {
    if (command == '_TITLE') {
      title = param;
    } else if (command == '_SUBTITLE') {
      subtitle = param;
    } else if (command == '_UNUSED') {
      items.add(TemplateItemIgnore(param, enumerations));
    } else if (command == '_SORT') {
      if (sortProperties.contains(param)) {
        throw TemplateException(lineNum, 'duplicate sort property: $param');
      }
      sortProperties.add(param);
    } else if (command == '_IDENTIFIER') {
      identifierProperties.add(param);
    } else if (command == '_SHOW') {
      _processCommandShow(lineNum, command, param);
    } else {
      throw TemplateException(lineNum, 'unknown command: $command');
    }
  }

  //----------------

  void _processCommandShow(int lineNum, String command, String param) {
    showRecords = false;
    showRecordsContents = false;
    showProperties = false;
    showPropertiesIndex = false;

    for (final v in param.split(';')) {
      switch (v.trim()) {
        case 'records':
          showRecords = true;
          break;
        case 'contents':
          showRecordsContents = true;
          break;
        case 'properties':
          showProperties = true;
          break;
        case 'index':
          showPropertiesIndex = true;
          break;
        case 'all':
          showRecords = true;
          showRecordsContents = true;
          showProperties = true;
          showPropertiesIndex = true;
          break;

        default:
          throw TemplateException(lineNum, 'unknown value in _SHOW: $param');
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

  /// Show the records (and maybe the table of contents).

  bool showRecords = true;

  /// Show the table of contents (only if [showRecords] is also true).

  bool showRecordsContents = true;

  /// Show the properties (and maybe the index of properties).

  bool showProperties = true;

  /// Show the index of properties (only if [showProperties] is also true).

  bool showPropertiesIndex = true;

  //================================================================

  Map<String, String> _parseEnum(int lineNum, String str) {
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
