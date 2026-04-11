import os
import re

files_to_fix = [
    'lib/database/EXAMPLES.dart',
    'lib/services/gemini_service.dart',
    'lib/services/openai_service.dart',
    'lib/screens/settings_screen.dart',
]

for file_path in files_to_fix:
    if os.path.exists(file_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        new_lines = []
        for line in lines:
            if 'print(' in line:
                stripped = line.lstrip()
                indent = line[:len(line) - len(stripped)]
                new_lines.append(indent + '// ' + stripped)
            else:
                new_lines.append(line)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print(f'Fixed: {file_path}')
    else:
        print(f'Not found: {file_path}')
