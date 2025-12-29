import re
import os

pbxpath = 'Know-Maps/Know Maps.xcodeproj/project.pbxproj'
with open(pbxpath, 'r') as f:
    content = f.read()

# 1. Purge ALL stale references
stale_files = [
    'SettingsView.swift', 'SearchView.swift', 'SearchTasteView.swift', 
    'SearchSectionView.swift', 'SearchPlacesView.swift', 'SearchCategoryView.swift', 
    'SavedListView.swift', 'RatingButton.swift', 'PromptRankingView.swift', 
    'PlacesList.swift', 'PlaceView.swift', 'PlaceTipsView.swift', 
    'PlacePhotosView.swift', 'PlaceDirectionsView.swift', 'PlaceDescriptionView.swift', 
    'PlaceAboutView.swift', 'NavigationLocationView.swift', 'MapResultsView.swift', 
    'FiltersView.swift', 'ContentView.swift', 'AddTasteView.swift', 
    'AddPromptView.swift', 'AddPlaceView.swift', 'AddCategoryView.swift'
]

for filename in stale_files:
    # Match any PBXFileReference for this filename
    matches = re.finditer(rf'([A-F0-9]{{24}}) /\* {re.escape(filename)} \*/ = {{isa = PBXFileReference;', content)
    for match in list(matches):
        f_id = match.group(1)
        # Remove matching BuildFiles
        bf_matches = re.findall(rf'([A-F0-9]{{24}}) /\* {re.escape(filename)} in Sources \*/ = {{isa = PBXBuildFile; fileRef = {f_id}', content)
        for bf_id in bf_matches:
            content = re.sub(rf'^\s*{bf_id} /\* {re.escape(filename)} in Sources \*/ = {{isa = PBXBuildFile; .*? }};\n', '', content, flags=re.MULTILINE)
            content = re.sub(rf'^\s*{bf_id} /\* {re.escape(filename)} in Sources \*/,\n', '', content, flags=re.MULTILINE)
        # Remove from Groups
        content = re.sub(rf'^\s*{f_id} /\* {re.escape(filename)} \*/,\n', '', content, flags=re.MULTILINE)
        # Remove FileRef
        content = re.sub(rf'^\s*{f_id} /\* {re.escape(filename)} \*/ = {{isa = PBXFileReference; .*? }};\n', '', content, flags=re.MULTILINE)

# 2. Add Active Files with FIXED IDs to ensure they are present
active_files = {
    "MainUI.swift": ("A1B2C3D4E5F6789012345678", "B1C2D3E4F5A6789012345678"),
    "UnifiedSearchView.swift": ("C1D2E3F4A5B6789012345678", "D1E2F3A4B5C6789012345678"),
    "PlaceDetailSheet.swift": ("E1F2A3B4C5D6E7F890123456", "F1A2B3C4D5E6F7A890123456")
}

view_group_id = "1EA7F76E2B050065002AE371"
sources_phase_id = "1E15EDE12EF96C59009384CA"

# First, clean existing refs to these to avoid duplicates
for fname, (fid, bid) in active_files.items():
    content = re.sub(rf'^\s*{fid} .*?,\n', '', content, flags=re.MULTILINE)
    content = re.sub(rf'^\s*{fid} .*?;\n', '', content, flags=re.MULTILINE)
    content = re.sub(rf'^\s*{bid} .*?,\n', '', content, flags=re.MULTILINE)
    content = re.sub(rf'^\s*{bid} .*?;\n', '', content, flags=re.MULTILINE)

# Add them back
for fname, (fid, bid) in active_files.items():
    # FileRef
    line = f'        {fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {fname}; sourceTree = "<group>"; }};\n'
    content = re.sub(r'(/\* End PBXFileReference section \*/)', line + r'\1', content)
    # BuildFile
    line = f'        {bid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fname} */; }};\n'
    content = re.sub(r'(/\* End PBXBuildFile section \*/)', line + r'\1', content)
    # View Group
    group_line = f'                {fid} /* {fname} */,\n'
    content = re.sub(rf'({view_group_id} /\* View \*/ = \{{.*?children = \(\n)', r'\1' + group_line, content, flags=re.DOTALL)
    # Sources phase
    build_line = f'                {bid} /* {fname} in Sources */,\n'
    content = re.sub(rf'({sources_phase_id} /\* Sources \*/ = \{{.*?files = \(\n)', r'\1' + build_line, content, flags=re.DOTALL)

with open(pbxpath, 'w') as f:
    f.write(content)

print("Build fix v5 complete.")
