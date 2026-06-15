# Add project specific ProGuard rules here.
-keepattributes *Annotation*
-keep class com.manwen.app.** { *; }

# Flutter embedding may reference AGP internal classes; keep them harmless
-dontwarn com.android.build.**
-keep class com.android.build.** { *; }

# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
