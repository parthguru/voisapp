#!/usr/bin/env python3
"""
Add Phase 6 files to Extensions group in Xcode project
"""

import re

def fix_phase6_groups():
    project_file = "TelnyxRTC.xcodeproj/project.pbxproj"
    
    with open(project_file, 'r') as f:
        content = f.read()
    
    # Phase 6 file references to add to Extensions group
    phase6_refs = [
        "F6445962 /* CallStateSynchronizer.swift */,",
        "F6570137 /* CallEventBroadcaster.swift */,", 
        "F6456011 /* CallKitAppUIBridge.swift */,"
    ]
    
    # Find the Extensions group and add Phase 6 files after AppDelegateCallKitExtension.swift
    extensions_group_pattern = r"(B32AE8BA26D6952500C7C6F4 /\* AppDelegateCallKitExtension\.swift \*/,\s*\n\s*B3B8F53626E7D4EF0007B583 /\* AppDelegateTelnyxVoIPExtension\.swift \*/,)"
    
    # Create replacement with Phase 6 files added
    replacement = r"\1\n" + "\n".join([f"\t\t\t\t{ref}" for ref in phase6_refs])
    
    content = re.sub(extensions_group_pattern, replacement, content)
    
    # Write back to file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Successfully added Phase 6 files to Extensions group")

if __name__ == "__main__":
    fix_phase6_groups()