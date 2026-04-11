# ProGuard Rules for Smart Content Creator

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager

# Play Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# GetX - Prevent obfuscation of controllers and models used by GetX reflection
-keep class com.getx.** { *; }
-keep class com.example.smart_content_creator.controllers.** { *; }
-keep class com.example.smart_content_creator.models.** { *; }
-keepNames class com.example.smart_content_creator.controllers.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# FFmpeg Kit & Media Kit
-keep class com.arthurivanets.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**
-keep class com.unseen.media_kit.** { *; }
-keep class com.alexmercerind.media_kit.** { *; }

# Prevent stripping of the startup flow
-keep class com.example.smart_content_creator.screens.SplashScreen { *; }
-keep class com.example.smart_content_creator.MainActivity { *; }

# General
-dontwarn okio.**
-dontwarn javax.annotation.**
-ignorewarnings
-keepattributes Signature,Exceptions,InnerClasses,SourceFile,LineNumberTable
