# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ CRITICAL SETUP REQUIREMENTS - READ FIRST

**ALWAYS USE ULTRA THINK MODE** - Enable detailed reasoning for all tasks in this repository.

**DEVICE CONSTRAINTS:**
- Only deploy to Parth's iPhone 14 Pro Max (iOS 26)
- NEVER use simulator - CallKit requires physical device
- NEVER attempt logging - it doesn't work on this setup
- Only CallKit interface for ALL calls - no custom app call screens

## Project Overview

The Telnyx WebRTC iOS SDK enables real-time voice communication on iOS devices. The project consists of:

- **TelnyxRTC Framework**: Core SDK providing WebRTC functionality
- **TelnyxWebRTCDemo**: Demo application showcasing SDK usage
- **TelnyxRTCTests**: Unit and integration tests for the SDK

## Development Setup

### Prerequisites
```bash
# Install dependencies
pod install

# Open workspace (never open .xcodeproj directly)
open TelnyxRTC.xcworkspace
```

### Build Commands
```bash
# Build SDK framework
xcodebuild -scheme "TelnyxRTC" -destination "generic/platform=iOS" -configuration Debug build

# Build demo app for device
xcodebuild -scheme "TelnyxWebRTCDemo" -destination "generic/platform=iOS" -configuration Debug -derivedDataPath /Users/Parth/Library/Developer/Xcode/DerivedData build

# ❌ DO NOT RUN TESTS - Physical device only, no automated testing
```

### Testing Commands
```bash
# ❌ DO NOT RUN TESTS - Use physical device only, no simulator testing in this setup
# Unit and UI tests are not run in this environment due to device-only constraints
```

## CRITICAL: Device Testing Requirements & Constraints

**⚠️ IMPORTANT: CallKit functionality ONLY works on physical iOS devices, NOT simulators.**

### Target Device Information - PARTH'S SETUP ONLY
- **Device**: Parth's iPhone 14 Pro Max (Physical) - iOS 26
- **Device ID**: 7D0E3815-43EF-57B3-881B-5F62DE000647
- **Deployment Command**: `xcrun devicectl device install app --device 7D0E3815-43EF-57B3-881B-5F62DE000647 [app_path]`

### Development Constraints - READ CAREFULLY
1. **NEVER START SIMULATOR** - Only use physical device
2. **NEVER TRY TO GET LOGS** - Logging is not working on this setup
3. **ONLY DEPLOY TO PARTH'S iPHONE** - Do not attempt other devices
4. **ALWAYS USE ULTRA THINK MODE** - Enable detailed reasoning for all tasks
5. **App location**: `/Users/Parth/Library/Developer/Xcode/DerivedData/TelnyxRTC-*/Build/Products/Debug-iphoneos/Telnyx\ WebRTC.app`

### Physical Device - NO LOGGING AVAILABLE
```bash
# ❌ DO NOT ATTEMPT - LOGGING DOES NOT WORK
# xcrun devicectl device log stream --device 7D0E3815-43EF-57B3-881B-5F62DE000647 --level debug

# ✅ Only check device connection if needed
xcrun devicectl list devices
```

## Architecture Overview

### Core Components

**TxClient** (`/TelnyxRTC/Telnyx/TxClient.swift`):
- Main SDK entry point
- WebSocket connection management
- Call lifecycle coordination

**Call** (`/TelnyxRTC/Telnyx/WebRTC/Call.swift`):
- Individual call management
- WebRTC peer connection handling
- Audio/video stream management

**Socket** (`/TelnyxRTC/Telnyx/Services/Socket.swift`):
- WebSocket communication with Telnyx backend
- Verto protocol message handling

**CallKit Integration** (`/TelnyxWebRTCDemo/Extensions/AppDelegateCallKitExtension.swift`):
- Native iOS call interface
- System call management
- Audio session handling

### Demo App Structure

**HomeViewController** (`/TelnyxWebRTCDemo/ViewControllers/HomeViewController.swift`):
- Main app controller
- TxClient initialization and management

**HomeView** (`/TelnyxWebRTCDemo/Views/HomeView.swift`):
- SwiftUI main interface
- Call controls and status display

**Professional Views** (`/TelnyxWebRTCDemo/Views/Professional/`):
- Modern glassmorphism UI components
- Contacts, recents, and settings screens

### Key Dependencies

- **WebRTC**: Core WebRTC functionality
- **Starscream**: WebSocket implementation
- **Firebase**: Analytics and crash reporting (demo app)
- **ReachabilitySwift**: Network connectivity monitoring

## CallKit Architecture (Current State)

### ✅ **CALLKIT-ONLY IMPLEMENTATION COMPLETE**
- **Architecture Decision**: Moved from dual screen approach to CallKit-only for optimal iOS experience
- **Custom UI Disabled**: Removed all custom call screen presentations from HomeView.swift
- **Backend Simplified**: Cleaned up CallInterfaceRouter coordination code
- **INCOMING CALLS**: Only CallKit native interface, no custom app screens
- **OUTGOING CALLS**: Only CallKit native interface, no custom app screens  
- **Result**: CallKit handles 100% of call presentation (incoming, outgoing, active calls) - NO app-specific call screens

### Key Integration Points

**AppDelegateCallKitExtension.swift**:
- CXProviderDelegate implementation
- Call start/end/hold actions
- Audio session management

**HomeViewController+VoIPExtension.swift**:
- TxClientDelegate implementation
- VoIP push notification handling
- CallKit event coordination

## Configuration

### Pre-call Diagnosis Setup
Edit `Config.xcconfig`:
```
PHONE_NUMBER = +15551234567
```

### SIP Credentials
The demo app supports both:
- Username/password authentication
- JWT token authentication (recommended)

### Region Selection
Available regions: Auto, US East, US Central, US West, Canada Central, Europe, Asia Pacific

## Important Development Notes

### CallKit Requirements
- Must use physical device for testing
- Requires VoIP background mode capability
- Must implement CXProviderDelegate properly
- Audio session must be managed through CallKit

### Push Notifications
- VoIP push notifications require Apple Developer certificates
- Push notification tool available in `/push-notification-tool/`
- Must register device token with Telnyx backend

### Testing Strategy
- NO AUTOMATED TESTING in this environment - Physical device only setup
- All testing must be done manually on Parth's iPhone 14 Pro Max (iOS 26)
- CallKit features can only be tested on physical device
- Use test SIP credentials for any manual testing

### Debug Logging
- ❌ LOGGING DOES NOT WORK in this setup - Do not attempt to get device logs
- Code-level logging in TxConfig may still work for debugging app behavior
- WebRTC stats with `debug: true` flag may provide some insights
- Custom loggers supported via TxLogger protocol for in-app logging only

## ⚠️ Known Issues

### iOS 18 CallKit Automatic UI Switching (CRITICAL)
**Status**: 🔴 UNRESOLVED - Requires further investigation

**Issue**: On iOS 18 (particularly Dynamic Island devices like iPhone 14 Pro Max), CallKit does not automatically switch from app UI to system UI for calls. Users must manually switch between app and CallKit screens.

**Symptoms**:
- Outgoing calls: App remains in foreground instead of automatically showing CallKit system UI
- Incoming calls: May require manual switching to see native CallKit interface
- Users lose the seamless native iOS call experience

**Root Cause**: iOS 18 behavior change confirmed in Apple Developer Forums
- Dynamic Island devices have different CallKit behavior than iOS 17
- Apps now "stay in foreground" instead of CallKit automatically taking over
- This affects multiple VoIP apps, not just Telnyx implementation

**Research Completed**:
- ✅ Researched official Apple CallKit documentation (2024-2025)
- ✅ Found confirmed iOS 18 behavior changes in Apple Developer Forums
- ✅ Implemented all recommended iOS 18 compatibility fixes:
  - Fixed CXProviderConfiguration for iOS 18 compatibility
  - Eliminated CallInterfaceRouter dual-screen logic (100% CallKit-only)
  - Enhanced minimizeAppForCallKit() with iOS 18-specific backgrounding
  - Added proper background notifications and timing delays

**Attempted Solutions** (All unsuccessful):
- CXProviderConfiguration iOS 18 compatibility settings
- Enhanced app lifecycle management for background transition
- Eliminated routing decisions causing dual-screen confusion  
- Window interaction disabling to prevent UI interference

**Apple Developer Forum References**:
- iOS 18 Different Behavior in CallKit with Dynamic Island (Thread #764532)
- CallKit screen briefly enters foreground issues (Thread #762925)
- Multiple developers reporting same issue on iOS 18 + Dynamic Island devices

**Next Steps for Future Investigation**:
1. Monitor Apple Developer Forums for official iOS 18.x+ CallKit updates
2. Consider filing bug report with Apple (FB number TBD)
3. Investigate if iOS 18.1+ releases address this issue
4. Test on non-Dynamic Island devices to isolate to hardware-specific behavior
5. Research if specific CXProvider timing or sequencing resolves the issue

**Workaround**: Users must manually switch to CallKit system UI during calls until resolved.

**Impact**: UX degradation - users lose seamless native iOS call experience that CallKit is designed to provide.