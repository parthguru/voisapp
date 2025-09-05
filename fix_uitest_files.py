#!/usr/bin/env python3
"""
Fix UI test file target assignments in Xcode project
Remove UI test files from framework and app targets
"""

import re

def fix_uitest_file_assignments():
    """Fix UI test files to be only in UI test target."""
    
    project_file = '/Users/Parth/telnyx-webrtc-ios/TelnyxRTC.xcodeproj/project.pbxproj'
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    print("🔧 Fixing UI test file target assignments...")
    
    # UI test build file UUIDs that should only be in UI test target
    uitest_build_files = [
        "994651932D76202C00049EF4", # TelnyxWebRTCDemoUITests.swift
        "994651942D76203100049EF4", # TestConstants.swift
        "994651952D76204800049EF4"  # AccessibilityIdentifiers.swift
    ]
    
    # Target build phase UUIDs where UI test files should NOT be
    incorrect_targets = [
        "B368BEBC25EDDB610032AE52",  # TelnyxRTC framework
        "B368BECD25EDDBC90032AE52",  # Another framework target
        "B368BEE425EDDD060032AE52"   # TelnyxWebRTCDemo app target
    ]
    
    # Correct UI test target (keep files here)
    correct_uitest_target = "9946517B2D761F7800049EF4"
    
    print(f"UI test files should only be in: {correct_uitest_target}")
    print(f"Removing UI test files from incorrect targets: {incorrect_targets}")
    
    # Remove UI test files from incorrect targets
    for target_uuid in incorrect_targets:
        print(f"Removing UI test files from target {target_uuid}")
        
        # Find the target's Sources build phase
        pattern = f'({target_uuid} /\\* Sources \\*/ = {{[^}}]+files = \\()([^)]+)(\\);)'
        match = re.search(pattern, content, re.DOTALL)
        
        if match:
            files_section = match.group(2)
            original_files_section = files_section
            
            # Remove our UI test files
            for build_file_uuid in uitest_build_files:
                # Remove lines containing our UI test build file UUIDs
                lines = files_section.split('\n')
                cleaned_lines = []
                
                for line in lines:
                    if build_file_uuid not in line:
                        cleaned_lines.append(line)
                    else:
                        print(f"  Removed {build_file_uuid} from target {target_uuid}")
                
                files_section = '\n'.join(cleaned_lines)
            
            # Only update if changes were made
            if files_section != original_files_section:
                # Update the content
                new_match_content = match.group(1) + files_section + match.group(3)
                content = content.replace(match.group(0), new_match_content)
            else:
                print(f"  No UI test files found in target {target_uuid}")
        else:
            print(f"  Warning: Could not find Sources build phase for target {target_uuid}")
    
    # Verify UI test files are still in correct UI test target
    print(f"Verifying UI test files are in correct target {correct_uitest_target}")
    
    pattern = f'({correct_uitest_target} /\\* Sources \\*/ = {{[^}}]+files = \\()([^)]+)(\\);)'
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        files_section = match.group(2)
        
        # Check if our UI test files are present
        missing_files = []
        for build_file_uuid in uitest_build_files:
            if build_file_uuid not in files_section:
                missing_files.append(build_file_uuid)
        
        if missing_files:
            print(f"  Warning: Some UI test files missing from correct target: {missing_files}")
        else:
            print(f"  ✅ All UI test files present in correct target")
    else:
        print(f"  Error: Could not find UI test target {correct_uitest_target}")
        return False
    
    # Write the fixed project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Successfully fixed UI test file target assignments")
    print("\n📋 Summary:")
    print("   - Removed UI test files from framework and app targets")
    print("   - UI test files now only in UI test target")
    print("   - This should resolve the XCTest module error")
    
    return True

if __name__ == '__main__':
    print("🔧 Fixing UI test file target assignment issues...")
    success = fix_uitest_file_assignments()
    if success:
        print("🎉 UI test file assignments fixed successfully!")
        print("\n🚀 Ready to retry Phase 3 build!")
    else:
        print("❌ Failed to fix UI test file assignments")
        exit(1)