import re
import os

pbxpath = 'Know-Maps/Know Maps.xcodeproj/project.pbxproj'
with open(pbxpath, 'r') as f:
    content = f.read()

# 1. Resolve missing files
# We'll look for files in PBXBuildFile and check if their ref exists and matches a disk file
file_refs = {}
pattern = r'([A-F0-9]{24}) /\* (.*?) \*/ = {isa = PBXFileReference;.*?path = (.*?); sourceTree = "(.*?)"; };'
for match in re.finditer(pattern, content):
    ref_id, name, path, tree = match.groups()
    file_refs[ref_id] = {'name': name, 'path': path, 'tree': tree}

# Helper to find absolute path (simplified)
def get_disk_path(filename):
    root = 'Know-Maps/Know Maps Prod'
    for r, d, f in os.walk(root):
        if filename in f:
            return os.path.join(r, filename)
    return None

build_files_to_remove = []
# Pattern for BuildFiles
bf_pattern = r'([A-F0-9]{24}) /\* (.*?) in Sources \*/ = {isa = PBXBuildFile; fileRef = ([A-F0-9]{24}) /\* (.*?) \*/; };'
for match in re.finditer(bf_pattern, content):
    bf_id, name_in_sources, ref_id, name = match.groups()
    if ref_id in file_refs:
        disk_path = get_disk_path(file_refs[ref_id]['path'])
        if not disk_path:
            print(f"File missing on disk: {name}. Marking for removal.")
            build_files_to_remove.append((bf_id, ref_id, name))

# Remove from PBXBuildFile section
for bf_id, ref_id, name in build_files_to_remove:
    content = re.sub(rf'^\s*{bf_id} /\* {name} in Sources \*/ = {{isa = PBXBuildFile; fileRef = {ref_id} /\* {name} \*/; }};\n', '', content, flags=re.MULTILINE)
    # Also remove from Sources build phase
    content = re.sub(rf'^\s*{bf_id} /\* {name} in Sources \*/,\n', '', content, flags=re.MULTILINE)

# 2. Add MainUI.swift
import hashlib
def generate_id(seed):
    return hashlib.sha1(seed.encode()).hexdigest()[:24].upper()

filename = "MainUI.swift"
f_id = generate_id(filename + "_ref_v3")
b_id = generate_id(filename + "_build_v3")

# Add FileRef
if f_id not in content:
    content = re.sub(r'(/\* End PBXFileReference section \*/)', f'        {f_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n' + r'\1', content)

# Add BuildFile
if b_id not in content:
    content = re.sub(r'(/\* End PBXBuildFile section \*/)', f'        {b_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {filename} */; }};\n' + r'\1', content)

# Add to View Group (1EA7F76E2B050065002AE371)
view_gid = "1EA7F76E2B050065002AE371"
if f_id not in content: # Check if it's already in the children list of this group
    view_group_pattern = r'(' + view_gid + r' /\* View \*/ = \{\n\s+isa = PBXGroup;\n\s+children = \(\n)'
    content = re.sub(view_group_pattern, r'\1' + f'                {f_id} /* {filename} */,\n', content)

# Add to Sources phase (1E15EDE12EF96C59009384CA)
sources_pid = "1E15EDE12EF96C59009384CA"
if b_id not in content:
    sources_pattern = r'(' + sources_pid + r' /\* Sources \*/ = \{\n\s+isa = PBXSourcesBuildPhase;\n\s+buildActionMask = [0-9]+;\n\s+files = \(\n)'
    content = re.sub(sources_pattern, r'\1' + f'                {b_id} /* {filename} in Sources */,\n', content)

with open(pbxpath, 'w') as f:
    f.write(content)

print("Cleanup and Add complete.")
