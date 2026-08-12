# FaceTune R8 / ProGuard rules for release builds.
#
# The Flutter Gradle plugin already contributes the engine's own rules. These
# entries cover the plugins this app depends on.

# Flutter embedding and deferred components referenced reflectively.
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Play Core is referenced by Flutter's deferred-components support but is not a
# dependency of this app, so R8 must not fail on the missing classes.
-dontwarn com.google.android.play.core.**

# OkHttp / Okio are pulled in transitively by the Supabase and image plugins.
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Kotlin coroutines internals accessed reflectively.
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**

# Keep annotations and generic signatures so JSON deserialization keeps working.
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*

# Do not strip line numbers; keep them mapped so release stack traces stay
# readable once a crash reporter is added. mapping.txt must be archived per build.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
