// Dev utility: convert the Kotlin/Android `strings.xml` catalogs into Flutter
// ARB files for `flutter gen-l10n`.
//
// This tool is intentionally kept OUTSIDE `lib/` so it never ships in the app,
// but it is still analyzer-clean (no `print`, all `final`) so `flutter analyze`
// of the whole package stays green.
//
// Run from the repo root:
//   dart run tool/xml_to_arb.dart
// Optional positional args:
//   dart run tool/xml_to_arb.dart <android-res-dir> <arb-out-dir>
//
// What it does, per the Phase-7 localization brief:
//   * parses `values/strings.xml` (en, the template) plus `values-de/-es/-it/-et`;
//   * converts snake_case resource names -> lowerCamelCase ARB keys
//     (deterministic, e.g. `metric_steps` -> `metricSteps`);
//   * converts Android positional format args `%1$s`/`%2$d`/`%3$f` (and the rare
//     bare `%s`/`%d`/`%.1f`) into ARB placeholders `{arg0}`, `{arg1}`, ... and
//     emits the matching `@key.placeholders` metadata with an inferred type
//     (String/int/double) in the en template;
//   * unescapes Android string escapes (`\'`, `\n`, `\"`, `\\`, `%%`->`%`); XML
//     entities (`&amp;`, `&#8226;`, ...) are already decoded by `package:xml`;
//   * converts `<plurals>` into ICU `{count, plural, ...}` (defensive: the
//     current catalogs contain none, but the path is implemented);
//   * for every en key missing from a non-en locale, falls back to the en value,
//     and if a translation's placeholder set is not a subset of the template's
//     it also falls back to en, so every ARB ends up with the same key set.
//
// Output: `lib/l10n/app_en.arb` (template, with metadata) and
// `app_de.arb`/`app_es.arb`/`app_it.arb`/`app_et.arb` (values only).

import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

/// ARB locale code -> Android `values*` directory name.
const Map<String, String> _localeDirs = <String, String>{
  'en': 'values',
  'de': 'values-de',
  'es': 'values-es',
  'it': 'values-it',
  'et': 'values-et',
};

const String _templateLocale = 'en';

void main(List<String> args) {
  final String resRoot = args.isNotEmpty
      ? args[0]
      : '/home/manu/Documents/repos/OpenVitals/app/src/main/res';
  final String outDir = args.length > 1 ? args[1] : 'lib/l10n';

  final Map<String, List<_Entry>> byLocale = <String, List<_Entry>>{};
  for (final MapEntry<String, String> e in _localeDirs.entries) {
    final File file = File('$resRoot/${e.value}/strings.xml');
    if (!file.existsSync()) {
      stderr.writeln('WARN: missing ${file.path}; skipping ${e.key}');
      continue;
    }
    byLocale[e.key] = _parseStrings(file.readAsStringSync());
  }

  final List<_Entry>? template = byLocale[_templateLocale];
  if (template == null) {
    stderr.writeln('FATAL: template locale "$_templateLocale" not found');
    exitCode = 1;
    return;
  }

  // Canonical, ordered key set comes from the en template.
  final List<String> orderedKeys =
      template.map((_Entry entry) => entry.key).toList();
  final Map<String, _Entry> templateByKey = <String, _Entry>{
    for (final _Entry entry in template) entry.key: entry,
  };

  Directory(outDir).createSync(recursive: true);

  int fallbackMissing = 0;
  int fallbackPlaceholderMismatch = 0;

  for (final String locale in _localeDirs.keys) {
    final List<_Entry>? entries = byLocale[locale];
    if (entries == null) continue;
    final Map<String, _Entry> byKey = <String, _Entry>{
      for (final _Entry entry in entries) entry.key: entry,
    };

    final Map<String, Object?> arb = <String, Object?>{'@@locale': locale};
    final bool isTemplate = locale == _templateLocale;

    for (final String key in orderedKeys) {
      final _Entry tmpl = templateByKey[key]!;
      _Entry chosen;
      if (isTemplate) {
        chosen = tmpl;
      } else {
        final _Entry? local = byKey[key];
        if (local == null) {
          fallbackMissing++;
          chosen = tmpl;
        } else if (!_placeholdersSubsetOf(local.argIndexes, tmpl.argIndexes)) {
          // Translation references a placeholder the template doesn't declare:
          // gen-l10n would reject it, so fall back to the (valid) en message.
          fallbackPlaceholderMismatch++;
          chosen = tmpl;
        } else {
          chosen = local;
        }
      }

      arb[key] = chosen.message;

      // Placeholder metadata lives only in the template file. Types come from
      // the template's own inference so the generated method signature is stable.
      if (isTemplate && tmpl.argIndexes.isNotEmpty) {
        final Map<String, Object?> placeholders = <String, Object?>{};
        final List<int> sorted = tmpl.argIndexes.toList()..sort();
        for (final int idx in sorted) {
          placeholders['arg$idx'] = <String, Object?>{
            'type': tmpl.argTypes[idx] ?? 'String',
          };
        }
        arb['@$key'] = <String, Object?>{'placeholders': placeholders};
      }
    }

    final File out = File('$outDir/app_$locale.arb');
    out.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(arb)}\n',
    );
    stdout.writeln('wrote ${out.path} (${orderedKeys.length} keys)');
  }

  stdout.writeln(
    'done: ${orderedKeys.length} keys x ${byLocale.length} locales; '
    'fallback(missing)=$fallbackMissing '
    'fallback(placeholder-mismatch)=$fallbackPlaceholderMismatch',
  );
}

/// A single converted catalog entry.
class _Entry {
  _Entry({
    required this.key,
    required this.message,
    required this.argIndexes,
    required this.argTypes,
  });

  final String key;

  /// The ARB message value (placeholders already `{argN}`).
  final String message;

  /// 0-based placeholder indexes referenced by [message].
  final Set<int> argIndexes;

  /// 0-based placeholder index -> Dart type (`String`/`int`/`double`).
  final Map<int, String> argTypes;
}

List<_Entry> _parseStrings(String xmlSource) {
  final XmlDocument doc = XmlDocument.parse(xmlSource);
  final XmlElement resources = doc.rootElement;
  final List<_Entry> entries = <_Entry>[];

  for (final XmlElement node in resources.childElements) {
    final String? name = node.getAttribute('name');
    if (name == null) continue;
    final String key = _toCamelCase(name);

    switch (node.name.local) {
      case 'string':
        final String raw = _unescapeAndroid(node.innerText);
        final _Converted c = _convertPlaceholders(raw);
        entries.add(_Entry(
          key: key,
          message: c.message,
          argIndexes: c.argIndexes,
          argTypes: c.argTypes,
        ));
      case 'plurals':
        entries.add(_convertPlural(key, node));
      default:
        // Ignore <string-array>, comments, etc.
        break;
    }
  }
  return entries;
}

/// Converts a `<plurals>` element into an ICU `{count, plural, ...}` message.
/// The `count` argument is declared as `arg0` (int) so it fits the shared
/// `{argN}` placeholder convention used everywhere else.
_Entry _convertPlural(String key, XmlElement node) {
  final StringBuffer buf = StringBuffer('{count, plural,');
  final Set<int> argIndexes = <int>{0};
  final Map<int, String> argTypes = <int, String>{0: 'int'};

  for (final XmlElement item in node.childElements) {
    if (item.name.local != 'item') continue;
    final String quantity = item.getAttribute('quantity') ?? 'other';
    final String raw = _unescapeAndroid(item.innerText);
    // Android uses `%d` for the plural count; map it to the ICU `#` sugar,
    // and convert any other args to {argN}. The count placeholder itself is
    // rendered as `#` which ICU substitutes with `count`.
    final _Converted c = _convertPlaceholders(raw.replaceAll('%d', '#'));
    argIndexes.addAll(c.argIndexes);
    for (final MapEntry<int, String> e in c.argTypes.entries) {
      argTypes[e.key] = e.value;
    }
    final String icuCategory = _icuPluralCategory(quantity);
    buf.write(' $icuCategory{${c.message}}');
  }
  buf.write('}');

  return _Entry(
    key: key,
    message: buf.toString(),
    argIndexes: argIndexes,
    argTypes: argTypes,
  );
}

String _icuPluralCategory(String androidQuantity) {
  switch (androidQuantity) {
    case 'zero':
    case 'one':
    case 'two':
    case 'few':
    case 'many':
    case 'other':
      return androidQuantity;
    default:
      return 'other';
  }
}

/// snake_case (Android resource name) -> lowerCamelCase (ARB key).
String _toCamelCase(String snake) {
  final List<String> parts = snake.split('_');
  final StringBuffer buf = StringBuffer();
  bool first = true;
  for (final String part in parts) {
    if (part.isEmpty) continue;
    if (first) {
      buf.write(part);
      first = false;
    } else {
      buf.write(part[0].toUpperCase());
      buf.write(part.substring(1));
    }
  }
  return buf.toString();
}

/// Applies Android string-resource backslash escapes and `%%` -> `%`.
/// XML entities are already decoded by `package:xml` before this runs.
String _unescapeAndroid(String s) {
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final String c = s[i];
    if (c == r'\' && i + 1 < s.length) {
      final String n = s[i + 1];
      switch (n) {
        case 'n':
          buf.write('\n');
          i++;
        case 't':
          buf.write('\t');
          i++;
        case "'":
          buf.write("'");
          i++;
        case '"':
          buf.write('"');
          i++;
        case r'\':
          buf.write(r'\');
          i++;
        case '@':
          buf.write('@');
          i++;
        case '?':
          buf.write('?');
          i++;
        case 'u':
          final int? code = (i + 5 < s.length)
              ? int.tryParse(s.substring(i + 2, i + 6), radix: 16)
              : null;
          if (code != null) {
            buf.writeCharCode(code);
            i += 5;
          } else {
            buf.write(n);
            i++;
          }
        default:
          // Unknown escape: drop the backslash, keep the char (Android behaviour).
          buf.write(n);
          i++;
      }
    } else {
      buf.write(c);
    }
  }
  return buf.toString();
}

/// Result of placeholder conversion.
class _Converted {
  _Converted(this.message, this.argIndexes, this.argTypes);
  final String message;
  final Set<int> argIndexes;
  final Map<int, String> argTypes;
}

// NB: no `^` anchor — `matchAsPrefix(input, i)` already requires the match to
// start exactly at `i`, whereas `^` would (wrongly) assert start-of-input and
// fail for any specifier past position 0.
final RegExp _positional = RegExp(r'%(\d+)\$([sdf])');
final RegExp _bare = RegExp(r'%[-+ 0#,]*\d*(?:\.\d+)?([sdf])');

/// Converts Android format specifiers into ARB `{argN}` placeholders.
_Converted _convertPlaceholders(String input) {
  final StringBuffer buf = StringBuffer();
  final Set<int> argIndexes = <int>{};
  final Map<int, String> argTypes = <int, String>{};
  int autoIndex = 0;
  int i = 0;

  while (i < input.length) {
    final String c = input[i];
    if (c != '%') {
      buf.write(c);
      i++;
      continue;
    }

    // `%%` -> literal `%`.
    if (i + 1 < input.length && input[i + 1] == '%') {
      buf.write('%');
      i += 2;
      continue;
    }

    // Positional `%N$X`.
    final Match? posMatch = _positional.matchAsPrefix(input, i);
    if (posMatch != null) {
      final int idx = int.parse(posMatch.group(1)!) - 1;
      _record(argIndexes, argTypes, idx, posMatch.group(2)!);
      buf.write('{arg$idx}');
      i = posMatch.end;
      continue;
    }

    // Bare `%X` / `%.Nf` (auto-numbered).
    final Match? bareMatch = _bare.matchAsPrefix(input, i);
    if (bareMatch != null) {
      final int idx = autoIndex++;
      _record(argIndexes, argTypes, idx, bareMatch.group(1)!);
      buf.write('{arg$idx}');
      i = bareMatch.end;
      continue;
    }

    // Lone `%` that isn't a specifier: keep literal.
    buf.write('%');
    i++;
  }

  return _Converted(buf.toString(), argIndexes, argTypes);
}

void _record(
  Set<int> argIndexes,
  Map<int, String> argTypes,
  int idx,
  String conversion,
) {
  argIndexes.add(idx);
  final String type = _typeFor(conversion);
  final String? existing = argTypes[idx];
  // On a type conflict for the same index, widen to String (safest for interop).
  argTypes[idx] = (existing == null || existing == type) ? type : 'String';
}

String _typeFor(String conversion) {
  switch (conversion) {
    case 'd':
      return 'int';
    case 'f':
      return 'double';
    case 's':
    default:
      return 'String';
  }
}

bool _placeholdersSubsetOf(Set<int> candidate, Set<int> allowed) {
  for (final int idx in candidate) {
    if (!allowed.contains(idx)) return false;
  }
  return true;
}
