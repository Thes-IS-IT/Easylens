# Google ML Kit rules
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# MediaPipe rules
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Google Maps SDK & Play Services rules for Release APK
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.maps.**

-keep class com.google.android.gms.location.** { *; }
-keep interface com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.location.**

-keep class com.google.android.gms.common.** { *; }
-keep interface com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.common.**

-keep class io.flutter.plugins.googlemaps.** { *; }
-dontwarn io.flutter.plugins.googlemaps.**

# Preserve Flutter Platform Views
-keep class io.flutter.plugin.platform.** { *; }
-dontwarn io.flutter.plugin.platform.**
