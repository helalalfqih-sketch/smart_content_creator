import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

void main() async {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('{"error": "lib directory not found"}');
    return;
  }

  // File Statistics
  int totalBytes = 0;
  final List<Map<String, dynamic>> allFiles = [];
  final Map<String, int> fileSizes = {};
  
  // Dependency tracking
  final Map<String, int> importCounts = {}; // path -> number of times it was imported
  final List<String> dartFilePaths = [];

  // 1. Gather files
  await for (var entity in libDir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      if (entity.path.endsWith('.dart')) {
        final path = entity.path.replaceAll('\\', '/');
        final bytes = await entity.length();
        totalBytes += bytes;
        dartFilePaths.add(path);
        fileSizes[path] = bytes;
        allFiles.add({
          'path': path,
          'bytes': bytes,
          'name': p.basename(path),
        });
      }
    }
  }

  allFiles.sort((a, b) => b['bytes'].compareTo(a['bytes']));
  final topLargest = allFiles.take(15).toList();

  // 2. Parse imports
  for (final path in dartFilePaths) {
    importCounts[path] = importCounts[path] ?? 0;
    
    final content = await File(path).readAsString();
    final importRegex = RegExp(r'''import\s+['"]([^'"]+\.dart)['"]''');
    final matches = importRegex.allMatches(content);
    
    for (var match in matches) {
      final importPathStr = match.group(1);
      if (importPathStr != null && !importPathStr.startsWith('package:') && !importPathStr.startsWith('dart:')) {
        // Resolve relative path
        try {
          final absolutePath = p.normalize(p.join(p.dirname(path), importPathStr)).replaceAll('\\', '/');
          if (importCounts.containsKey(absolutePath)) {
             importCounts[absolutePath] = importCounts[absolutePath]! + 1;
          } else {
             importCounts[absolutePath] = 1;
          }
        } catch (_) {}
      }
    }

    // Part of
    final partRegex = RegExp(r'''part\s+['"]([^'"]+\.dart)['"]''');
    final partMatches = partRegex.allMatches(content);
    for (var match in partMatches) {
      final partPathStr = match.group(1);
      if (partPathStr != null) {
        try {
          final absolutePath = p.normalize(p.join(p.dirname(path), partPathStr)).replaceAll('\\', '/');
          importCounts[absolutePath] = (importCounts[absolutePath] ?? 0) + 1;
        } catch (_) {}
      }
    }
  }

  // 3. Find Unused (0 imports and not main.dart and not part of bindings if they are called dynamically, though getx bindings might be explicit)
  final List<String> potentiallyUnused = [];
  for (final path in importCounts.keys) {
    if (importCounts[path] == 0) {
      final bn = p.basename(path);
      // Safe list of files that are executed dynamically or are entry points
      if (bn != 'main.dart' && bn != 'firebase_options.dart' && !bn.endsWith('_binding.dart')) {
        potentiallyUnused.add(path);
      }
    }
  }

  // 4. Find Similar/Duplicated Names (Heuristics)
  final Map<String, List<String>> prefixGroups = {};
  for (var fn in dartFilePaths) {
    final bn = p.basenameWithoutExtension(fn);
    if (bn.length > 5) {
      final prefix = bn.substring(0, 5);
      prefixGroups.putIfAbsent(prefix, () => []).add(fn);
    }
  }
  
  final List<Map<String, dynamic>> similarGroups = [];
  prefixGroups.forEach((k, v) {
    if (v.length > 1 && v.where((p) => p.contains('service') || p.contains('screen') || p.contains('controller')).length > 1) {
      // similarGroups.add({'prefix': k, 'files': v}); // simple heuristic might be too noisy
    }
  });

  // Construct comprehensive report
  final report = {
    'total_files': dartFilePaths.length,
    'total_size_mb': (totalBytes / (1024 * 1024)).toStringAsFixed(2),
    'largest_files': topLargest.map((e) => {'name': e['name'], 'kb': (e['bytes']/1024).toStringAsFixed(1)}).toList(),
    'potentially_unused': potentiallyUnused,
  };

  print(jsonEncode(report));
}
