# CSV to HTML converter

Converts records from a Comma Separated Variables (CSV) file into HTML.

## Installing

This program is written in [Dart](https://dart.dev).

To run it using the Dart interpreter, install the Dart SDK and run:

```sh
dart pub get
dart bin/csv2html.dart
```

To compile it into a native binary, install the Dart SDK and run:

```sh
dart pub get
dart compile exe bin/csv2html.dart
```

Pre-compiled native binaries may be available on the project's GitHub
repository under [releases](https://github.com/qcif/csv2html/releases).

## Usage

```sh

csv2html [options] csv-data.csv

```

Options:

- `-o` or `--output` file to write generated HTML to (default: writes to stdout).

- `-t` or `--template` properties in a record.

- `--no-records` do not include the records and the table of contents.

- `--no-contents` do not include the table of contents of the records.

- `--no-properties` do not include the properties and the index of properties.

- `--no-index` do not include the index of properties.

- `-q` or `--quiet` do not print out warnings.

- `-h` or `--help`  show a brief help message and exits.


## Overview

### Data input

The data in the CSV file is treated as a sequence of records, where
each record has a set of property values. Rows are records; columns
are properties.

The first row contains the **property names**. The fields in the
column under the property name, are the **property values**.  All
fields in the first row must contain a value (i.e. a property name
cannot be empty).

Each subsequent row is a **record**. The fields in a record row are
the _property values_ for the corresponding property of the record.
If a record row contains fewer fields than the number of property
names, the remaining property values are assigned the empty
string. Record rows cannot contain more fields than the number of
properties named in the first row.

All fields are treated as strings, with leading and trailing
whitespace removed.

### HTML output

The HTML produced contains to main sections: records and properties.

The records show every record from the input data. That is, the values
from a row in the input CSV. By default, a table of contents is shown
before the records, with links to each of the records.

The properties show every property from the input data. That is, the
values from a column in the input CSV. By default, an index of the
properties is shown after the properties, with links to each of the
properties.

## Templates

The template defines which properties are included in the record, and
how they are displayed.

The template is specified by a CSV file with four columns:

- display text;
- property name;
- enumeration; and
- notes.

The first row in the template CSV is ignored.

Template items are defined by the other rows. There are scalars,
groups and special items. The order in which the items appear in the
template is the order in which they are shown in the record.

The notes column is always ignored.

It is an error to have a property name that does not appear in the
data file.

A warning will be given for properties that appear in the data but not
in the template. The warning can be suppressed by specifying in the
template that the property is unused.

### Template items

#### Scalars

A scalar is a template item for displaying a single property.

It is specified by a row with non-blank property name. The display
text and property name cannot be one of the special values described
below.

It maps a property name into the display text for the property's
label.  The display text can be empty: usually used for sub-properties
of a group to not display any sub-label for the property.

```
Project identifier,  id
```

If there is an enumeration, it is used to map the property values into
text that appears for the property's value.

The enumeration field contains a set of semicolon separated key-value
pairs, where the key and value are separated by an equal sign.

```
Machine status,  status,  0=off; 1=sleep ;2=on
```

Only scalar items and ignored properties can have an enumeration.

#### Groups

A group is a template item for displaying multiple properties
together. The properties in the group are shown with sub-labels under
a single group label.

It is specified by a row with a non-blank display text and a blank
property name. The display text is used as the group label.
Scalar items in the following rows are members of the group.
The group is terminated by an empty row (a row where all the
fields are blank).

```
Location
Building name,bldg
Street Address,address
Suburb,suburb
,,
```

#### Title

If the property name has the special value of "#TITLE", the display text
is used as the HTML document's title.

```
This text is the title,  #TITLE
```

#### Subtitle

If the property name has the special value of "#SUBTITLE", the display
text is used as the HTML document's subtitle.

```
This text is the subtitle,  #SUBTITLE
```

#### Sort

If the display text has the special value of "#SORT", the property name is
used to order the records. Multiple sort properties can be specified using
multiple sort rows.

```
#SORT,  title
#SORT,  subtitle
```

If no sort properties are defined in the template, the records are ordered
in the same order as the rows in the CSV file.

#### Identifiers

If the display text has the special value of "#IDENTIFIER", the
property name is used for the link to the record (e.g. in the table of
contents). Multiple identifiers can be specified using multiple
identifier rows.

```
#IDENTIFIER,  title
```

If no identifiers are defined in the template, the first scalar
property in the template is used as the identifier.

#### Unused properties

If the display text has the special value of "#UNUSED", the
named property is not displayed in the records.

```
#UNUSED,  code
#UNUSED,  timestamp
```

However, it will still appear in the variables section.  Also, any
properties that are not mentioned in the template produce a warning
and are included in the variables section.

### Example template

A simple example template:

```
Display text,   Property,       Enumeration,    Notes

My Books,       #TITLE
An example,     #SUBTITLE

#SORT,          title
#SORT,          subtitle

#IDENTIFIER,    title

Book title,     title
Subtitle,       subtitle

Author,         ,               ,               Start of a group
Given name,     author_givenname
Family name,    author_familyname

ISBN,           isbn
Publisher,      publisher_name
Format,         format,         , hc=Hard cover;pb=Paperback
#UNUSED,        id
#UNUSED,        timestamp
```

See the _examples_ directory for another example.


### Default template

If no template is supplied, a default template is used.

The default template contains a scalar item for every property, with
the display text being the same as the property name.  They appear in
the same order as the property names appear in the first line of the
CSV.
