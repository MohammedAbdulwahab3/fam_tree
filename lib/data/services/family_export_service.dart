import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:family_tree/data/models/person.dart';

/// Service for exporting family tree data in various formats
class FamilyExportService {
  
  /// Export family tree as JSON
  static String exportAsJson(List<Person> members) {
    final data = {
      'familyTree': {
        'exportedAt': DateTime.now().toIso8601String(),
        'totalMembers': members.length,
        'members': members.map((p) => _personToMap(p)).toList(),
      }
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
  
  /// Export family tree as CSV
  static String exportAsCsv(List<Person> members) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('ID,First Name,Last Name,Birth Date,Death Date,Gender,Bio,Generation,Parent IDs,Spouse ID,Children');
    
    // Data rows
    for (final person in members) {
      final generation = _getGeneration(person, members);
      final parentIds = person.relationships.parentIds.join(';');
      final spouseIds = person.relationships.spouseIds.join(';');
      final childCount = members.where((p) => p.relationships.parentIds.contains(person.id)).length;
      
      buffer.writeln([
        person.id,
        '"${person.firstName}"',
        '"${person.lastName}"',
        person.birthDate ?? '',
        person.deathDate ?? '',
        person.gender,
        '"${person.bio?.replaceAll('"', '""') ?? ''}"',
        generation,
        parentIds,
        spouseIds,
        childCount,
      ].join(','));
    }
    
    return buffer.toString();
  }
  
  /// Export family tree as beautiful HTML with visual tree hierarchy
  static String exportAsHtmlTree(List<Person> members, String familyName) {
    final roots = members.where((p) => p.relationships.parentIds.isEmpty).toList();
    
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$familyName - Family Tree</title>
    <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;500;600;700&family=Inter:wght@300;400;500;600&display=swap" rel="stylesheet">
    <style>
        :root {
            --gold: #B8860B;
            --gold-light: #DAA520;
            --terracotta: #CD5C45;
            --sage: #8FBC8F;
            --charcoal: #2d3436;
            --cream: #faf8f5;
            --warm-white: #fffef9;
        }
        
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        @page {
            size: A0 landscape;
            margin: 0.5cm;
        }
        
        body {
            font-family: 'Inter', sans-serif;
            background: linear-gradient(180deg, var(--cream) 0%, #f5f0eb 100%);
            min-height: 100vh;
            padding: 40px 60px;
            color: var(--charcoal);
            overflow-x: auto;
        }
        
        /* Header */
        .header {
            text-align: center;
            margin-bottom: 50px;
            padding: 40px;
            background: linear-gradient(135deg, var(--gold) 0%, var(--gold-light) 100%);
            border-radius: 20px;
            color: white;
            box-shadow: 0 20px 60px rgba(184, 134, 11, 0.3);
        }
        
        .header h1 {
            font-family: 'Playfair Display', serif;
            font-size: 3.5rem;
            font-weight: 700;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        
        .header .subtitle {
            font-size: 1.3rem;
            opacity: 0.9;
            font-weight: 300;
        }
        
        .stats-row {
            display: flex;
            justify-content: center;
            gap: 40px;
            margin-top: 25px;
        }
        
        .stat {
            text-align: center;
        }
        
        .stat-value {
            font-size: 2.5rem;
            font-weight: 700;
            font-family: 'Playfair Display', serif;
        }
        
        .stat-label {
            font-size: 0.9rem;
            opacity: 0.85;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        /* Tree Container */
        .tree-container {
            width: 100%;
            overflow-x: auto;
            padding: 60px 40px;
        }
        
        .tree {
            display: inline-block;
            min-width: 100%;
            text-align: center;
        }
        
        /* Tree Structure with Lines */
        .tree > ul {
            display: inline-flex;
            justify-content: center;
        }
        
        .tree ul {
            padding-top: 60px;
            position: relative;
            display: flex;
            justify-content: center;
        }
        
        .tree li {
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
            list-style-type: none;
            position: relative;
            padding: 60px 8px 0 8px;
        }
        
        /* Connector lines */
        .tree li::before, .tree li::after {
            content: '';
            position: absolute;
            top: 0;
            width: 50%;
            height: 60px;
            border-top: 4px solid var(--gold);
        }
        
        .tree li::before {
            right: 50%;
        }
        
        .tree li::after {
            left: 50%;
            border-left: 4px solid var(--gold);
        }
        
        /* Only child - single vertical line */
        .tree li:only-child::before,
        .tree li:only-child::after {
            border: none;
        }
        
        .tree li:only-child::after {
            border-left: 4px solid var(--gold);
            width: 0;
            left: 50%;
        }
        
        /* First child - no left border */
        .tree li:first-child::before {
            border: none;
        }
        
        .tree li:first-child::after {
            border-radius: 15px 0 0 0;
        }
        
        /* Last child - no right extension */
        .tree li:last-child::after {
            border-top: none;
        }
        
        .tree li:last-child::before {
            border-right: 4px solid var(--gold);
            border-radius: 0 15px 0 0;
        }
        
        /* Vertical line from parent to children */
        .tree ul ul::before {
            content: '';
            position: absolute;
            top: 0;
            left: 50%;
            border-left: 4px solid var(--gold);
            width: 0;
            height: 60px;
        }
        
        /* Person Card */
        .person {
            display: inline-block;
            padding: 8px 10px;
            background: white;
            border-radius: 10px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.08);
            border: 1px solid transparent;
            transition: all 0.3s ease;
            width: 80px;
            min-height: 100px;
            position: relative;
        }
        
        .person:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 50px rgba(184, 134, 11, 0.2);
            border-color: var(--gold);
        }
        
        .person.root {
            background: linear-gradient(135deg, var(--gold) 0%, var(--gold-light) 100%);
            color: white;
            padding: 10px 12px;
            width: 90px;
            min-height: 110px;
        }
        
        .person.root .avatar {
            background: rgba(255,255,255,0.25);
            border: 3px solid rgba(255,255,255,0.5);
        }
        
        .person.male { border-left: 4px solid #4A90D9; }
        .person.female { border-left: 4px solid #E88D9E; }
        .person.root.male, .person.root.female { border-left: none; }
        
        .avatar {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            background: linear-gradient(135deg, var(--terracotta) 0%, #B7472A 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 6px;
            font-family: 'Playfair Display', serif;
            font-size: 0.9rem;
            font-weight: 700;
            color: white;
            box-shadow: 0 3px 10px rgba(205, 92, 69, 0.3);
        }
        
        .name {
            font-family: 'Playfair Display', serif;
            font-size: 0.6rem;
            font-weight: 600;
            margin-bottom: 4px;
            line-height: 1.15;
            height: 2.3em;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }
        
        .person.root .name {
            font-size: 0.7rem;
            height: 2.3em;
        }
        
        .gender-badge {
            display: inline-block;
            padding: 1px 5px;
            border-radius: 8px;
            font-size: 0.5rem;
            font-weight: 500;
        }
        
        .gender-badge.male {
            background: rgba(74, 144, 217, 0.15);
            color: #4A90D9;
        }
        
        .gender-badge.female {
            background: rgba(232, 141, 158, 0.15);
            color: #E88D9E;
        }
        
        .person.root .gender-badge {
            background: rgba(255,255,255,0.2);
            color: white;
        }
        
        .children-count {
            margin-top: 4px;
            font-size: 0.5rem;
            color: var(--terracotta);
            font-weight: 600;
        }
        
        .person.root .children-count {
            color: rgba(255,255,255,0.9);
        }
        
        /* Legend */
        .legend {
            display: flex;
            justify-content: center;
            gap: 30px;
            margin: 40px 0;
            padding: 20px;
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.05);
        }
        
        .legend-item {
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 0.9rem;
        }
        
        .legend-color {
            width: 20px;
            height: 20px;
            border-radius: 50%;
        }
        
        .legend-color.male { background: #4A90D9; }
        .legend-color.female { background: #E88D9E; }
        .legend-color.root { background: linear-gradient(135deg, var(--gold), var(--gold-light)); }
        
        /* Footer */
        .footer {
            text-align: center;
            margin-top: 60px;
            padding: 30px;
            color: #888;
            font-size: 0.9rem;
        }
        
        .footer .brand {
            font-family: 'Playfair Display', serif;
            font-size: 1.2rem;
            color: var(--gold);
            margin-bottom: 10px;
        }
        
        /* Print Styles */
        @media print {
            body { 
                background: white; 
                padding: 20px;
            }
            .header {
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }
            .person:hover { transform: none; }
            .person, .person.root {
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌳 $familyName</h1>
        <p class="subtitle">Family Lineage & Descendants</p>
        <div class="stats-row">
            <div class="stat">
                <div class="stat-value">${members.length}</div>
                <div class="stat-label">Family Members</div>
            </div>
            <div class="stat">
                <div class="stat-value">${_calculateGenerations(members)}</div>
                <div class="stat-label">Generations</div>
            </div>
            <div class="stat">
                <div class="stat-value">${roots.length}</div>
                <div class="stat-label">${roots.length == 1 ? 'Patriarch' : 'Patriarchs'}</div>
            </div>
        </div>
    </div>
    
    <div class="legend">
        <div class="legend-item">
            <div class="legend-color root"></div>
            <span>Root/Patriarch</span>
        </div>
        <div class="legend-item">
            <div class="legend-color male"></div>
            <span>Male</span>
        </div>
        <div class="legend-item">
            <div class="legend-color female"></div>
            <span>Female</span>
        </div>
    </div>
    
    <div class="tree-container">
        <div class="tree">
            ${_generateTreeHierarchy(members, roots)}
        </div>
    </div>
</body>
</html>
''';
  }
  
  /// Generate recursive tree hierarchy HTML
  static String _generateTreeHierarchy(List<Person> allMembers, List<Person> persons) {
    if (persons.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.write('<ul>');
    
    for (final person in persons) {
      final isRoot = person.relationships.parentIds.isEmpty;
      // Get children and sort them by the order in parent's childrenIds list
      final childrenIds = person.relationships.childrenIds;
      final children = allMembers.where((p) => 
        p.relationships.parentIds.contains(person.id)).toList();
      // Sort children to match the order in childrenIds
      children.sort((a, b) {
        final indexA = childrenIds.indexOf(a.id);
        final indexB = childrenIds.indexOf(b.id);
        if (indexA == -1 && indexB == -1) return 0;
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });
      final genderClass = person.gender?.toLowerCase() == 'female' ? 'female' : 'male';
      
      buffer.write('<li>');
      buffer.write('''
        <div class="person ${isRoot ? 'root' : ''} $genderClass">
            <div class="avatar">${person.firstName[0].toUpperCase()}</div>
            <div class="name">${person.fullName}</div>
            <span class="gender-badge $genderClass">${person.gender == 'male' || person.gender == 'Male' ? '♂ Male' : '♀ Female'}</span>
            ${children.isNotEmpty ? '<div class="children-count">${children.length} ${children.length == 1 ? 'child' : 'children'}</div>' : ''}
        </div>
      ''');
      
      if (children.isNotEmpty) {
        buffer.write(_generateTreeHierarchy(allMembers, children));
      }
      
      buffer.write('</li>');
    }
    
    buffer.write('</ul>');
    return buffer.toString();
  }
  
  /// Export as printable member list
  static String exportAsMemberList(List<Person> members, String familyName) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$familyName - Member Directory</title>
    <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Inter', sans-serif; padding: 40px; background: #fefefe; }
        h1 { font-family: 'Playfair Display', serif; color: #2d3436; margin-bottom: 30px; }
        .member-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 20px;
        }
        .member-card {
            background: white;
            border: 1px solid #eee;
            border-radius: 12px;
            padding: 20px;
            display: flex;
            align-items: center;
            gap: 15px;
        }
        .avatar {
            width: 60px;
            height: 60px;
            border-radius: 50%;
            background: linear-gradient(135deg, #CD5C45, #B7472A);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-family: 'Playfair Display', serif;
            font-size: 1.5rem;
            font-weight: 600;
            flex-shrink: 0;
        }
        .member-info h3 {
            font-family: 'Playfair Display', serif;
            font-size: 1.1rem;
            color: #2d3436;
            margin-bottom: 4px;
        }
        .member-info p {
            color: #636e72;
            font-size: 0.85rem;
        }
        @media print {
            .member-card { break-inside: avoid; }
        }
    </style>
</head>
<body>
    <h1>$familyName - Member Directory</h1>
    <div class="member-grid">
        ${members.map((p) => '''
        <div class="member-card">
            <div class="avatar">${p.firstName[0].toUpperCase()}</div>
            <div class="member-info">
                <h3>${p.fullName}</h3>
                <p>${p.birthDate ?? 'Birth date unknown'}${p.deathDate != null ? ' - ${p.deathDate}' : ''}</p>
                <p style="color: #CD5C45;">${p.gender == 'Male' ? '♂' : '♀'} ${p.gender}</p>
            </div>
        </div>
        ''').join('\n')}
    </div>
</body>
</html>
''';
  }
  
  static Map<String, dynamic> _personToMap(Person p) {
    return {
      'id': p.id,
      'firstName': p.firstName,
      'lastName': p.lastName,
      'fullName': p.fullName,
      'birthDate': p.birthDate,
      'deathDate': p.deathDate,
      'gender': p.gender,
      'bio': p.bio,
      'profilePhotoUrl': p.profilePhotoUrl,
      'relationships': {
        'parentIds': p.relationships.parentIds,
        'spouseIds': p.relationships.spouseIds,
      },
    };
  }
  
  static int _getGeneration(Person person, List<Person> allMembers) {
    if (person.relationships.parentIds.isEmpty) return 1;
    
    final parent = allMembers.where((p) => 
      person.relationships.parentIds.contains(p.id)).firstOrNull;
    if (parent == null) return 1;
    
    return _getGeneration(parent, allMembers) + 1;
  }
  
  static int _calculateGenerations(List<Person> members) {
    int maxGen = 0;
    for (final person in members) {
      final gen = _getGeneration(person, members);
      if (gen > maxGen) maxGen = gen;
    }
    return maxGen;
  }
  
  static String _generateHtmlGenerations(List<Person> members) {
    final maxGen = _calculateGenerations(members);
    final buffer = StringBuffer();
    
    for (int gen = 1; gen <= maxGen; gen++) {
      final genMembers = members.where((p) => _getGeneration(p, members) == gen).toList();
      if (genMembers.isEmpty) continue;
      
      buffer.write('<div class="generation">');
      buffer.write('<span class="gen-label">Gen $gen</span>');
      
      for (final person in genMembers) {
        final isRoot = person.relationships.parentIds.isEmpty;
        final childCount = members.where((p) => p.relationships.parentIds.contains(person.id)).length;
        
        buffer.write('''
        <div class="person-card${isRoot ? ' root' : ''}">
            <div class="person-avatar">${person.firstName[0].toUpperCase()}</div>
            <div class="person-name">${person.fullName}</div>
            <div class="person-dates">${person.birthDate ?? 'Unknown'}${person.deathDate != null ? ' - ${person.deathDate}' : ''}</div>
            <span class="person-gender">${person.gender == 'Male' ? '♂' : '♀'} ${person.gender}</span>
            ${childCount > 0 ? '<div class="person-children">$childCount ${childCount == 1 ? 'child' : 'children'}</div>' : ''}
        </div>
        ''');
      }
      
      buffer.write('</div>');
    }
    
    return buffer.toString();
  }
}
