# CSV to HTML converter

Formats a Comma Separated Variables (CSV) data file into HTML.  Each
row is a record and the columns are properties.  A template is used to
control how the records and properties are displayed.

See the _examples_ directory for an example generated HTML file.

## Installing

### Download binaries

Pre-compiled native binaries may be available on the project's GitHub
repository under [releases](https://github.com/qcif/csv2html/releases).

### Building from source

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

## Usage

```sh

csv2html [options] csv-data.csv

```

Options:

- `-o FILE` or `--output FILE` write generated HTML to named file (default: write to stdout).

- `-t FILE` or `--template FILE` specifies the template to use.

- `-e` or `--exclude-other` exclude other properties from property summary.

- `-i` or `--include-hidden` include hidden properties in property summary.

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

The HTML produced contains two main sections: records and properties.

The records section show every record from the input data. That is,
the values from a row in the input CSV. By default, a table of
contents is also shown before the records, with links to each of the
records.

The properties section show every property from the input data. That
is, the values from a column in the input CSV. By default, an index of
the properties is shown after the properties, with links to each of
the properties. By default, other properties (those indicated by
`_OTHER`) are included and hidden properties (those indicated by
`_HIDE`) are not: that behaviour can be changed by using command line
options.

## Templates

The template defines which properties are included in the record, and
how they are displayed.

The template is specified by a CSV file. The rows are either

- template items;
- commands; or
- comments

The first row in the template CSV is always ignored. This is for
consistency with how data files are processed.

In both template items and commands, it is an error to reference a
property name that does not appear in the data file.

All fields are treated as strings, with leading and trailing
whitespace removed.

### Template items

Rows for template items contain up to four columns, representing:

- display text;
- property name;
- enumeration; and
- notes.

The order in which the template items appear in the template is the
order in which they are shown in the record.

Templates should have a template item for every property in the data
file, or identify the property with either the _OTHER or _HIDE
commands.  A warning will be given for properties that appear in the
data but not in the template.

#### Scalars

A scalar is a template item for displaying a single property.

It is specified by a row with non-blank property name.

It maps the property name into the display text for the property's
label. The display text cannot start with an underscore (otherwise the
row will be treated as a command).

The display text can be empty. This only makes sense for
sub-properties of a group, so no sub-label is displayed for the
property.

```
Common name, cn
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

### Commands

Rows where the first column has a value that starts with a "_" are
treated as commands. The second colum will be used as the parameter to
the command.

#### _TITLE

The parameter is used as the HTML document's title.

```
_TITLE,My Books
```

#### _SUBTITLE

The parameter is used as the HTML document's subtitle.

```
_SUBTITLE,"Some books from my library"
```

#### _SORT

The parameter is used as a property used to order the
records.

```
_SORT,  title
_SORT,  subtitle
```

Multiple sort properties can be specified with multiple sort commands.
The records are sorted by the first sort property, with subsequent
sort properties used if the first values are equal.

If no sort properties are defined in the template, the records are ordered
in the same order as the rows in the CSV file.

#### _IDENTIFIER

The parameter is a property used for the link to the record (e.g. in
the table of contents).

```
_IDENTIFIER, title
```

Multiple identifiers can be specified with multiple identifier
commands. Each is displayed in its own column.

If no identifiers are defined in the template, the first scalar
property in the template is used as the identifier.

#### _OTHER

The property named in the parameter is not displayed in the records,
but is included in the properties section.

But it can be excluded from the properties section with the
`--exclude-other` command line option. That option makes this behave
like _HIDE.

```
_OTHER,  isbn
_OTHER,  dimensions
```

#### _HIDE

The property named in the paramater is not displayed at all (neither
in the records section or the properties section).

But it can be included in the properties section with the
`--include-hidden` command line option. That option makes this behave
like _OTHER.

```
_HIDE,  internal_price
```

This command is used to indicate the template knows about the
property, but is deliberately not displaying it in the record.

#### _SHOW

Semicolon separate list of one or more of these values:

- `records` - show the records
- `contents` - show the table of contents (only if `records` are shown)
- `properties` - show the properties
- `index` - show the index of properties (only if `properties` are shown)
- `all` - show all the above.

```
_SHOW, records;contents
```

If there is now _SHOW command, it is the same as showing "all".


### Comments

Rows where the value in the first column starts with a "#" are
comments. The entire comment row is ignored.

Note: empty rows are also ignored, except when they are used to
indicate the end of a group. Comment rows do not indicate the end of a
group.

### Example template

A simple example template:

```
Display text,   Property,       Enumeration,    Notes

# An example template

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

Publisher,      publisher_name
Format,         format,         , hc=Hard cover;pb=Paperback
_OTHER,         isbn
_OTHER,         dimensions
_HIDE,          internal_price
```

### Default template

If no template is supplied, a default template is generated from the
data.

The default template contains a scalar item for every property, with
the display text being the same as the property name.  They appear in
the same order as the property names appear in the first line of the
CSV.
