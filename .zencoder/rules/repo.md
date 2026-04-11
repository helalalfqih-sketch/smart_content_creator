---
description: Repository Information Overview
alwaysApply: true
---

# Smart Content Creator - Flutter Application

## Summary
Smart Content Creator is a multi-platform Flutter application for intelligent content generation and management. It uses Google Generative AI (Gemini), OpenAI, and Vision APIs to create professional marketing content. The app is Arabic-first with Material Design 3 support.

**Recent Updates (v1.1):**
- ✅ Added custom prompt TextField for user-specific commands
- ✅ New advertisement generation button with specialized Gemini function
- ✅ Enhanced text generation with generateCustomContent() and generateAdvertisement()
- ✅ Complete Arabic support with RTL alignment

## Structure
- **lib/**: Core application (main, screens, services, config)
- **lib/screens/**: 6 UI screens (Splash, Home, Upload, Trend, Settings, ContentPreview)
- **lib/services/**: AI integrations (GeminiService, OpenAIService, VisionService)
- **android/, ios/, windows/, linux/, macos/, web/**: Platform implementations
- **test/**: Flutter widget tests
- **assets/**: Fonts (IBM Plex Sans Arabic) and images

## Language & Runtime
**Language**: Dart  
**SDK Version**: >=3.3.0 <4.0.0  
**Framework**: Flutter >=3.22.0  
**Build System**: Flutter build system with Gradle, Xcode, CMake  
**Package Manager**: pub.dev

## Main Dependencies
- **google_generative_ai**: ^0.4.4 - Gemini AI integration
- **image_picker**: ^1.0.7 - Image/media selection
- **video_player**: ^2.7.2 - Video playback
- **http**: ^1.2.0 - HTTP requests
- **shared_preferences**: ^2.2.3 - Local storage for API keys
- **mime**: ^2.0.0 - MIME type detection
- **share_plus**: ^11.1.0 - Content sharing

## Build & Installation
\\\ash
flutter pub get                 # Get dependencies
flutter build apk               # Android APK
flutter build ios               # iOS app
flutter build windows           # Windows
flutter build web               # Web app
flutter run                     # Run on device
flutter analyze                 # Code analysis
dart format lib/                # Format code
\\\

## Main Files & Entry Points
- **lib/main.dart**: Application entry point
- **lib/screens/upload_screen.dart**: Main upload interface with new TextField for custom prompts
- **lib/services/gemini_service.dart**: Gemini integration with generateCustomContent() and generateAdvertisement()
- **lib/config.dart**: API configuration
- **test/widget_test.dart**: Widget tests

## New Features (v1.1)
- 🎯 **Custom Prompt TextField**: Write custom commands like "اصنع وصف تسويقي لعطر Royal Blue"
- 📢 **Advertisement Button**: Generate marketing ads with dedicated Gemini function
- 💬 **generateCustomContent()**: Accept user prompts with optional images
- 🎨 **generateAdvertisement()**: Specialized advertisement generation
- ✨ Complete Arabic RTL support

## Testing
**Framework**: Flutter Widget Testing (flutter_test)  
**Location**: test/  
**Run Command**:
\\\ash
flutter test
\\\

## Documentation Files
- **IMPLEMENTATION_NOTES_AR.md**: Detailed implementation guide
- **USAGE_GUIDE_AR.md**: Complete usage guide with examples
- **CODE_EXAMPLES.md**: Code snippets and references
- **README_IMPLEMENTATION.md**: Comprehensive overview
- **CHANGES_SUMMARY.md**: Quick summary of changes
- **FILE_INDEX.md**: File reference index

## Platform Support
Android, iOS, macOS, Windows, Linux, Web

**Status**: ✅ v1.1 Complete - Ready for Production
