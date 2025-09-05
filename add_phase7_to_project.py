#!/usr/bin/env python3

import os
import sys

def add_phase7_files_to_project():
    """
    Add Phase 7 CallKit enhancement files to Xcode project
    """
    
    # Define Phase 7 files
    phase7_files = [
        "TelnyxWebRTCDemo/Extensions/CallKitTestScenarios.swift",
        "TelnyxWebRTCDemo/Extensions/CallKitValidationSuite.swift", 
        "TelnyxWebRTCDemo/Extensions/CallKitDebugLogger.swift"
    ]
    
    print("🚀 Adding Phase 7 CallKit enhancement files to Xcode project...")
    
    project_file = "TelnyxRTC.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_file):
        print(f"❌ Project file not found: {project_file}")
        return False
    
    # Read project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Generate unique IDs for each file (24-character hex)
    import uuid
    
    file_entries = {}
    build_entries = {}
    
    for file_path in phase7_files:
        filename = os.path.basename(file_path)
        
        # Generate two unique IDs per file (file reference and build file)
        file_id = ''.join([f'{uuid.uuid4().hex[i:i+2]}{uuid.uuid4().hex[i:i+2]}'[:24] for i in range(0, 8, 2)])[:24].upper()
        build_id = ''.join([f'{uuid.uuid4().hex[i:i+2]}{uuid.uuid4().hex[i:i+2]}'[:24] for i in range(0, 8, 2)])[:24].upper()
        
        file_entries[file_path] = {
            'file_id': file_id,
            'build_id': build_id,
            'filename': filename
        }
    
    print(f"Generated {len(file_entries)} file entries with unique IDs")
    
    # Find the Extensions group
    extensions_group_pattern = r'([A-F0-9]{24}) /\* Extensions \*/ = \{'
    import re
    
    extensions_match = re.search(extensions_group_pattern, content)
    if not extensions_match:
        print("❌ Extensions group not found in project file")
        return False
    
    extensions_group_id = extensions_match.group(1)
    print(f"✅ Found Extensions group with ID: {extensions_group_id}")
    
    # Add file references to PBXFileReference section
    pbx_file_ref_pattern = r'(/\* Begin PBXFileReference section \*/\n)'
    
    file_ref_entries = []
    for file_path, info in file_entries.items():
        file_ref_entry = f"\t\t{info['file_id']} /* {info['filename']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {info['filename']}; sourceTree = \"<group>\"; }};\n"
        file_ref_entries.append(file_ref_entry)
    
    file_ref_insertion = '\\1' + ''.join(file_ref_entries)
    content = re.sub(pbx_file_ref_pattern, file_ref_insertion, content)
    print(f"✅ Added {len(file_ref_entries)} file references")
    
    # Add build file references to PBXBuildFile section
    pbx_build_file_pattern = r'(/\* Begin PBXBuildFile section \*/\n)'
    
    build_file_entries = []
    for file_path, info in file_entries.items():
        build_file_entry = f"\t\t{info['build_id']} /* {info['filename']} in Sources */ = {{isa = PBXBuildFile; fileRef = {info['file_id']} /* {info['filename']} */; }};\n"
        build_file_entries.append(build_file_entry)
    
    build_file_insertion = '\\1' + ''.join(build_file_entries)
    content = re.sub(pbx_build_file_pattern, build_file_insertion, content)
    print(f"✅ Added {len(build_file_entries)} build file references")
    
    # Add files to Extensions group
    extensions_group_pattern = f'({extensions_group_id} /\\* Extensions \\*/ = {{[^}}]+children = \\([^)]+)'
    
    group_file_entries = []
    for file_path, info in file_entries.items():
        group_entry = f"\t\t\t\t{info['file_id']} /* {info['filename']} */,\n"
        group_file_entries.append(group_entry)
    
    group_insertion = '\\1' + ''.join(group_file_entries)
    content = re.sub(extensions_group_pattern, group_insertion, content, flags=re.DOTALL)
    print(f"✅ Added {len(group_file_entries)} files to Extensions group")
    
    # Add files to TelnyxWebRTCDemo target Sources build phase
    # Find TelnyxWebRTCDemo target
    target_pattern = r'([A-F0-9]{24}) /\* TelnyxWebRTCDemo \*/ = \{'
    target_match = re.search(target_pattern, content)
    
    if not target_match:
        print("❌ TelnyxWebRTCDemo target not found")
        return False
    
    target_id = target_match.group(1)
    print(f"✅ Found TelnyxWebRTCDemo target with ID: {target_id}")
    
    # Find the Sources build phase for this target
    sources_build_phase_pattern = r'([A-F0-9]{24}) /\* Sources \*/ = \{[^}]+isa = PBXSourcesBuildPhase;[^}]+files = \([^)]*\)'
    
    sources_match = re.search(sources_build_phase_pattern, content, re.DOTALL)
    if not sources_match:
        print("❌ Sources build phase not found")
        return False
    
    sources_build_entries = []
    for file_path, info in file_entries.items():
        sources_entry = f"\t\t\t\t{info['build_id']} /* {info['filename']} in Sources */,\n"
        sources_build_entries.append(sources_entry)
    
    sources_insertion = '\\1' + ''.join(sources_build_entries)
    content = re.sub(sources_build_phase_pattern, sources_insertion, content, flags=re.DOTALL)
    print(f"✅ Added {len(sources_build_entries)} files to Sources build phase")
    
    # Write the updated project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Phase 7 files successfully added to Xcode project!")
    print("\nPhase 7 files added:")
    for file_path in phase7_files:
        print(f"  - {file_path}")
    
    return True

if __name__ == "__main__":
    success = add_phase7_files_to_project()
    if success:
        print("\n🎉 Phase 7 integration complete! Ready for testing and validation.")
        sys.exit(0)
    else:
        print("\n❌ Failed to add Phase 7 files to project")
        sys.exit(1)