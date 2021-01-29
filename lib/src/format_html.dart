part of csv_data;

//################################################################

class PropertyNotInDataException implements Exception {
  PropertyNotInDataException(this.propertyName);

  final String propertyName;

  @override
  String toString() =>
      'property from template is not in the data: $propertyName';
}

//################################################################
/// Indicates an enumeration is missing a value.

class NoEnumeration {
  NoEnumeration(this.propertyName, this.value);

  final String propertyName;
  final String value;

  @override
  String toString() =>
      'Property "$propertyName" enumeration missing value for "$value"';
}

//################################################################

enum PropertyState { usedInRecord, other, hidden }

const _cssClassNormalProperty = 'normal-property';
const _cssClassOtherProperty = 'other-property';
const _cssClassHiddenProperty = 'hidden-property';
const _cssClassUnexpectedProperty = 'unexpected-property';

const stateClass = {
  PropertyState.usedInRecord: _cssClassNormalProperty,
  PropertyState.other: _cssClassOtherProperty,
  PropertyState.hidden: _cssClassHiddenProperty
};

//################################################################

class _PropInfo {
  Map<String, PropertyState> useStates = {};
  Map<String, bool> hasSummary = {};
}

//################################################################

class Formatter {
  //================================================================

  Formatter(this._template,
      {this.excludeOther = false, this.includeHidden = false});

  //================================================================

  /// The template to interpret the CSV data.

  final Template _template;

  /// Exclude other properties.
  ///
  /// The properties marked as _OTHER are not a part of the records, but they
  /// are normally included in the property section. If this member is true,
  /// they are excluded (i.e. they behave similar to _HIDE).

  final bool excludeOther;

  /// Include hidden properties.
  ///
  /// The properties marked as _HIDE are not a part of the records, and they
  /// are normally not included in the property section. If this member is true,
  /// they are included in the property section (i.e. they behave similar to
  /// _OTHER).

  final bool includeHidden;

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

  List<NoEnumeration> toHtml(
      CsvData data, String defaultTitle, String programVersion, IOSink buf,
      {DateTime timestamp}) {
    final propertyIds = _generatePropertyIds(data);

    data.sort(_template.sortProperties); // sort the records

    final warnings = <NoEnumeration>[];

    // Generate HTML

    _showHead(buf, defaultTitle, programVersion, timestamp: timestamp);

    if (_template.showRecords) {
      if (_template.showRecordsContents) {
        _showRecordContents(data, buf);
      }
      _showRecords(data, propertyIds, buf, warnings);
    }

    if (_template.showProperties) {
      final propInfo = _showProperties(data, propertyIds, buf, warnings);

      if (_template.showPropertiesIndex) {
        _propertiesIndex(data, propertyIds, propInfo, buf);
      }
    }

    _showFooter(buf, timestamp: timestamp);

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

  Map<String, String> _generatePropertyIds(CsvData data) {
    // Assign identifiers to each property name

    final propertyId = <String, String>{};
    var count = 0;
    for (final name in data.propertyNames) {
      count++;
      propertyId[name] = 'p$count';
    }

    // Check all template items refer to properties that exist in the data

    for (final item in _template.items) {
      if (item is TemplateItemProperty) {
        if (!propertyId.containsKey(item.propertyName)) {
          throw PropertyNotInDataException(item.propertyName);
        }
      } else if (item is TemplateItemGroup) {
        for (final m in item.members) {
          if (!propertyId.containsKey(m.propertyName)) {
            throw PropertyNotInDataException(m.propertyName);
          }
        }
      } else {
        assert(false, 'unexpected class: ${item.runtimeType}');
      }
    }

    // Check sort properties all exist in the data

    for (final name in _template.sortProperties) {
      if (!data.propertyNames.contains(name)) {
        TemplateException('sort property not in data: $name');
      }
    }

    // Check identifier properties all exist in the data

    for (final name in _template.identifierProperties) {
      if (!data.propertyNames.contains(name)) {
        TemplateException('identifier property not in data: $name');
      }
    }

    // Return map from property name to property ID

    return propertyId;
  }

  //----------------

  void _showHead(IOSink buf, String defaultTitle, String programVersion,
      {DateTime timestamp}) {
    final title = _template.title.isNotEmpty ? _template.title : defaultTitle;

    final _timestamp = timestamp != null
        ? 'timestamp: ${hText(timestamp.toUtc().toIso8601String().substring(0, 19))}Z\n'
        : '';

    buf.write('''
<!DOCTYPE html>

<!--
generator: csv2html $programVersion <https://github.com/qcif/csv2html>
generated: ${hText(DateTime.now().toUtc().toIso8601String().substring(0, 19))}Z
$_timestamp-->

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
span.groupProp {
  color: #666;
}
span.groupProp::after { content: ": " }

div.other > h3:after {
  content: " (other property)";
  color: green;
}
div.hide > h3:after {
  content: " (hidden property)";
  color: orange;
}
div.unexpected > h3:after {
  content: " (unexpected property)";
  color: red;
}

.properties table {
  border-collapse: collapse;
}
.properties tr:hover {
  background: #eee;
}
h3.unused::before { content: 'Unused property: ' }

th {
  white-space: nowrap;
  vertical-align: top;
  text-align: right;
  padding-right: 0.5em;
  font-weight: normal;
  color: #666;
}

/* Property summaries */

div.property > h3 {}
div.$_cssClassNormalProperty > h3 {}
div.$_cssClassOtherProperty > h3::after { content: " (not used in records)"; color: green; }
div.$_cssClassHiddenProperty > h3::after { content: " (hidden)"; color: orange; }
div.$_cssClassUnexpectedProperty > h3::after { content: " (not in template)"; color: red; }

/* Property index */

li.property {}
li.$_cssClassNormalProperty {}
li.$_cssClassOtherProperty { color: gray; }
li.$_cssClassHiddenProperty { color: orange; }
li.$_cssClassUnexpectedProperty { color: red; }

/* Footer */

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
      if (_template.showRecords) {
        buf.write('<a href="#${record.identifier}">$valueHtml</a>');
      } else {
        buf.write(valueHtml);
      }
      buf.write('</th>');
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
      if (item is TemplateItemActive) {
        _showRecordSingular(item, record, propertyId, buf, warnings);
      } else if (item is TemplateItemGroup) {
        _showRecordGroup(item, record, propertyId, buf);
      } else if (item is TemplateItemHide) {
        // ignore
      }
    }

    buf.write('</table>\n</div>\n\n');
  }

  //----------------

  void _showRecordSingular(
      TemplateItemActive item,
      Record record,
      Map<String, String> propertyId,
      IOSink buf,
      List<NoEnumeration> warnings) {
    final value = record[item.propertyName];

    if (value.isNotEmpty) {
      // Property name

      buf.write('<tr><th>');

      if (_template.showProperties) {
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
      Map<String, String> enumerations,
      IOSink buf,
      List<NoEnumeration> warnings) {
    var displayValue = value;
    String title;
    if (enumerations != null && value.isNotEmpty) {
      if (enumerations.containsKey(value)) {
        displayValue = enumerations[value];
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
      if (member is TemplateItemActive) {
        // Show property in the record
        final value = entry[member.propertyName];

        if (value.isNotEmpty) {
          if (!started) {
            buf.write('<tr><th>${hText(item.displayText)}</th>\n'
                '<td class="group">\n');
            started = true;
          }

          if (member.displayText.isNotEmpty) {
            buf.write('<span class="groupProp">');

            if (_template.showProperties) {
              final id = propertyId[member.propertyName];
              buf.write('<a href="#$id">${hText(member.displayText)}</a>');
            } else {
              buf.write(hText(member.displayText));
            }

            buf.write('</span>');
          }

          if (member.enumerations == null) {
            // No enumeration
            buf.write('<span>${hText(value)}</span><br>\n');
          } else {
            // Enumeration
            final displayValue = (member.enumerations.containsKey(value))
                ? member.enumerations[value]
                : value;

            buf.write('<span title="${hAttr(value)}">'
                '${hText(displayValue)}</span><br>\n');
          }
        }
      } // else is other or hidden: do not show property in the record
    }

    if (started) {
      buf.write('</td>\n</tr>\n');
    }
  }

  //----------------------------------------------------------------
  /// Produce the properties section.
  ///
  /// This shows a summary of the property values. First all the properties
  /// in the order they appear in the template (including other and hidden
  /// properties), and then treat any properties which were not in the template.

  _PropInfo _showProperties(CsvData records, Map<String, String> propertyIds,
      IOSink buf, List<NoEnumeration> warnings) {
    buf.write('<div class="properties">\n<h2>Properties</h2>\n\n');

    final propInfo = _PropInfo();

    List<NoEnumeration> warnings;

    // Summaries for all properties mentioned in the template

    for (final item in _template.items) {
      if (item is TemplateItemProperty) {
        // Display the property

        _propertySummaryForItem(
            item, records, propertyIds, buf, propInfo, warnings);
      } else if (item is TemplateItemGroup) {
        // Display all properties in the group

        for (final groupMember in item.members) {
          _propertySummaryForItem(
              groupMember, records, propertyIds, buf, propInfo, warnings);
        }
      } else {
        assert(false, 'unexpected class: ${item.runtimeType}');
      }
    }

    // Summaries for any properties not mentioned in the template

    for (final propertyName in records.propertyNames) {
      if (!propInfo.useStates.containsKey(propertyName)) {
        // Property has not been outputted (i.e. weren't referenced in template)

        _propertySummary(records, propertyIds, propertyName, null, '',
            _cssClassUnexpectedProperty, buf, warnings);

        propInfo.hasSummary[propertyName] = true;
      }
    }

    buf.write('</div> <!-- properties -->\n');

    return propInfo;
  }

  //----------------

  void _propertySummaryForItem(
      TemplateItemProperty item,
      CsvData records,
      Map<String, String> propertyIds,
      IOSink buf,
      _PropInfo propInfo,
      List<NoEnumeration> warnings) {
    // Determine what state the property is in

    PropertyState state;
    bool include;

    if (item is TemplateItemActive) {
      state = PropertyState.usedInRecord;
      include = true; // always include

    } else if (item is TemplateItemOther) {
      state = PropertyState.other;
      include = !excludeOther;
    } else {
      state = PropertyState.hidden;
      include = includeHidden;

      assert(item is TemplateItemHide);
    }

    propInfo.useStates[item.propertyName] = state;

    if (include) {
      _propertySummary(records, propertyIds, item.propertyName,
          item.enumerations, item.notes, stateClass[state], buf, warnings);
      propInfo.hasSummary[item.propertyName] = true;
    }
  }

  //----------------

  void _propertySummary(
      CsvData records,
      Map<String, String> propertyIds,
      String propertyName,
      Map<String, String> enumerations,
      String notes,
      String cssClass,
      IOSink buf,
      List<NoEnumeration> warnings) {
    final id = propertyIds[propertyName];

    buf.write('<div class="property $cssClass">\n'
        '<h3 id="${hAttr(id)}">${hText(propertyName)}</h3>\n');

    if (notes.isNotEmpty) {
      buf.write('<p class="notes">${hText(notes)}</p>\n');
    }
    buf.write('<table>\n');

    for (final entry in records._records) {
      buf.write('<tr>');
      _showIdentitiesInTd(entry, buf);
      _value(propertyName, entry[propertyName], enumerations, buf, warnings);
      buf.write('</tr>\n');
    }

    buf.write('</table>\n</div>\n\n');
  }

  //----------------

  void _propertiesIndex(CsvData data, Map<String, String> propertyId,
      _PropInfo propInfo, IOSink buf) {
    if (_template.showPropertiesIndex) {
      // Property index

      buf.write('\n<div class="index">\n'
          '<h2>Index</h2>\n'
          '<ol>\n');

      final orderedPropertyNames = data.propertyNames.toList()..sort();

      for (final v in orderedPropertyNames) {
        if (propInfo.hasSummary.containsKey(v)) {
          // Include entry in the index

          final cssClass = propInfo.useStates.containsKey(v)
              ? stateClass[propInfo.useStates[v]]
              : _cssClassUnexpectedProperty;

          buf.write('<li class="$cssClass">'
              '<a href="#${hAttr(propertyId[v])}">${hText(v)}</a></li>\n');
        }
      }
      buf.write('</ol>\n'
          '</div>\n\n');
    }
  }

  //----------------------------------------------------------------

  void _showFooter(IOSink buf, {DateTime timestamp}) {
    buf.write('<footer>\n');

    if (timestamp != null) {
      final ts = timestamp.toIso8601String().substring(0, 10);
      buf.write('<p class="timestamp">${hText(ts)}</p>\n');
    }

    buf.write('</footer>\n</body>\n</html>\n');
  }

  //================================================================
  // Escape functions for HTML

  static final _htmlEscapeText = HtmlEscape(HtmlEscapeMode.element);
  static final _htmlEscapeAttr = HtmlEscape(HtmlEscapeMode.attribute);

  /// Escape string for use in HTML attributes
  ///
  /// New lines U+000A and the Unicode "line separator" U+2028 character are
  /// represented as `<br>` line breaks.

  static String hText(String s) => _htmlEscapeText
      .convert(s)
      .replaceAll('\n', '<br>\n')
      .replaceAll('\u2028', '<br>\n');

  /// Escape string for use in HTML content

  static String hAttr(String s) => _htmlEscapeAttr.convert(s);
}
