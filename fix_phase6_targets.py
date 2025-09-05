#!/usr/bin/env python3

import os
import re

def fix_phase6_target_assignments():
    """
    Fix Phase 6 files target assignments in Xcode project
    """
    
    # Phase 6 files that need to be in main target
    phase6_files = [
        "CallStateSynchronizer.swift",
        "CallEventBroadcaster.swift", 
        "CallKitAppUIBridge.swift"
    ]
    
    project_file = "TelnyxRTC.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_file):
        print(f"❌ Project file not found: {project_file}")
        return False
    
    print("🔍 Reading project file...")
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Find TelnyxWebRTCDemo target Sources build phase
    sources_pattern = r'([A-F0-9]{24} /\* Sources \*/ = \{[^}]+isa = PBXSourcesBuildPhase;[^}]+files = \([^)]*)'
    sources_match = re.search(sources_pattern, content, re.DOTALL)
    
    if not sources_match:
        print("❌ Could not find Sources build phase")
        return False
    
    print("✅ Found Sources build phase")
    
    # Check if Phase 6 files are already in Sources build phase
    sources_section = sources_match.group(0)
    missing_files = []
    
    for filename in phase6_files:
        if filename not in sources_section:
            missing_files.append(filename)
    
    if not missing_files:
        print("✅ All Phase 6 files are already in Sources build phase")
        return True
    
    print(f"🔧 Adding {len(missing_files)} missing files to Sources build phase")
    
    # Find build file references for missing files
    for filename in missing_files:
        # Look for build file reference
        build_ref_pattern = f'([A-F0-9]{{24}}) /\\* {re.escape(filename)} in Sources \\*/'
        build_match = re.search(build_ref_pattern, content)
        
        if build_match:
            build_id = build_match.group(1)
            print(f"✅ Found build reference for {filename}: {build_id}")
            
            # Add to Sources build phase
            build_entry = f"\t\t\t\t{build_id} /* {filename} in Sources */,\n"
            
            # Insert before closing parenthesis of files array
            insertion_point = sources_match.end() - 1  # Before closing parenthesis
            content = content[:insertion_point] + build_entry + content[insertion_point:]
            
            print(f"✅ Added {filename} to Sources build phase")
        else:
            print(f"❌ Could not find build reference for {filename}")
    
    # Write back to project file
    print("💾 Writing updated project file...")
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Phase 6 target assignments fixed!")
    return True

if __name__ == "__main__":
    success = fix_phase6_target_assignments()
    if success:
        print("🎉 Phase 6 target fix complete!")
    else:
        print("❌ Failed to fix Phase 6 target assignments")
