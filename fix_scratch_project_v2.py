import re
import os

pbxpath = 'Know-Maps/Know Maps.xcodeproj/project.pbxproj'
with open(pbxpath, 'r') as f:
    content = f.read()

# Helper to find group ID by name
def find_group_id(name):
    match = re.search(r'([A-F0-9]{24}) /\* ' + re.escape(name) + r' \*/ = \{\n\s+isa = PBXGroup;', content)
    return match.group(1) if match else None

# Group IDs we need
prod_gid = find_group_id('Know Maps Prod')
models_gid = find_group_id('Models')
view_gid = find_group_id('View')

print(f"Prod: {prod_gid}, Models: {models_gid}, View: {view_gid}")

# Clean up previous attempt
content = re.sub(r'^\s*[A-F0-9]{24} /\* .* \*/ = {isa = PBXBuildFile; fileRef = [A-F0-9]{24} /\* .* \*/; };\n', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s*[A-F0-9]{24} /\* .* \*/ = {isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = .*?; sourceTree = "<group>"; };\n', '', content, flags=re.MULTILINE)

# Files to add with correct groups and paths
files_to_add = [
    ('Know_MapsApp.swift', prod_gid, 'Know_MapsApp.swift'),
    ('SearchMode.swift', models_gid, 'SearchMode.swift'),
    ('MainContentView.swift', view_gid, 'MainContentView.swift'),
    ('KnowMapsRootView.swift', view_gid, 'KnowMapsRootView.swift')
]

file_refs = ""
build_files = ""
group_updates = {prod_gid: "", models_gid: "", view_gid: ""}
sources_entries = ""

import hashlib
def generate_id(seed):
    return hashlib.sha1(seed.encode()).hexdigest()[:24].upper()

for filename, gid, path in files_to_add:
    f_id = generate_id(filename + "_ref_v2")
    b_id = generate_id(filename + "_build_v2")
    
    file_refs += f"        {f_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
    build_files += f"        {b_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {filename} */; }};\n"
    group_updates[gid] += f"                {f_id} /* {filename} */,\n"
    sources_entries += f"                {b_id} /* {filename} in Sources */,\n"

# Insert section content
content = re.sub(r'(/\* End PBXFileReference section \*/)', file_refs + r'\1', content)
content = re.sub(r'(/\* End PBXBuildFile section \*/)', build_files + r'\1', content)

# Update Groups
for gid, entries in group_updates.items():
    if gid and entries:
        pattern = r'(' + gid + r' /\* .*? \*/ = \{\n\s+isa = PBXGroup;\n\s+children = \(\n)'
        content = re.sub(pattern, r'\1' + entries, content)

# Sources Build Phase
# Need the ID: 1E15EDE12EF96C59009384CA /* Sources */
sources_pattern = r'(1E15EDE12EF96C59009384CA /\* Sources \*/ = \{\n\s+isa = PBXSourcesBuildPhase;\n\s+buildActionMask = [0-9]+;\n\s+files = \(\n)'
content = re.sub(sources_pattern, r'\1' + sources_entries, content)

with open(pbxpath, 'w') as f:
    f.write(content)

print("Updated project.pbxproj v2")
