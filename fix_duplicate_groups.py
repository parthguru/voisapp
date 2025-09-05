#!/usr/bin/env python3
"""
Fix duplicate group membership warnings in Xcode project file
Remove duplicate entries from Extensions group
"""

import re

def fix_duplicate_group_memberships():
    """Fix duplicate file references in Extensions group."""
    
    project_file = '/Users/Parth/telnyx-webrtc-ios/TelnyxRTC.xcodeproj/project.pbxproj'
    
    # Read the project file
    with open(project_file, 'r') as f:
        content = f.read()
    
    print("🔧 Fixing duplicate group memberships in Xcode project...")
    
    # Find all Extensions groups and their children
    extensions_groups = re.findall(r'(\w{24}) /\* Extensions \*/ = \{[^}]+children = \(\s*([^)]+)\s*\);', content, re.DOTALL)
    
    print(f"Found {len(extensions_groups)} Extensions groups")
    
    if len(extensions_groups) > 1:
        # Keep the first Extensions group, remove duplicates from others
        primary_group_uuid = extensions_groups[0][0]
        primary_children = extensions_groups[0][1]
        
        print(f"Primary Extensions group: {primary_group_uuid}")
        
        # Remove duplicate entries from other Extensions groups
        for i, (group_uuid, children) in enumerate(extensions_groups[1:], 1):
            print(f"Cleaning duplicate Extensions group {i}: {group_uuid}")
            
            # Replace the duplicate group's children with empty list
            pattern = f'{re.escape(group_uuid)} /\\* Extensions \\*/ = {{[^}}]+children = \\([^)]+\\);'
            replacement = f'{group_uuid} /* Extensions */ = {{\\n\\t\\t\\tisa = PBXGroup;\\n\\t\\t\\tchildren = (\\n\\t\\t\\t);\\n\\t\\t\\tname = Extensions;\\n\\t\\t\\tsourceTree = \"<group>\";\\n\\t\\t}};'
            
            content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    # Also clean up any duplicate file references in the primary group
    if extensions_groups:
        primary_group_uuid = extensions_groups[0][0]
        primary_children = extensions_groups[0][1]
        
        # Extract individual file references
        file_refs = re.findall(r'(\w{24} /\* [^*]+ \*/),', primary_children)
        
        # Remove duplicates while preserving order
        seen = set()
        unique_refs = []
        for ref in file_refs:
            if ref not in seen:
                unique_refs.append(ref)
                seen.add(ref)
            else:
                print(f"Removing duplicate reference: {ref}")
        
        # Rebuild the children list
        if unique_refs:
            new_children = '\n\t\t\t\t' + ',\n\t\t\t\t'.join(unique_refs) + ','
            
            # Replace the primary group's children
            pattern = f'({re.escape(primary_group_uuid)} /\\* Extensions \\*/ = {{[^}}]+children = \\()([^)]+)(\\);)'
            content = re.sub(pattern, f'\\g<1>{new_children}\\g<3>', content, flags=re.DOTALL)
    
    # Write the cleaned project file
    with open(project_file, 'w') as f:
        f.write(content)
    
    print("✅ Fixed duplicate group memberships")
    return True

if __name__ == '__main__':
    print("🔧 Cleaning up Xcode project duplicate group warnings...")
    success = fix_duplicate_group_memberships()
    if success:
        print("🎉 Project file cleaned successfully!")
    else:
        print("❌ Failed to clean project file")
        exit(1)