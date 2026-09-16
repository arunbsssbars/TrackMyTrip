import re

file_path = r'd:\Program\Antigravity\TripTrackerApp\lib\core\services\local_storage_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix literal backslashes
content = content.replace(r'\\'app_seeded_v1\\'', \"'app_seeded_v1'\")

# Fix empty constructor body
content = content.replace('LocalStorageService(this._prefs, this._db) {\n  }', 'LocalStorageService(this._prefs, this._db);')

# Fix _invitationsKey
content = re.sub(r'      final jsonString = jsonEncode\(list\.map\(\(e\) => e\.toJson\(\)\)\.toList\(\)\);\n      await _prefs\.setString\(_invitationsKey, jsonString\);\n', '', content)
content = re.sub(r'    final jsonString = jsonEncode\(list\.map\(\(e\) => e\.toJson\(\)\)\.toList\(\)\);\n    await _prefs\.setString\(_invitationsKey, jsonString\);\n', '', content)
content = content.replace('await _prefs.setString(_invitationsKey, jsonString);', '')

# Fix dead code in get*Async methods
def remove_dead_return(match):
    return match.group(1) + '\n  }'

content = re.sub(r'(      return await _db\.[a-zA-Z0-9_]+\(.*?\);)\n    return [a-zA-Z0-9_]+\(.*?\);\n  \}', remove_dead_return, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
