part of csv_data;

//################################################################
/// Base class for a template item.
///
/// There are two types of template items: properties and groups,
/// corresponding to [TemplateItemProperty] and [TemplateItemGroup].

abstract class TemplateItem {}

//################################################################
/// Base class for a property template item.
///
/// There are three types of property template items:
///
/// - properties used in the record (either at the top level or in a group);
/// - other properties; and
/// - hidden properties.

abstract class TemplateItemProperty extends TemplateItem {
  TemplateItemProperty(this.propertyName, this.enumerations, this.notes);

  // Name of the property
  final String propertyName;

  /// Optional enumerations
  final Map<String, String> enumerations;

  /// Notes about the property
  final String notes;
}

//################################################################
/// Item to indicate a single property.

class TemplateItemActive extends TemplateItemProperty {
  TemplateItemActive(String propertyName, this.displayText,
      Map<String, String> enumerations, String notes)
      : super(propertyName, enumerations, notes);

  final String displayText;
}

//################################################################
/// Item to indicate a property is not used in the records.
///
/// These properties are not included in the records section, but they are
/// included in the properties section.

class TemplateItemOther extends TemplateItemProperty {
  TemplateItemOther(
      String propertyName, Map<String, String> enumerations, String notes)
      : super(propertyName, enumerations, notes);
}

//################################################################
/// Item to indicate a property is hidden.
///
/// These properties are not included in the records section, and also not
/// normally included in the properties section. But they can be included
/// in the properties section, if requested.

class TemplateItemHide extends TemplateItemProperty {
  TemplateItemHide(
      String propertyName, Map<String, String> enumerations, String notes)
      : super(propertyName, enumerations, notes);
}

//################################################################
/// Item to indicate a group of properties.

class TemplateItemGroup extends TemplateItem {
  TemplateItemGroup(this.displayText, this.members);

  final String displayText;

  final List<TemplateItemProperty> members;
}

//################################################################
/// Exception thrown when there is a problem with a template.

class TemplateException implements Exception {
  TemplateException(this.message, [this.lineNum]);

  /// The line from the template file causing the problem.
  ///
  /// Null if the line cannot be identified.

  final int lineNum;

  /// Error message.

  final String message;

  @override
  String toString() => '${lineNum != null ? 'line $lineNum: ' : ''}$message';
}

//################################################################
/// Template for displaying a CSV file.
///
/// A template identifies properties and how they are to be interpreted.
///
/// The main part of a template is an ordered list of [items]. These identify
/// individual properties [TemplateItemActive], groups of properties
/// [TemplateItemGroup], properties that are to be displayed but are not a part
/// of the record [TemplateItemOther], and properties that are not to be
/// displayed [TemplateItemHide].
///
/// The template has a list of [sortProperties] that can be used to sort
/// the records and a list of [identifierProperties] that are used to identify
/// a record.
///
/// The template also specifies a [title] and [subtitle].

class Template {
  //================================================================

  //----------------------------------------------------------------
  /// Create a default template based on the CSV data.
  ///
  /// The default template uses each of the data's property names as an item
  /// (in the same order), and the first property as the identifying property.
  /// There are no sort properties.

  Template(CsvData data) {
    for (final propertyName in data.propertyNames) {
      items.add(TemplateItemActive(propertyName, propertyName, null, ''));

      if (identifierProperties.isEmpty) {
        // Use first property as the identifier
        identifierProperties.add(propertyName);
      }
    }
  }

  //----------------------------------------------------------------
  /// Create a template by parsing the CSV representation of it.

  Template.load(String templateCsv) {
    try {
      // Parse specification as CSV

      // CSV package's detection of eol is unreliable, so do our own handling
      // of CR-LF and treat everything as LF.

      final data = CsvToListConverter(
              eol: '\n', shouldParseNumbers: false, allowInvalid: false)
          .convert(templateCsv.replaceAll('\r\n', '\n'));

      // Ignore header row
      // - column name
      // - label
      // - enumeration
      // - notes

      // Extract template items and commands from all the other rows

      String groupLabel;
      List<TemplateItemActive> groupItems;
      var lineNum = 1;

      if (1 < data.length) {
        for (final row in data.getRange(1, data.length)) {
          lineNum++;

          final displayText = (row.isNotEmpty) ? row[0].trim() : '';
          final propertyName = (row.length >= 2) ? row[1].trim() : '';
          final enumStr = (row.length >= 3) ? row[2].trim() : '';
          final notes = (row.length >= 4) ? row[3].trim() : '';

          if (4 < row.length) {
            throw TemplateException('too many fields in row', lineNum);
          }

          if (displayText.startsWith('#')) {
            // Comment row: ignore

            if (displayText == '#TITLE' || displayText == '#UNUSED') {
              throw TemplateException(
                  'old template syntax: change #COMMAND to _COMMAND', lineNum);
            }
          } else {
            // Not a comment

            final enumerations = _parseEnum(lineNum, enumStr);

            if (displayText.startsWith('_')) {
              // Command row
              _processCommand(
                  lineNum, displayText, propertyName, enumerations, notes);
            } else if (propertyName.isNotEmpty || displayText.isNotEmpty) {
              // Template entry row

              if (groupItems == null) {
                if (propertyName.isNotEmpty) {
                  // Singular item

                  final item = TemplateItemActive(
                      propertyName, displayText, enumerations, notes);

                  items.add(item);
                } else {
                  // Start of group
                  groupLabel = displayText;
                  groupItems = [];
                }
              } else {
                // Add to group
                final item = TemplateItemActive(
                    propertyName, displayText, enumerations, notes);
                groupItems.add(item);
              }
            } else {
              // Blank row

              if (enumerations != null) {
                throw TemplateException(
                    'enumeration without property', lineNum);
              }

              if (groupItems != null) {
                // Complete the group
                items.add(TemplateItemGroup(
                    groupLabel ?? 'Unnamed group', groupItems));
                groupItems = null;
              }
            }
          } // not a comment
        } // for all non-header rows
      } // if has non-header rows

      if (groupItems != null) {
        // Complete the last group
        items.add(TemplateItemGroup(groupLabel ?? 'Unnamed group', groupItems));
        groupItems = null;
      }

      // Make sure there is at least one identifier property to use

      if (identifierProperties.isEmpty) {
        // Default to first property as the identifier property

        for (final item in items) {
          if (item is TemplateItemActive) {
            identifierProperties.add(item.propertyName);
            break;
          } else if (item is TemplateItemHide) {
            identifierProperties.add(item.propertyName);
            break;
          }
        }

        if (identifierProperties.isEmpty) {
          throw TemplateException('no identifier column', lineNum);
        }
      }
    } on FormatException catch (e) {
      throw TemplateException('invalid CSV: ${e.message}');
    }
  }

  //----------------
  /// Parse a command.

  void _processCommand(int lineNum, String command, String param,
      Map<String, String> enumerations, String notes) {
    if (command == '_TITLE') {
      title = param;
    } else if (command == '_SUBTITLE') {
      subtitle = param;
    } else if (command == '_OTHER') {
      items.add(TemplateItemOther(param, enumerations, notes));
    } else if (command == '_HIDE') {
      items.add(TemplateItemHide(param, enumerations, notes));
    } else if (command == '_SORT') {
      if (sortProperties.contains(param)) {
        throw TemplateException('duplicate sort property: $param', lineNum);
      }
      sortProperties.add(param);
    } else if (command == '_IDENTIFIER') {
      identifierProperties.add(param);
    } else if (command == '_SHOW') {
      _processCommandShow(lineNum, command, param);
    } else {
      throw TemplateException('unknown command: $command', lineNum);
    }
  }

  //----------------
  /// Parse the value provided to the _SHOW command.
  ///
  /// The value is a set of semicolon separated values, indicating which
  /// sections and their contents/index to show.

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
          throw TemplateException('unknown value in _SHOW: $param', lineNum);
      }
    }
  }

  //================================================================
  // Members

  /// Display title.

  String title = '';

  /// Display subtitle.

  String subtitle = '';

  /// Properties used to sort the records.

  final List<String> sortProperties = [];

  /// Properties used to identify a record.

  final List<String> identifierProperties = [];

  /// The items making up the record.

  final List<TemplateItem> items = [];

  //----------------
  // The following booleans control which sections appear in the output.

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
          throw TemplateException('duplicate key in enum: $key', lineNum);
        }
        result[key] = label;
      } else {
        throw TemplateException('bad enum missing equals: $pair', lineNum);
      }
    }

    return result.isNotEmpty ? result : null;
  }

  //----------------------------------------------------------------
  /// Identify any properties in the data that do not appear in the template.

  Set<String> unusedProperties(CsvData data) {
    final usedColumns = <String>{};

    for (final item in items) {
      if (item is TemplateItemProperty) {
        usedColumns.add(item.propertyName);
      } else if (item is TemplateItemGroup) {
        for (final member in item.members) {
          usedColumns.add(member.propertyName);
        }
      } else if (item is TemplateItemHide) {
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
