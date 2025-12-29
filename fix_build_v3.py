import re
import os

pbxpath = 'Know-Maps/Know Maps.xcodeproj/project.pbxproj'
with open(pbxpath, 'r') as f:
    content = f.read()

# 1. Purge references to files that are in "Old" or missing
# These were causing "Build input files cannot be found"
files_to_purge = [
    'SettingsView.swift', 'SearchView.swift', 'SearchTasteView.swift', 
    'SearchSectionView.swift', 'SearchPlacesView.swift', 'SearchCategoryView.swift', 
    'SavedListView.swift', 'RatingButton.swift', 'PromptRankingView.swift', 
    'PlacesList.swift', 'PlaceView.swift', 'PlaceTipsView.swift', 
    'PlacePhotosView.swift', 'PlaceDirectionsView.swift', 'PlaceDescriptionView.swift', 
    'PlaceAboutView.swift', 'NavigationLocationView.swift', 'MapResultsView.swift', 
    'FiltersView.swift', 'ContentView.swift', 'AddTasteView.swift', 
    'AddPromptView.swift', 'AddPlaceView.swift', 'AddCategoryView.swift'
]

for filename in files_to_purge:
    # Find FileRef ID
    match = re.search(rf'([A-F0-9]{{24}}) /\* {re.escape(filename)} \*/ = {{isa = PBXFileReference;', content)
    if match:
        f_id = match.group(1)
        # Find BuildFile IDs
        bf_matches = re.findall(rf'([A-F0-9]{{24}}) /\* {filename} in Sources \*/ = {{isa = PBXBuildFile; fileRef = {f_id}', content)
        for bf_id in bf_matches:
            # Remove BuildFile from section
            content = re.sub(rf'^\s*{bf_id} /\* {filename} in Sources \*/ = {{isa = PBXBuildFile; .*? }};\n', '', content, flags=re.MULTILINE)
            # Remove from Sources build phases
            content = re.sub(rf'^\s*{bf_id} /\* {filename} in Sources \*/,\n', '', content, flags=re.MULTILINE)
        # Remove from Groups
        content = re.sub(rf'^\s*{f_id} /\* {filename} \*/,\n', '', content, flags=re.MULTILINE)
        # Remove FileRef
        content = re.sub(rf'^\s*{f_id} /\* {filename} \*/ = {{isa = PBXFileReference; .*? }};\n', '', content, flags=re.MULTILINE)

# 2. Ensure MainUI.swift and UnifiedSearchView.swift are correctly added
# We'll use a specific group ID 1EA7F76E2B050065002AE371 (View)
view_group_id = "1EA7F76E2B050065002AE371"
sources_phase_id = "1E15EDE12EF96C59009384CA"

def add_file_safely(fname, f_id, b_id):
    global content
    # Add FileRef
    if f_id not in content:
        content = re.sub(r'(/\* End PBXFileReference section \*/)', f'        {f_id} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {fname}; sourceTree = "<group>"; }};\n' + r'\1', content)
    # Add BuildFile
    if b_id not in content:
        content = re.sub(r'(/\* End PBXBuildFile section \*/)', f'        {b_id} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {fname} */; }};\n' + r'\1', content)
    # Add to Group
    group_pattern = r'(' + view_group_id + r' /\* View \*/ = \{\n\s+isa = PBXGroup;\n\s+children = \(\n)'
    if f_id not in content:
        content = re.sub(group_pattern, r'\1' + f'                {f_id} /* {fname} */,\n', content)
    # Add to Sources phase
    sources_pattern = r'(' + sources_phase_id + r' /\* Sources \*/ = \{\n\s+isa = PBXSourcesBuildPhase;\n\s+buildActionMask = [0-9]+;\n\s+files = \(\n)'
    if b_id not in content:
        content = re.sub(sources_pattern, r'\1' + f'                {b_id} /* {fname} in Sources */,\n', content)

add_file_safely("MainUI.swift", "4B7F052D107C8CE1FA277503", "BFEAFC35CF441B682B90C252")
add_file_safely("UnifiedSearchView.swift", "5C7F052D107C8CE1FA277501", "CFEAFC35CF441B682B90C251")

with open(pbxpath, 'w') as f:
    f.write(content)

print("Build fix v3 applied.")
