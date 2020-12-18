#!/usr/bin/env dart --no-sound-null-safety
// Pretty prints CSV into HTML.

import 'dart:io';

// ignore: import_of_legacy_library_into_null_safe
import 'package:args/args.dart';

// ignore: import_of_legacy_library_into_null_safe
import 'package:path/path.dart' as p;

import 'package:csv2html/csv_data.dart';

final _name = 'csv2html';
final _version = '1.0.0';

//################################################################
/// Configuration

class Config {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Create config from parsing command line arguments.

  factory Config.parse(List<String> args) {
    try {
      const _oParamTemplate = 'template';
      const _oParamOutput = 'output';

      const _oParamIncludeRecords = 'records';
      const _oParamIncludeRecordsContents = 'contents';
      const _oParamIncludeProperties = 'properties';
      const _oParamIncludePropertiesIndex = 'index';

      const _oParamQuiet = 'quiet';
      const _oParamVersion = 'version';
      const _oParamHelp = 'help';

      final parser = ArgParser(allowTrailingOptions: true)
        ..addOption(_oParamTemplate,
            abbr: 't', help: 'template', valueHelp: 'FILE')
        ..addOption(_oParamOutput,
            abbr: 'o', help: 'output file', valueHelp: 'FILE')
        ..addFlag(_oParamIncludeRecords,
            help: 'include records', negatable: true, defaultsTo: true)
        ..addFlag(_oParamIncludeRecordsContents,
            help: 'include contents of records',
            negatable: true,
            defaultsTo: true)
        ..addFlag(_oParamIncludeProperties,
            help: 'include properties', negatable: true, defaultsTo: true)
        ..addFlag(_oParamIncludePropertiesIndex,
            help: 'include index of properties',
            negatable: true,
            defaultsTo: true)
        ..addFlag(_oParamVersion,
            help: 'display version information and exit', negatable: false)
        ..addFlag(_oParamQuiet,
            abbr: 'q', help: 'do not show warnings', negatable: false)
        ..addFlag(_oParamHelp,
            abbr: 'h', help: 'display this help and exit', negatable: false);

      final results = parser.parse(args);

      // ignore: avoid_as
      if (results[_oParamHelp] as bool) {
        stdout.write('Usage: $_name [options]\n${parser.usage}\n');
        exit(0);
      }

      // ignore: avoid_as
      if (results[_oParamVersion] as bool) {
        stdout.write('$_name $_version\n');
        exit(0);
      }

      // ignore: avoid_as
      final incRecords = results[_oParamIncludeRecords] as bool;

      // ignore: avoid_as
      final incRecordsContents = results[_oParamIncludeRecordsContents] as bool;

      // ignore: avoid_as
      final incProperties = results[_oParamIncludeProperties] as bool;

      // ignore: avoid_as
      final incPropertiesIndex = results[_oParamIncludePropertiesIndex] as bool;

      // ignore: avoid_as
      final quiet = results[_oParamQuiet] as bool;

      // Template

      final templateFilename = results[_oParamTemplate] as String;

      final outFile = results[_oParamOutput] as String;

      // Data filename

      String dataFilename;

      final rest = results.rest;
      if (rest.isEmpty) {
        stderr.write('$_name: missing CSV data filename (-h for help)\n');
        exit(2);
      } else if (rest.length == 1) {
        dataFilename = rest.first;
      } else {
        stderr.write('$_name: too many arguments\n');
        exit(2);
      }

      // Title

      return Config._(dataFilename, templateFilename, outFile,
          includeRecords: incRecords,
          includeRecordsContents: incRecordsContents,
          includeProperties: incProperties,
          includePropertiesIndex: incPropertiesIndex,
          quiet: quiet);
    } on FormatException catch (e) {
      stderr.write('$_name: usage error: ${e.message}\n');
      exit(2);
    }
  }

  //----------------------------------------------------------------

  Config._(this.dataFilename, this.templateFilename, this.outFilename,
      { this.includeRecords,
       this.includeRecordsContents,
       this.includeProperties,
       this.includePropertiesIndex,
       this.quiet});

  //================================================================
  // Members

  /// CSV filename
  final String dataFilename;

  /// Optional template filename
  final String templateFilename;

  /// Optional output filename
  final String outFilename;

  final bool includeRecords;

  final bool includeRecordsContents;

  final bool includeProperties;

  final bool includePropertiesIndex;

  /// Quiet mode
  final bool quiet;
}

//################################################################

void main(List<String> arguments) {
  // Parse command line

  final config = Config.parse(arguments);

  try {
    // Load

    final data = CsvData.load(File(config.dataFilename).readAsStringSync());

    final defaultTitle = p.split(config.dataFilename).last;

    RecordTemplate template;

    final tName = config.templateFilename;
    if (tName != null) {
      final f = File(tName);
      template = RecordTemplate.load(f.readAsStringSync());
    } else {
      template = RecordTemplate(data);
    }

    // Output destination

    final outFile = config.outFilename;
    final out = (outFile != null) ? File(outFile).openWrite() : stdout;

    // Process

    final fmt = Formatter(template,
        includeRecords: config.includeRecords,
        includeRecordsContents: config.includeRecordsContents,
        includeProperties: config.includeProperties,
        includePropertiesIndex: config.includePropertiesIndex);

    final warnings = fmt.toHtml(data, defaultTitle, out,
        timestamp: File(config.dataFilename).lastModifiedSync());

    // Show warnings

    if (!config.quiet) {
      final unused = template.unusedProperties(data).toList()..sort();
      for (final name in unused) {
        stderr.write('Warning: property not in template: $name\n');
      }

      for (final w in warnings) {
        stderr.write('Warning: property "${w.propertyName}"'
            ': no enumeration for value: "${w.value}"\n');
      }
    }

    out.close();
  } on CsvDataException catch (e) {
    stderr.write('Error: ${config.dataFilename}: $e\n');
    exit(1);
  } on TemplateException catch (e) {
    stderr.write('Error: ${config.templateFilename}: $e\n');
    exit(1);
  } on PropertyNotInDataException catch (e) {
    stderr.write('Error: ${config.templateFilename}: $e\n');
    exit(1);
  }
}
