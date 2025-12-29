
import os
import uuid
import re

PROJECT_PATH = "Know Maps.xcodeproj/project.pbxproj"
SOURCE_ROOT = "Know Maps Prod"

def generate_uuid():
    return uuid.uuid4().hex[:24].upper()

def read_project():
    with open(PROJECT_PATH, 'r') as f:
        return f.readlines()

def get_files_on_disk():
    files = []
    for root, _, filenames in os.walk(SOURCE_ROOT):
        for filename in filenames:
            if filename.endswith(".swift") or filename.endswith(".mlmodel") or filename.endswith(".mlpackage"):
                full_path = os.path.join(root, filename)
                files.append(full_path)
    return files

def get_files_in_project(content):
    project_files = set()
    # Simple regex to capture filenames in comments or paths
    # This is an approximation but sufficient for "is it there?" check
    text = "".join(content)
    # Look for /* Filename.swift */
    matches = re.findall(r'/\* ([a-zA-Z0-9_+\.]+\.(swift|model|mlmodel|mlpackage)) \*/', text)
    for m in matches:
        project_files.add(m[0])
    return project_files

def add_file_to_project(content, file_path):
    filename = os.path.basename(file_path)
    file_uuid = generate_uuid()
    build_uuid = generate_uuid()
    
    # 1. Add to PBXBuildFile
    # Find /* Begin PBXBuildFile section */
    build_section_idx = -1
    for i, line in enumerate(content):
        if "/* Begin PBXBuildFile section */" in line:
            build_section_idx = i
            break
            
    if build_section_idx != -1:
        # 987654321098765432109876 /* Filename.swift in Sources */ = {isa = PBXBuildFile; fileRef = 123456789012345678901234 /* Filename.swift */; };
        entry = f'\t\t{build_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {filename} */; }};\n'
        content.insert(build_section_idx + 1, entry)

    # 2. Add to PBXFileReference
    # Find /* Begin PBXFileReference section */
    ref_section_idx = -1
    for i, line in enumerate(content):
        if "/* Begin PBXFileReference section */" in line:
            ref_section_idx = i
            break
            
    if ref_section_idx != -1:
        # 123456789012345678901234 /* Filename.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Filename.swift; sourceTree = "<group>"; };
        # Need simpler path handling: assuming file is in a group that maps to directory, but for restoration, flat add to main group is safest fallback
        # Or relative path from SOURCE_ROOT? 
        # project.pbxproj often uses "path = Relative/Path/To/File.swift" relative to group.
        # Here we will use the full relative path from project root if possible, or name/path.
        # To be safe and simple, we'll try to match name.
        
        file_type = "sourcecode.swift"
        if filename.endswith(".mlmodel"): file_type = "file.mlmodel"
        if filename.endswith(".mlpackage"): file_type = "folder.mlpackage"
        
        # Calculate strict relative path from "Know Maps Prod"
        # BUT project structure usually has groups. 
        # We will add it as a file ref with the relative path from the project folder.
        rel_path = file_path # This is "Know Maps Prod/..."
        
        entry = f'\t\t{file_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = "{filename}"; sourceTree = "<group>"; }};\n'
        # Note: path is filename, assuming we put it in a group that sets the directory?
        # No, let's use the full relative path "Know Maps Prod/Subdir/File.swift" to be safe and put it in Main Group.
        entry = f'\t\t{file_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; name = "{filename}"; path = "{file_path}"; sourceTree = SOURCE_ROOT; }};\n'
        
        content.insert(ref_section_idx + 1, entry)

    # 3. Add to PBXGroup (Main Group)
    # This is tricky. We need to find the main group.
    # Usually has `children = (` and contains `Know_MapsApp.swift` or similar.
    # We will look for the group containing "Know Maps Prod" or just append to the first large group.
    # Let's find "/* Begin PBXGroup section */" and look for the main group ID.
    # Usually rootObject -> mainGroup.
    # Shortcut: Look for the group containing "Know Maps Prod" children. 
    # Or just find a group known to hold sources.
    
    # We'll look for: 1EA7F74D2B03FA71002AE371 /* Know Maps Prod */
    # (Checking prev output for UUIDs might help, but we can search by text)
    
    group_start_idx = -1
    for i, line in enumerate(content):
        if "/* Know Maps Prod */ = {" in line:
            # We found the group definition
            # Find the children = ( line
            for j in range(i, len(content)):
                if "children = (" in content[j]:
                    group_start_idx = j
                    break
            break
            
    if group_start_idx != -1:
        content.insert(group_start_idx + 1, f'\t\t\t\t{file_uuid} /* {filename} */,\n')

    # 4. Add to PBXSourcesBuildPhase
    # Find /* Begin PBXSourcesBuildPhase section */
    # Find the "Sources" phase.
    sources_start_idx = -1
    for i, line in enumerate(content):
        if "/* Sources */ = {" in line and "isa = PBXSourcesBuildPhase" in content[i+1]:
             for j in range(i, len(content)):
                if "files = (" in content[j]:
                    sources_start_idx = j
                    break
             break
             
    if sources_start_idx != -1:
        content.insert(sources_start_idx + 1, f'\t\t\t\t{build_uuid} /* {filename} in Sources */,\n')


def main():
    content = read_project()
    disk_files = get_files_on_disk()
    project_files = get_files_in_project(content)
    
    missing_files = []
    
    # Filter disk_files: remove duplicates and check against project_files basenames
    # Project files set contains basenames (e.g. "Foo.swift")
    
    for f_path in disk_files:
        basename = os.path.basename(f_path)
        if basename not in project_files:
            missing_files.append(f_path)
    
    if not missing_files:
        print("No missing files found.")
        return

    print(f"Adding {len(missing_files)} missing files to project...")
    for f in missing_files:
        print(f"Adding {f}")
        add_file_to_project(content, f)
        
    with open(PROJECT_PATH, 'w') as f:
        f.writelines(content)
    print("Project file updated.")

if __name__ == "__main__":
    main()
