import re
import os

pbxpath = 'Know-Maps/Know Maps.xcodeproj/project.pbxproj'
with open(pbxpath, 'r') as f:
    content = f.read()

# 1. Purge references to files that are in "Old"
# The previous script might have missed some if the path wasn't exactly what xcode expected.
# We will be very aggressive and look for anything mentioning these filenames.
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

# Specifically check for references that might be using the "Old" directory in their path
for filename in files_to_purge:
    # Match any PBXFileReference for this filename
    matches = re.finditer(rf'([A-F0-9]{{24}}) /\* {re.escape(filename)} \*/ = {{isa = PBXFileReference;.*?path = (.*?\b{re.escape(filename)});', content)
    for match in matches:
        f_id = match.group(1)
        path = match.group(2)
        print(f"Found reference to {filename} at {path} with ID {f_id}")
        
        # Find BuildFile IDs
        bf_matches = re.findall(rf'([A-F0-9]{{24}}) /\* {re.escape(filename)} in Sources \*/ = {{isa = PBXBuildFile; fileRef = {f_id}', content)
        for bf_id in bf_matches:
            print(f"  Removing BuildFile {bf_id}")
            content = re.sub(rf'^\s*{bf_id} /\* {re.escape(filename)} in Sources \*/ = {{isa = PBXBuildFile; .*? }};\n', '', content, flags=re.MULTILINE)
            content = re.sub(rf'^\s*{bf_id} /\* {re.escape(filename)} in Sources \*/,\n', '', content, flags=re.MULTILINE)
        
        # Remove from Groups
        content = re.sub(rf'^\s*{f_id} /\* {re.escape(filename)} \*/,\n', '', content, flags=re.MULTILINE)
        # Remove FileRef
        content = re.sub(rf'^\s*{f_id} /\* {re.escape(filename)} \*/ = {{isa = PBXFileReference; .*? }};\n', '', content, flags=re.MULTILINE)

# 2. Re-add MainUI.swift and UnifiedSearchView.swift with FRESH IDs to avoid conflicts
# And make sure they are in the "View" group (1EA7F76E2B050065002AE371)
main_ui_fid = "A1B2C3D4E5F6789012345678"
main_ui_bid = "B1C2D3E4F5A6789012345678"
unified_search_fid = "C1D2E3F4A5B6789012345678"
unified_search_bid = "D1E2F3A4B5C6789012345678"

# Group and Phase IDs
view_group_id = "1EA7F76E2B050065002AE371"
sources_phase_id = "1E15EDE12EF96C59009384CA"

def add_file(fname, fid, bid):
    global content
    # FileRef
    line = f'        {fid} /* {fname} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {fname}; sourceTree = "<group>"; }};\n'
    content = re.sub(r'(/\* End PBXFileReference section \*/)', line + r'\1', content)
    # BuildFile
    line = f'        {bid} /* {fname} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {fname} */; }};\n'
    content = re.sub(r'(/\* End PBXBuildFile section \*/)', line + r'\1', content)
    # Group
    pattern = r'(' + view_group_id + r' /\* View \*/ = \{\n\s+isa = PBXGroup;\n\s+children = \(\n)'
    content = re.sub(pattern, r'\1' + f'                {fid} /* {fname} */,\n', content)
    # Sources phase
    pattern = r'(' + sources_phase_id + r' /\* Sources \*/ = \{\n\s+isa = PBXSourcesBuildPhase;\n\s+buildActionMask = [0-9]+;\n\s+files = \(\n)'
    content = re.sub(pattern, r'\1' + f'                {bid} /* {fname} in Sources */,\n', content)

# Remove any existing refs to these two just in case
for fid in ["4B7F052D107C8CE1FA277503", "5C7F052D107C8CE1FA277501", main_ui_fid, unified_search_fid]:
    content = re.sub(rf'^\s*{fid} .*?,\n', '', content, flags=re.MULTILINE)
    content = re.sub(rf'^\s*{fid} .*?;\n', '', content, flags=re.MULTILINE)
for bid in ["BFEAFC35CF441B682B90C252", "CFEAFC35CF441B682B90C251", main_ui_bid, unified_search_bid]:
    content = re.sub(rf'^\s*{bid} .*?,\n', '', content, flags=re.MULTILINE)
    content = re.sub(rf'^\s*{bid} .*?;\n', '', content, flags=re.MULTILINE)

add_file("MainUI.swift", main_ui_fid, main_ui_bid)
add_file("UnifiedSearchView.swift", unified_search_fid, unified_search_bid)

with open(pbxpath, 'w') as f:
    f.write(content)

print("Build fix v4 applied.")
