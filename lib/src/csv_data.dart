part of csv_data;

//################################################################
/// Exception thrown when the CSV data is not valid.

class CsvDataException implements Exception {
  CsvDataException(this.lineNum, this.message);

  /// Line in the CSV that contains the problem.
  final int lineNum;

  /// Description of the problem.
  final String message;

  @override
  String toString() => 'line $lineNum: $message';
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

  factory CsvData.load(String csvText) {
    // Parse the CSV
    //
    // CSV package's detection of eol is unreliable, so do our own handling
    // of CR-LF and treat everything as LF.

    final data = CsvToListConverter(
            eol: '\n', shouldParseNumbers: false, allowInvalid: false)
        .convert(csvText.replaceAll('\r\n', '\n'));

    final propertyNames = <String>[];
    final records = <Record>[];

    if (data.isEmpty) {
      throw CsvDataException(1, 'missing header row');
    }

    // Extract property names from the header row

    final values = <String>[]; // first: get trimmed string values
    for (final v in data.first.map((s) => s.trim())) {
      if (v is String) {
        values.add(v);
      } else {
        // This should never happen
        assert(false, 'property name is not a string');
      }
    }

    var column = 0; // second: use the non-blank values as names
    while (column < values.length) {
      final name = values[column];
      if (name.isNotEmpty) {
        propertyNames.add(name);
      } else {
        // Some CSV exports put blank values at the end of a row
        // A blank value is only an error if there are non-blank fields after it
        for (var x = column + 1; x < values.length; x++) {
          if (values[x].isNotEmpty) {
            throw CsvDataException(1, 'column $column: blank property name');
          }
        }
      }
      column++;
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

    var lineNum = 1; // skipping header row
    for (final row in data.getRange(1, data.length)) {
      lineNum++;

      final record = Record(lineNum);
      var hasValue = false;

      // Assign fields to property values

      var index = 0;

      while (index < row.length && index < propertyNames.length) {
        final value = row[index].trim();

        record[propertyNames[index]] = value;
        index++;

        hasValue |= value.isNotEmpty;
      }

      // If there are extra fields, they must all be blank

      while (index < row.length) {
        if (row[index].trim().isNotEmpty) {
          throw CsvDataException(
              lineNum, 'column ${index + 1}: more fields than properties');
        }
        index++;
      }

      // Only include the record if it has some value(s) in it.
      // That is, ignore rows where all the fields are blank (e.g. blank lines)

      if (hasValue) {
        records.add(record);
      }
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
