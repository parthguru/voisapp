#!/usr/bin/env python3
"""
Add Phase 2 WhatsApp-style CallKit enhancement files to Xcode project
AppBackgroundingManager.swift and WindowInteractionController.swift
"""

import re
import uuid
import os

def generate_uuid():
    """Generate a new UUID for Xcode project files."""
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

def add_files_to_xcode_project():
    """Add Phase 2 files to TelnyxWebRTCDemo target in Xcode project."""
    
    project_file = '/Users/Parth/telnyx-webrtc-ios/TelnyxRTC.xcodeproj/project.pbxproj'
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Phase 2 files to add
    files_to_add = [
        {
            'name': 'AppBackgroundingManager.swift',
            'path': 'TelnyxWebRTCDemo/Extensions/AppBackgroundingManager.swift'
        },
        {
            'name': 'WindowInteractionController.swift', 
            'path': 'TelnyxWebRTCDemo/Extensions/WindowInteractionController.swift'
        }
    ]
    
    # Generate UUIDs for each file (file reference + build file)
    file_uuids = []
    for file_info in files_to_add:
        file_ref_uuid = generate_uuid()
        build_file_uuid = generate_uuid()
        file_uuids.append({
            'name': file_info['name'],
            'path': file_info['path'],
            'file_ref_uuid': file_ref_uuid,
            'build_file_uuid': build_file_uuid
        })
    
    print("Generated UUIDs for Phase 2 files:")
    for file_uuid in file_uuids:
        print(f"  {file_uuid['name']}: FileRef={file_uuid['file_ref_uuid']}, BuildFile={file_uuid['build_file_uuid']}")
    
    # Find the Extensions group UUID
    extensions_group_match = re.search(r'(\w{24}) /\* Extensions \*/ = \{[^}]+children = \(\s*([^)]+)\s*\);', content, re.DOTALL)
    if not extensions_group_match:
        print("ERROR: Could not find Extensions group in project")
        return False
    
    extensions_group_uuid = extensions_group_match.group(1)
    existing_children = extensions_group_match.group(2).strip()
    
    print(f"Found Extensions group: {extensions_group_uuid}")
    
    # Find TelnyxWebRTCDemo target sources build phase
    sources_phase_match = re.search(r'(\w{24}) /\* Sources \*/ = \{[^}]+isa = PBXSourcesBuildPhase;[^}]+files = \(\s*([^)]+)\s*\);', content, re.DOTALL)
    if not sources_phase_match:
        print("ERROR: Could not find Sources build phase")
        return False
    
    sources_phase_uuid = sources_phase_match.group(1)
    existing_build_files = sources_phase_match.group(2).strip()
    
    print(f"Found Sources build phase: {sources_phase_uuid}")
    
    # Add PBXFileReference entries for each file
    file_reference_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)', content, re.DOTALL)
    if not file_reference_section:
        print("ERROR: Could not find PBXFileReference section")
        return False
    
    new_file_references = []
    for file_uuid in file_uuids:
        file_ref_entry = f"\t\t{file_uuid['file_ref_uuid']} /* {file_uuid['name']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{file_uuid['name']}\"; sourceTree = \"<group>\"; }};"
        new_file_references.append(file_ref_entry)
    
    # Add file references before the End PBXFileReference section
    file_ref_insertion_point = content.find('/* End PBXFileReference section */')
    content = content[:file_ref_insertion_point] + '\n'.join(new_file_references) + '\n\t\t' + content[file_ref_insertion_point:]
    
    print("Added PBXFileReference entries")
    
    # Add PBXBuildFile entries
    build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)', content, re.DOTALL)
    if not build_file_section:
        print("ERROR: Could not find PBXBuildFile section")
        return False
    
    new_build_files = []
    for file_uuid in file_uuids:
        build_file_entry = f"\t\t{file_uuid['build_file_uuid']} /* {file_uuid['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid['file_ref_uuid']} /* {file_uuid['name']} */; }};"
        new_build_files.append(build_file_entry)
    
    # Add build files before the End PBXBuildFile section
    build_file_insertion_point = content.find('/* End PBXBuildFile section */')
    content = content[:build_file_insertion_point] + '\n'.join(new_build_files) + '\n\t\t' + content[build_file_insertion_point:]
    
    print("Added PBXBuildFile entries")
    
    # Update Extensions group children
    new_file_refs = [f"{file_uuid['file_ref_uuid']} /* {file_uuid['name']} */," for file_uuid in file_uuids]
    updated_children = existing_children + '\n\t\t\t\t' + '\n\t\t\t\t'.join(new_file_refs) if existing_children.strip() else '\n\t\t\t\t'.join(new_file_refs)
    
    extensions_pattern = r'(\w{24} /\* Extensions \*/ = \{[^}]+children = \(\s*)([^)]+)(\s*\);)'
    content = re.sub(extensions_pattern, rf'\g<1>{updated_children}\g<3>', content, flags=re.DOTALL)
    
    print("Updated Extensions group children")
    
    # Update Sources build phase files
    new_build_file_refs = [f"{file_uuid['build_file_uuid']} /* {file_uuid['name']} in Sources */," for file_uuid in file_uuids]
    updated_build_files = existing_build_files + '\n\t\t\t\t' + '\n\t\t\t\t'.join(new_build_file_refs) if existing_build_files.strip() else '\n\t\t\t\t'.join(new_build_file_refs)
    
    sources_pattern = r'(\w{24} /\* Sources \*/ = \{[^}]+files = \(\s*)([^)]+)(\s*\);)'
    content = re.sub(sources_pattern, rf'\g<1>{updated_build_files}\g<3>', content, flags=re.DOTALL)
    
    print("Updated Sources build phase files")
    
    # Write the updated project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Successfully added Phase 2 files to Xcode project:")
    for file_uuid in file_uuids:
        print(f"   - {file_uuid['name']}")
    
    return True

if __name__ == '__main__':
    print("🔧 Adding Phase 2 WhatsApp-style CallKit enhancement files to Xcode project...")
    success = add_files_to_xcode_project()
    if success:
        print("🎉 Phase 2 files successfully integrated!")
    else:
        print("❌ Failed to add Phase 2 files to project")
        exit(1)