#!/usr/bin/env python3
"""
Add Phase 4 files to Xcode project - State Management & Coordination
"""

import re
import uuid

def add_phase4_files():
    """Add Phase 4 files to Xcode project."""
    
    project_file = '/Users/Parth/telnyx-webrtc-ios/TelnyxRTC.xcodeproj/project.pbxproj'
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    print("🔧 Adding Phase 4 files to Xcode project...")
    print("📁 Phase 4: State Management & UI Coordination")
    
    # Phase 4 files to add
    phase4_files = [
        {
            'name': 'CallUIStateManager.swift',
            'path': 'TelnyxWebRTCDemo/Extensions/CallUIStateManager.swift'
        },
        {
            'name': 'CallStateCoordinator.swift', 
            'path': 'TelnyxWebRTCDemo/Extensions/CallStateCoordinator.swift'
        },
        {
            'name': 'CallStateTransition.swift',
            'path': 'TelnyxWebRTCDemo/Extensions/CallStateTransition.swift'
        }
    ]
    
    # Generate UUIDs for file references and build files
    file_refs = []
    build_files = []
    
    for file_info in phase4_files:
        file_ref_uuid = str(uuid.uuid4()).upper().replace('-', '')[:24]
        build_file_uuid = str(uuid.uuid4()).upper().replace('-', '')[:24]
        
        file_refs.append({
            'uuid': file_ref_uuid,
            'name': file_info['name'],
            'path': file_info['path']
        })
        
        build_files.append({
            'uuid': build_file_uuid,
            'file_ref': file_ref_uuid,
            'name': file_info['name']
        })
    
    print(f"📄 Adding {len(phase4_files)} Phase 4 files:")
    for file_ref in file_refs:
        print(f"   • {file_ref['name']} (UUID: {file_ref['uuid']})")
    
    # Add file references
    file_refs_section_pattern = r'(\/\* Begin PBXFileReference section \*\/\s*)(.*?)(\s*\/\* End PBXFileReference section \*\/)'
    match = re.search(file_refs_section_pattern, content, re.DOTALL)
    
    if match:
        existing_refs = match.group(2)
        new_refs_lines = []
        
        for file_ref in file_refs:
            new_ref_line = f'\t\t{file_ref["uuid"]} /* {file_ref["name"]} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{file_ref["name"]}"; sourceTree = "<group>"; }};'
            new_refs_lines.append(new_ref_line)
        
        new_refs_content = existing_refs + '\n' + '\n'.join(new_refs_lines)
        content = content.replace(match.group(0), match.group(1) + new_refs_content + match.group(3))
        print(f"✅ Added {len(file_refs)} file references")
    else:
        print("❌ Could not find PBXFileReference section")
        return False
    
    # Add build file references
    build_files_section_pattern = r'(\/\* Begin PBXBuildFile section \*\/\s*)(.*?)(\s*\/\* End PBXBuildFile section \*\/)'
    match = re.search(build_files_section_pattern, content, re.DOTALL)
    
    if match:
        existing_build_files = match.group(2)
        new_build_files_lines = []
        
        for build_file in build_files:
            new_build_file_line = f'\t\t{build_file["uuid"]} /* {build_file["name"]} in Sources */ = {{isa = PBXBuildFile; fileRef = {build_file["file_ref"]} /* {build_file["name"]} */; }};'
            new_build_files_lines.append(new_build_file_line)
        
        new_build_files_content = existing_build_files + '\n' + '\n'.join(new_build_files_lines)
        content = content.replace(match.group(0), match.group(1) + new_build_files_content + match.group(3))
        print(f"✅ Added {len(build_files)} build file references")
    else:
        print("❌ Could not find PBXBuildFile section")
        return False
    
    # Add to Extensions group (find existing group)
    extensions_group_pattern = r'(B3AF24A825EE84410062EDA9 \/\* Extensions \*\/ = \{[^}]*children = \()(.*?)(\);)'
    match = re.search(extensions_group_pattern, content, re.DOTALL)
    
    if match:
        existing_children = match.group(2)
        new_children_lines = []
        
        for file_ref in file_refs:
            new_child_line = f'\t\t\t\t{file_ref["uuid"]} /* {file_ref["name"]} */,'
            new_children_lines.append(new_child_line)
        
        new_children_content = existing_children + '\n' + '\n'.join(new_children_lines)
        content = content.replace(match.group(0), match.group(1) + new_children_content + match.group(3))
        print("✅ Added files to Extensions group")
    else:
        print("❌ Could not find Extensions group")
        return False
    
    # Add to demo app target sources (B368BEE425EDDD060032AE52)
    demo_target_pattern = r'(B368BEE425EDDD060032AE52 \/\* Sources \*\/ = \{[^}]*files = \()(.*?)(\);)'
    match = re.search(demo_target_pattern, content, re.DOTALL)
    
    if match:
        existing_files = match.group(2)
        new_files_lines = []
        
        for build_file in build_files:
            new_file_line = f'\t\t\t\t{build_file["uuid"]} /* {build_file["name"]} in Sources */,'
            new_files_lines.append(new_file_line)
        
        new_files_content = existing_files + '\n' + '\n'.join(new_files_lines)
        content = content.replace(match.group(0), match.group(1) + new_files_content + match.group(3))
        print("✅ Added files to TelnyxWebRTCDemo target")
    else:
        print("❌ Could not find TelnyxWebRTCDemo target sources")
        return False
    
    # Write the updated project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Successfully added Phase 4 files to Xcode project")
    print("\n📋 Phase 4 Summary:")
    print("   🎯 CallUIStateManager.swift - Centralized state management (900+ lines)")
    print("   🎯 CallStateCoordinator.swift - UI coordination layer (1000+ lines)")
    print("   🎯 CallStateTransition.swift - Advanced transition animations (1200+ lines)")
    print("   📊 Total Phase 4 code: 3100+ lines of enterprise-grade state management")
    
    print("\n🚀 Ready for Phase 4 build and integration testing!")
    
    return True

if __name__ == '__main__':
    print("🔧 Adding Phase 4: State Management & UI Coordination files...")
    success = add_phase4_files()
    if success:
        print("🎉 Phase 4 files added successfully to Xcode project!")
    else:
        print("❌ Failed to add Phase 4 files to Xcode project")
        exit(1)