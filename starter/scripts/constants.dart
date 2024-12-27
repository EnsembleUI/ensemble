const authProguardRules = '''
# Keep Google Play Services Auth classes
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep Firebase-related classes
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep other necessary classes for Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
''';

const connectProguardRules = '''
# OkHttp
-dontwarn okhttp3.logging.**
-keep class okhttp3.logging.** { *; }

# Conscrypt
-dontwarn org.conscrypt.**
-keep class org.conscrypt.** { *; }

# Bouncy Castle
-dontwarn org.bouncycastle.**
-keep class org.bouncycastle.** { *; }

# Apache Harmony
-dontwarn org.apache.harmony.**
-keep class org.apache.harmony.** { *; }

# General SSL
-dontwarn javax.net.ssl.**
-keep class javax.net.ssl.** { *; }
''';
