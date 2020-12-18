part of csv_data;

//################################################################

class PropertyNotInDataException implements Exception {
  PropertyNotInDataException(this.propertyName);

  final String propertyName;

  @override
  String toString() => 'Property in template, but not in data: $propertyName';
}

//################################################################
/// Indicates an enumeration is missing a value.

class NoEnumeration {
  NoEnumeration(this.propertyName, this.value);

  final String propertyName;
  final String value;
}

//################################################################

class Formatter {
  //================================================================

  Formatter(this._template,
      {this.includeRecords = true,
      this.includeRecordsContents = true,
      this.includeProperties = true,
      this.includePropertiesIndex = true});

  //================================================================

  /// Show the records (and maybe the table of contents).

  final bool includeRecords;

  /// Show the table of contents (only if [includeRecords] is also true).

  final bool includeRecordsContents;

  /// Show the properties (and maybe the index of properties).

  final bool includeProperties;

  /// Show the index of properties (only if [includeProperties] is also true).

  final bool includePropertiesIndex;

  /// The template to interpret the CSV data.

  final RecordTemplate _template;

  //================================================================

  //----------------------------------------------------------------
  /// Produce HTML.
  ///
  /// Format the [data] as HTML and write the HTML to [buf].
  ///
  /// The [defaultTitle] will be used as the title, if the template does not
  /// have a title.
  ///
  /// If a value for [timestamp] is provided, the footer shows it. Usually,
  /// the caller can pass in the last modified date of the CSV data as the
  /// timestamp to display.

  List<NoEnumeration> toHtml(CsvData data, String defaultTitle, IOSink buf,
      {DateTime? timestamp}) {
    final propertyId = _checkProperties(data);

    data.sort(_template.sortProperties); // sort the records

    final warnings = <NoEnumeration>[];

    // Generate HTML

    _showHead(buf, defaultTitle);

    if (includeRecords) {
      if (includeRecordsContents) {
        _showRecordContents(data, buf);
      }

      _showRecords(data, propertyId, buf, warnings);
    }

    if (includeProperties) {
      _showProperties(data, propertyId, buf, warnings);
      if (includePropertiesIndex) {
        _propertiesIndex(data, propertyId, buf);
      }
    }

    _showFooter(timestamp, buf);

    return warnings;
  }

  //----------------
  /// Assign IDs to all the properties.
  ///
  /// Returns a map from property name to property ID.
  ///
  /// Also checks if all the properties in the template's items appear in the
  /// [data]. Throws a [PropertyNotInDataException] if the template refers to
  /// a property that doesn't exist in the data.
  ///
  /// The IDs will be used as fragment identifiers in the HTML.

  Map<String, String> _checkProperties(CsvData data) {
    // Assign identifiers to each property name

    final propertyId = <String, String>{};
    var count = 0;
    for (final name in data.propertyNames) {
      count++;
      propertyId[name] = 'p$count';
    }

    // Check all template items refer to properties that exist in the data

    for (final item in _template.items) {
      if (item is TemplateItemScalar) {
        if (!propertyId.containsKey(item.propertyName)) {
          throw PropertyNotInDataException(item.propertyName);
        }
      } else if (item is TemplateItemGroup) {
        for (final m in item.members) {
          if (!propertyId.containsKey(m.propertyName)) {
            throw PropertyNotInDataException(m.propertyName);
          }
        }
      } else if (item is TemplateItemIgnore) {
        if (!propertyId.containsKey(item.propertyName)) {
          throw PropertyNotInDataException(item.propertyName);
        }
      } else {
        assert(false, 'unexpected class: ${item.runtimeType}');
      }
    }

    // Check sort properties all exist in the data

    for (final name in _template.sortProperties) {
      if (!data.propertyNames.contains(name)) {
        TemplateException(0, 'sort property not in data: $name');
      }
    }

    // Check identifier properties all exist in the data

    for (final name in _template.identifierProperties) {
      if (!data.propertyNames.contains(name)) {
        TemplateException(0, 'identifier property not in data: $name');
      }
    }

    // Return map from property name to property ID

    return propertyId;
  }

  //----------------

  void _showHead(IOSink buf, String defaultTitle) {
    final title = _template.title.isNotEmpty ? _template.title : defaultTitle;

    buf.write('''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">

<style type="text/css">

body {
  font-family: Calibri, Helvetica, sans-serif;
}

p.subtitle {
  margin: 0;
  font-size: larger;
  font-weight: bold;
}

a {
  text-decoration: none;
  color: inherit;
}

a:hover {
  text-decoration: underline;
  color: blue;
}

div.toc {
  margin: 4ex 0;
}
.toc table {
  border-collapse: collapse;
}
.toc tr:hover {
  background: #eee;
}

div.record {
  margin: 2ex 0 4ex 0;
}
span.projectName {
  font-size: smaller;
}
span.gp {
  color: #666;
}
span.gp::after { content: ": " }

.properties table {
  border-collapse: collapse;
}
.properties tr:hover {
  background: #eee;
}
h3.unused::before { content: 'Unused property: ' }

h3.unexpected::before { content: 'Property not in template: ' }

th {
  white-space: nowrap;
  vertical-align: top;
  text-align: right;
  padding-right: 0.5em;
  font-weight: normal;
  color: #666;
}

p.timestamp {
  margin: 4ex 0;
  text-align: center;
  font-size: smaller;
  color: #666;
}

@media print {
  div.toc {page-break-after: always;}
  div.record {page-break-after: always;}
}

</style>

</head>

<body>

<header>
<h1>${hText(title)}</h1>
''');

    if (_template.subtitle.isNotEmpty) {
      buf.write('<p class="subtitle">${hText(_template.subtitle)}</p>\n');
    }

    buf.write('</header>\n\n');
  }

  //----------------------------------------------------------------

  void _showRecordContents(CsvData records, IOSink buf) {
    // Table of contents

    buf.write('<div class="toc">\n<h2>Contents</h2>\n<table>\n');

    for (final entry in records.records) {
      buf.write('<tr>');
      _showIdentitiesInTd(entry, buf);
      buf.write('</tr>\n');
    }

    buf.write('</table>\n</div>\n\n');
  }

  //----------------

  void _showIdentitiesInTd(Record record, IOSink buf) {
    for (final property in _template.identifierProperties) {
      final value = record[property];
      final valueHtml = (value.isNotEmpty) ? hText(value) : '&mdash;';

      buf.write('<th>');
      if (includeRecords) {
        buf.write('<a href="#${record.identifier}">$valueHtml</a></th>\n');
      } else {
        buf.write(valueHtml);
      }
      buf.write('</th>\n');
    }
  }

  //----------------------------------------------------------------

  void _showRecords(CsvData records, Map<String, String> propertyId, IOSink buf,
      List<NoEnumeration> warnings) {
    // Records

    buf.write('<h2>Records</h2>\n\n');

    for (final entry in records.records) {
      _showRecord(entry, propertyId, buf, warnings);
    }

    buf.write('</table>\n</div>\n\n');
  }

  //----------------

  void _showRecord(Record record, Map<String, String> propertyId, IOSink buf,
      List<NoEnumeration> warnings) {
    // Heading

    var hasHeadingValue = false;

    buf.write('<div class="record" id="${record.identifier}">\n');

    buf.write('<h3>');
    for (var x = 0; x < _template.identifierProperties.length - 1; x++) {
      final preTitle = record[_template.identifierProperties[x]];
      if (preTitle.isNotEmpty) {
        buf.write('<span class="projectName">${hText(preTitle)}</span><br>\n');
        hasHeadingValue = true;
      }
    }
    final mainTitle = record[_template.identifierProperties.last];
    if (mainTitle.isNotEmpty) {
      buf.write(hText(mainTitle));
      hasHeadingValue = true;
    }

    if (!hasHeadingValue) {
      buf.write('(Untitled)');
    }
    buf.write('</h3>\n');

    // Entry data

    buf.write('<table>\n');

    for (final item in _template.items) {
      if (item is TemplateItemScalar) {
        _showRecordSingular(item, record, propertyId, buf, warnings);
      } else if (item is TemplateItemGroup) {
        _showRecordGroup(item, record, propertyId, buf);
      } else if (item is TemplateItemIgnore) {
        // ignore
      }
    }

    buf.write('</table>\n</div>\n\n');
  }

  //----------------

  void _showRecordSingular(
      TemplateItemScalar item,
      Record record,
      Map<String, String> propertyId,
      IOSink buf,
      List<NoEnumeration> warnings) {
    final value = record[item.propertyName];

    if (value.isNotEmpty) {
      // Property name

      buf.write('<tr><th>');

      if (includeProperties) {
        final id = propertyId[item.propertyName];
        buf.write('<a href="#$id">${hText(item.displayText)}</a>');
      } else {
        buf.write(hText(item.displayText));
      }
      buf.write('</th>');

      _value(item.propertyName, value, item.enumerations, buf, warnings);

      buf.write('</tr>\n');
    }
  }

  void _value(
      String propertyName,
      String value,
      Map<String, String>? enumerations,
      IOSink buf,
      List<NoEnumeration> warnings) {
    var displayValue = value;
    String? title;
    if (enumerations != null && value.isNotEmpty) {
      if (enumerations.containsKey(value)) {
        displayValue = enumerations[value]!;
        title = value;
      } else {
        warnings.add(NoEnumeration(propertyName, value));
      }
    }

    buf.write('<td${title != null ? ' title="${hAttr(title)}"' : ''}>'
        '${hText(displayValue)}</td>');
  }
  //----------------

  void _showRecordGroup(TemplateItemGroup item, Record entry,
      Map<String, String> propertyId, IOSink buf) {
    var started = false;

    for (final member in item.members) {
      final value = entry[member.propertyName];

      if (value.isNotEmpty) {
        if (!started) {
          buf.write('<tr><th>${hText(item.displayText)}</th>\n<td>');
          started = true;
        }

        if (member.displayText.isNotEmpty) {
          buf.write('<span class="gp">');

          if (includeProperties) {
            final id = propertyId[member.propertyName];
            buf.write('<a href="#$id">${hText(member.displayText)}</a>');
          } else {
            buf.write(hText(member.displayText));
          }

          buf.write('</span>');
        }

        var displayValue = value;
        if (member.enumerations != null) {
          if (member.enumerations!.containsKey(value)) {
            displayValue = member.enumerations![value]!;
            buf.write('<span>${hText(displayValue)}</span>: ');
          }
        }

        buf.write('<span>${hText(displayValue)}</span><br>\n');
      }
    }

    if (started) {
      buf.write('</td>\n</tr>\n');
    }
  }

  //----------------------------------------------------------------

  void _showProperties(CsvData records, Map<String, String> propertyId,
      IOSink buf, List<NoEnumeration> warnings) {
    // Dump properties used in the template items

    buf.write('<div class="properties">\n<h2>Properties</h2>\n\n');

    final usedColumns = <String>{};

    for (final item in _template.items) {
      if (item is TemplateItemScalar) {
        _propertySimple(
            item, propertyId, records.records, buf, usedColumns, warnings);
      } else if (item is TemplateItemGroup) {
        _propertyGroup(
            item, propertyId, records.records, buf, usedColumns, warnings);
      } else if (item is TemplateItemIgnore) {
        _propertyUnused(
            item, propertyId, records.records, buf, usedColumns, warnings);
      } else {
        assert(false, 'unexpected class: ${item.runtimeType}');
      }
    }

    // Dump properties not in the template items

    for (final propertyName in records.propertyNames) {
      if (!usedColumns.contains(propertyName)) {
        final id = propertyId[propertyName]!;
        buf.write('<h3 id="${hAttr(id)}" class="unexpected">'
            '${hText(propertyName)}</h3>\n<table>\n');

        for (final entry in records.records) {
          final value = entry[propertyName];
          if (value.isNotEmpty) {
            buf.write('<tr>');
            _showIdentitiesInTd(entry, buf);
            buf.write('<td>${hText(value)}</td></tr>\n');
          }
        }
        buf.write('</table>\n\n');
      }
    }

    buf.write('</div> <!-- properties -->\n');
  }

  //----------------

  void _propertySimple(
      TemplateItemScalar item,
      Map<String, String> propertyId,
      Iterable<Record> records,
      IOSink buf,
      Set<String> usedColumns,
      List<NoEnumeration> warnings) {
    final id = propertyId[item.propertyName]!;
    buf.write('<div class="property">\n'
        '</div><h3 id="${hAttr(id)}">${hText(item.propertyName)}</h3>\n');

    buf.write('<table>\n');

    for (final entry in records) {
      buf.write('<tr>');
      _showIdentitiesInTd(entry, buf);
      _value(item.propertyName, entry[item.propertyName], item.enumerations,
          buf, warnings);
      buf.write('</tr>\n');
    }

    buf.write('</table>\n'
        '</div>\n\n');

    usedColumns.add(item.propertyName);
  }

  //----------------

  void _propertyGroup(
      TemplateItemGroup item,
      Map<String, String> propertyId,
      Iterable<Record> records,
      IOSink buf,
      Set<String> usedColumns,
      List<NoEnumeration> warnings) {
    for (final member in item.members) {
      _propertySimple(member, propertyId, records, buf, usedColumns, warnings);
    }
  }

  //----------------

  void _propertyUnused(
      TemplateItemIgnore item,
      Map<String, String> propertyId,
      Iterable<Record> records,
      IOSink buf,
      Set<String> usedColumns,
      List<NoEnumeration> warnings) {
    final id = propertyId[item.propertyName]!;
    buf.write('<div class="property">\n'
        '<h3 id="${hAttr(id)}" class="unused">${hText(item.propertyName)}</h3>\n');

    buf.write('<table>\n');

    for (final entry in records) {
      buf.write('<tr>');
      _showIdentitiesInTd(entry, buf);
      _value(item.propertyName, entry[item.propertyName], item.enumerations,
          buf, warnings);
      buf.write('</tr>\n');
    }

    buf.write('</table>\n</div>\n\n');

    usedColumns.add(item.propertyName);
  }

  void _propertiesIndex(
      CsvData data, Map<String, String> propertyId, IOSink buf) {
    if (includePropertiesIndex) {
      // Property index

      final orderedPropertyNames = data.propertyNames.toList()..sort();

      buf.write('\n<div class="index"><h2>Index</h2>\n<ol>\n');
      for (final v in orderedPropertyNames) {
        final id = propertyId[v]!;
        buf.write('<li><a href="#${hAttr(id)}">${hText(v)}</a></li>\n');
      }
      buf.write('</ol>\n</div>\n\n');
    }
  }

  //----------------------------------------------------------------

  void _showFooter(DateTime? timestamp, IOSink buf) {
    // Visible footer

    buf.write('<footer>\n');

    if (timestamp != null) {
      final ts = timestamp.toIso8601String().substring(0, 10);
      buf.write('<p class="timestamp">${hText(ts)}</p>\n');
    }

    buf.write('''
</footer>

</body>
</html>

<!--
''');

    // Hidden timestamps

    if (timestamp != null) {
      buf.write('timestamp: ${hText(timestamp.toUtc().toIso8601String())}\n');
    }

    buf.write('''
generated: ${hText(DateTime.now().toUtc().toIso8601String())}
-->
''');
  }

  //================================================================
  // Escape functions for HTML

  static final _htmlEscapeText = HtmlEscape(HtmlEscapeMode.element);
  static final _htmlEscapeAttr = HtmlEscape(HtmlEscapeMode.attribute);

  /// Escape string for use in HTML attributes

  static String hText(String s) => _htmlEscapeText.convert(s);

  /// Escape string for use in HTML content

  static String hAttr(String s) => _htmlEscapeAttr.convert(s);
}
