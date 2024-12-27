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
-keep class okhttp3.logging.HttpLoggingInterceptor { *; }

# Keep other relevant classes as before
-keep class com.android.org.conscrypt.** { *; }
-keep class org.conscrypt.** { *; }
-keep class org.bouncycastle.jsse.** { *; }
-keep class org.bouncycastle.jsse.provider.BouncyCastleJsseProvider { *; }
''';
