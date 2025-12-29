import re
import os

def generate_id(seed):
    import hashlib
    return hashlib.sha1(seed.encode()).hexdigest()[:24].upper()

pbxpath = 'Know-Maps/Know Maps.xcodeproj/project.pbxproj'
with open(pbxpath, 'r') as f:
    content = f.read()

# 1. Remove Know_Maps.swift references
content = re.sub(r'^\s*[A-F0-9]{24} /\* Know_Maps\.swift in Sources \*/ = {isa = PBXBuildFile; fileRef = [A-F0-9]{24} /\* Know_Maps\.swift \*/; };\n', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s*[A-F0-9]{24} /\* Know_Maps\.swift \*/ = {isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = Know_Maps\.swift; sourceTree = "<group>"; };\n', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s*[A-F0-9]{24} /\* Know_Maps\.swift \*/,\n', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s*[A-F0-9]{24} /\* Know_Maps\.swift in Sources \*/,\n', '', content, flags=re.MULTILINE)

# 2. Add New Files
new_files = [
    ('Know_MapsApp.swift', 'Know Maps Prod'),
    ('SearchMode.swift', 'Know Maps Prod/Model/Models'),
    ('MainContentView.swift', 'Know Maps Prod/View'),
    ('KnowMapsRootView.swift', 'Know Maps Prod/View')
]

file_refs = ""
build_files = ""
group_entries = {
    'Know Maps Prod': "",
    'Know Maps Prod/Model/Models': "",
    'Know Maps Prod/View': ""
}
sources_entries = ""

for filename, folder in new_files:
    f_id = generate_id(filename + "_ref")
    b_id = generate_id(filename + "_build")
    
    file_refs += f"        {f_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
    build_files += f"        {b_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {filename} */; }};\n"
    group_entries[folder] += f"                {f_id} /* {filename} */,\n"
    sources_entries += f"                {b_id} /* {filename} in Sources */,\n"

# Insert File References
content = re.sub(r'(/\* End PBXFileReference section \*/)', file_refs + r'\1', content)

# Insert Build Files
content = re.sub(r'(/\* End PBXBuildFile section \*/)', build_files + r'\1', content)

# Add to Groups (This is tricky, need to find the right group IDs)
# For now, let's just add to the main "Know Maps Prod" group if we can find it
prod_group_pattern = r'(/\* Know Maps Prod \*/ = \{\n\s+isa = PBXGroup;\n\s+children = \(\n)'
content = re.sub(prod_group_pattern, r'\1' + group_entries['Know Maps Prod'], content)

# Sources Build Phase
# Need the ID: 1E15EDE12EF96C59009384CA /* Sources */
sources_pattern = r'(1E15EDE12EF96C59009384CA /\* Sources \*/ = \{\n\s+isa = PBXSourcesBuildPhase;\n\s+buildActionMask = [0-9]+;\n\s+files = \(\n)'
content = re.sub(sources_pattern, r'\1' + sources_entries, content)

with open(pbxpath, 'w') as f:
    f.write(content)

print("Updated project.pbxproj")
