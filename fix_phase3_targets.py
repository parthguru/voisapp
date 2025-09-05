#!/usr/bin/env python3
"""
Fix Phase 3 file target assignments in Xcode project
Remove from incorrect targets, ensure they're only in TelnyxWebRTCDemo app target
"""

import re

def fix_phase3_target_assignments():
    """Fix Phase 3 files to be only in TelnyxWebRTCDemo app target."""
    
    project_file = '/Users/Parth/telnyx-webrtc-ios/TelnyxRTC.xcodeproj/project.pbxproj'
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    print("🔧 Fixing Phase 3 file target assignments...")
    
    # Phase 3 build file UUIDs that need to be fixed
    phase3_build_files = [
        "93C0056B70A641FCB4844EDF", # CallKitRetryManager.swift
        "3E57EB706C9C48BB8F57CF92", # CallRetryStrategy.swift  
        "9DC866A859B74B4CA5E74184"  # CallKitFailureAnalyzer.swift
    ]
    
    # Target build phase UUIDs
    telnyxwebrtcdemo_app_sources = "B368BEE425EDDD060032AE52"  # Correct target
    incorrect_targets = [
        "9946517B2D761F7800049EF4",  # TelnyxWebRTCDemoUITests (causes XCTest error)
        "B368BEBC25EDDB610032AE52",  # TelnyxRTC framework  
        "B368BECD25EDDBC90032AE52"   # Another incorrect target
    ]
    
    print(f"Correct target: {telnyxwebrtcdemo_app_sources}")
    print(f"Incorrect targets to fix: {incorrect_targets}")
    
    # Remove Phase 3 files from incorrect targets
    for target_uuid in incorrect_targets:
        print(f"Removing Phase 3 files from target {target_uuid}")
        
        # Find the target's Sources build phase
        pattern = f'({target_uuid} /\\* Sources \\*/ = {{[^}}]+files = \\()([^)]+)(\\);)'
        match = re.search(pattern, content, re.DOTALL)
        
        if match:
            files_section = match.group(2)
            
            # Remove our Phase 3 files
            for build_file_uuid in phase3_build_files:
                # Remove lines containing our build file UUIDs
                lines = files_section.split('\n')
                cleaned_lines = []
                
                for line in lines:
                    if build_file_uuid not in line:
                        cleaned_lines.append(line)
                    else:
                        print(f"  Removed {build_file_uuid} from target {target_uuid}")
                
                files_section = '\n'.join(cleaned_lines)
            
            # Update the content
            new_match_content = match.group(1) + files_section + match.group(3)
            content = content.replace(match.group(0), new_match_content)
        else:
            print(f"  Warning: Could not find Sources build phase for target {target_uuid}")
    
    # Ensure Phase 3 files are in the correct TelnyxWebRTCDemo target
    print(f"Ensuring Phase 3 files are in correct target {telnyxwebrtcdemo_app_sources}")
    
    pattern = f'({telnyxwebrtcdemo_app_sources} /\\* Sources \\*/ = {{[^}}]+files = \\()([^)]+)(\\);)'
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        files_section = match.group(2)
        
        # Check if our files are already present, if not add them
        for i, build_file_uuid in enumerate(phase3_build_files):
            file_names = [
                "CallKitRetryManager.swift",
                "CallRetryStrategy.swift", 
                "CallKitFailureAnalyzer.swift"
            ]
            
            if build_file_uuid not in files_section:
                files_section += f"\n\t\t\t\t{build_file_uuid} /* {file_names[i]} in Sources */,"
                print(f"  Added {file_names[i]} to correct target")
            else:
                print(f"  {file_names[i]} already in correct target")
        
        # Update the content
        new_match_content = match.group(1) + files_section + match.group(3)
        content = content.replace(match.group(0), new_match_content)
    else:
        print(f"  Error: Could not find Sources build phase for correct target {telnyxwebrtcdemo_app_sources}")
        return False
    
    # Write the fixed project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Successfully fixed Phase 3 file target assignments")
    print("\n📋 Summary:")
    print("   - Removed Phase 3 files from UI test and framework targets")
    print("   - Ensured Phase 3 files are only in TelnyxWebRTCDemo app target")
    print("   - This should resolve the XCTest module error")
    
    return True

if __name__ == '__main__':
    print("🔧 Fixing Phase 3 target assignment issues...")
    success = fix_phase3_target_assignments()
    if success:
        print("🎉 Phase 3 target assignments fixed successfully!")
        print("\n🚀 Ready to retry Phase 3 build!")
    else:
        print("❌ Failed to fix Phase 3 target assignments")
        exit(1)