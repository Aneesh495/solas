#!/usr/bin/env python3
import os
import sys

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EM_DASHES = ['\u2014', '\u2013']
found_errors = False

for root, dirs, files in os.walk(repo_root):
    if '.git' in dirs:
        dirs.remove('.git')
    if 'build' in dirs:
        dirs.remove('build')
    if 'subprojects' in dirs:
        dirs.remove('subprojects')
    for file in files:
        if file.endswith(('.vala', '.c', '.h', '.vapi', '.md', '.txt', '.py', '.sh', '.json', '.build')):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    for line_num, line in enumerate(f, 1):
                        for em in EM_DASHES:
                            if em in line:
                                rel_path = os.path.relpath(path, repo_root)
                                print(f"EM DASH DETECTED at {rel_path}:{line_num}: {line.strip()}")
                                found_errors = True
            except Exception as e:
                pass

if found_errors:
    print("FAILED: Em dashes found! Please replace with hyphens or colons.")
    sys.exit(1)
else:
    print("PASSED: Zero em dashes found.")
    sys.exit(0)
