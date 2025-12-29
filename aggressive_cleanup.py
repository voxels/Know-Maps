import re
import os

pbxpath = 'Know-Maps/Know Maps.xcodeproj/project.pbxproj'
with open(pbxpath, 'r') as f:
    content = f.read()

# Files we KNOW are gone from the target's "active" perspective
missing_root = 'Know-Maps/Know Maps Prod/View'
missing_files = [
    'SettingsView.swift', 'SearchView.swift', 'SearchTasteView.swift', 
    'SearchSectionView.swift', 'SearchPlacesView.swift', 'SearchCategoryView.swift', 
    'SavedListView.swift', 'RatingButton.swift', 'PromptRankingView.swift', 
    'PlacesList.swift', 'PlaceView.swift', 'PlaceTipsView.swift', 
    'PlacePhotosView.swift', 'PlaceDirectionsView.swift', 'PlaceDescriptionView.swift', 
    'PlaceAboutView.swift', 'NavigationLocationView.swift', 'MapResultsView.swift', 
    'FiltersView.swift', 'ContentView.swift', 'AddTasteView.swift', 
    'AddPromptView.swift', 'AddPlaceView.swift', 'AddCategoryView.swift'
]

# Find their IDs
file_ids = []
for filename in missing_files:
    # Match ref id
    match = re.search(rf'([A-F0-9]{{24}}) /\* {re.escape(filename)} \*/ = {{isa = PBXFileReference;', content)
    if match:
        file_ids.append((match.group(1), filename))

# Remove matching BuildFiles
for f_id, filename in file_ids:
    # Find build file IDs for this file ref
    bf_matches = re.findall(rf'([A-F0-9]{{24}}) /\* {re.escape(filename)} in Sources \*/ = {{isa = PBXBuildFile; fileRef = {f_id}', content)
    for bf_id in bf_matches:
        print(f"Removing build file {bf_id} for {filename}")
        # Remove from PBXBuildFile section
        content = re.sub(rf'^\s*{bf_id} /\* {filename} in Sources \*/ = {{isa = PBXBuildFile; fileRef = {f_id} /\* {filename} \*/; }};\n', '', content, flags=re.MULTILINE)
        # Remove from Sources build phases
        content = re.sub(rf'^\s*{bf_id} /\* {filename} in Sources \*/,\n', '', content, flags=re.MULTILINE)

    # Remove from Group children lists
    content = re.sub(rf'^\s*{f_id} /\* {filename} \*/,\n', '', content, flags=re.MULTILINE)
    
    # Remove from PBXFileReference section
    content = re.sub(rf'^\s*{f_id} /\* {filename} \*/ = {{isa = PBXFileReference; .*? path = {re.escape(filename)}; .*? }};\n', '', content, flags=re.MULTILINE)

with open(pbxpath, 'w') as f:
    f.write(content)

print("Aggressive cleanup complete.")
