part of csv_data;

//################################################################
/// Exception thrown when the CSV data is not valid.

class CsvDataException implements Exception {
  CsvDataException(this.lineNum, this.message);

  /// Line in the CSV that contains the problem.
  final int lineNum;

  /// Description of the problem.
  final String message;
}

//################################################################
/// Record from the CSV.
///
/// A **record** represents a row from the CSV file.

class Record {
  Record(this._rowNumber);

  final int _rowNumber;

  final Map<String, String> _fields = {};

  void operator []=(String name, String value) {
    _fields[name] = value;
  }

  String operator [](String name) {
    return _fields[name] ?? '';
  }

  String get identifier => 'r$_rowNumber';
}

//################################################################
/// Data from the CSV.
///
/// CSV data consists of a sequence of records with values corresponding to
/// named properties. These are available through [records] and [propertyNames].
///
/// The property names are extracted from the first row of the [csvText] and
/// the records are extracted from all the other rows. Every field in the
/// first row must be non-blank and must be unique. The columns correspond to
/// the properties. All the other rows must have no more fields than the number
/// of properties named in the first row. If there are less fields, the value of
/// the remaining properties in the record are assigned the empty string.

class CsvData {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Parses the [text] as Comma Separated Variables (CSV) data.

  factory CsvData.load(String csvText, {String eol = '\n'}) {
    final data = CsvToListConverter(eol: eol, shouldParseNumbers: false)
        .convert(csvText);

    // Extract property names from the header row

    final propertyNames = <String>[];

    var column = 0;
    for (final name in data.first.map((s) => s.trim())) {
      column++;

      if (name is String) {
        if (name.isNotEmpty) {
          propertyNames.add(name);
        } else {
          throw CsvDataException(1, 'column $column: blank property name');
        }
      } else {
        throw CsvDataException(1, 'column $column: property name not string');
      }
    }

    // Check all property names are unique

    final seen = <String>{};
    for (final name in propertyNames) {
      if (seen.contains(name)) {
        throw CsvDataException(1, 'duplicate property name: $name');
      } else {
        seen.add(name);
      }
    }

    // Extract records from all the other rows

    final records = <Record>[];

    var lineNum = 1; // skipping header row
    for (final row in data.getRange(1, data.length)) {
      lineNum++;

      final record = Record(lineNum);

      // Assign fields to property values

      var index = 0;

      while (index < row.length && index < propertyNames.length) {
        record[propertyNames[index]] = row[index].trim();
        index++;
      }

      // If there are extra fields, they must all be blank

      while (index < row.length) {
        if (row[index].trim.isNotEmpty) {
          throw CsvDataException(
              lineNum, 'column ${index + 1}: more fields than properties');
        }
        index++;
      }

      records.add(record);

      /* Do we want to ignore totally empty records?
        if (row.any((v) => v.trim().isNotEmpty)) {
          records.add(record);
      } */
    }

    // Create the object

    return CsvData._init(propertyNames, records);
  }

  //----------------------------------------------------------------
  /// Internal constructor.

  CsvData._init(this._propertyNames, this._records);

  //================================================================
  // Members

  //----------------------------------------------------------------

  final List<String> _propertyNames;

  final List<Record> _records;

  //================================================================

  //----------------------------------------------------------------
  /// The names of the properties.

  Iterable<String> get propertyNames => _propertyNames;

  //----------------------------------------------------------------
  /// The records.

  Iterable<Record> get records => _records;

  //----------------------------------------------------------------
  /// Sort the records using the sort properties.

  void sort(Iterable<String> sortProperties) {
    if (sortProperties.isNotEmpty) {
      // Perform sorting (putting empty values at the end)

      _records.sort((a, b) {
        for (final propertyName in sortProperties) {
          final v1 = a[propertyName];
          final v2 = b[propertyName];

          if (v1.isNotEmpty && v2.isNotEmpty) {
            final c = v1.compareTo(v2);
            if (c != 0) {
              return c;
            }
          } else if (v1.isNotEmpty) {
            return -1; // v2 is empty
          } else if (v2.isNotEmpty) {
            return 1; // v1 is empty
          }
        } // all sort properties

        return 0; // equal
      });
    }
  }
}