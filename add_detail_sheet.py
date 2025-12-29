import re
import hashlib

def generate_id(seed):
    return hashlib.sha1(seed.encode()).hexdigest()[:24].upper()

pbxpath = 'Know-Maps/Know Maps.xcodeproj/project.pbxproj'
with open(pbxpath, 'r') as f:
    content = f.read()

filename = "PlaceDetailSheet.swift"
f_id = "E1F2A3B4C5D6E7F890123456"
b_id = "F1A2B3C4D5E6F7A890123456"

# Group and Phase IDs
view_group_id = "1EA7F76E2B050065002AE371"
sources_phase_id = "1E15EDE12EF96C59009384CA"

# 1. Add FileRef
if f_id not in content:
    content = re.sub(r'(/\* End PBXFileReference section \*/)', f'        {f_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n' + r'\1', content)

# 2. Add BuildFile
if b_id not in content:
    content = re.sub(r'(/\* End PBXBuildFile section \*/)', f'        {b_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {filename} */; }};\n' + r'\1', content)

# 3. Add to View Group
group_pattern = r'(' + view_group_id + r' /\* View \*/ = \{\n\s+isa = PBXGroup;\n\s+children = \(\n)'
if f_id not in content:
    content = re.sub(group_pattern, r'\1' + f'                {f_id} /* {filename} */,\n', content)

# 4. Add to Sources phase
sources_pattern = r'(' + sources_phase_id + r' /\* Sources \*/ = \{\n\s+isa = PBXSourcesBuildPhase;\n\s+buildActionMask = [0-9]+;\n\s+files = \(\n)'
if b_id not in content:
    content = re.sub(sources_pattern, r'\1' + f'                {b_id} /* {filename} in Sources */,\n', content)

with open(pbxpath, 'w') as f:
    f.write(content)

print("PlaceDetailSheet added to project.")
