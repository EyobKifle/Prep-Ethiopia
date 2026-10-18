import com.android.build.api.dsl.LibraryExtension
import org.gradle.kotlin.dsl.configure

group = "com.mr.flutter.plugin.filepicker"
version = "1.0-SNAPSHOT"

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val agpVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION
    .substringBefore('.')
    .toInt()
val builtInKotlinProperty = providers.gradleProperty("android.builtInKotlin").orNull
val isBuiltInKotlinEnabled = agpVersion >= 9 &&
    (builtInKotlinProperty == null || builtInKotlinProperty.toBoolean())
val shouldApplyKotlinAndroidPlugin = agpVersion < 9 || !isBuiltInKotlinEnabled

apply(plugin = "com.android.library")
if (shouldApplyKotlinAndroidPlugin) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

val flutterCompileSdkVersion = 36

configure<LibraryExtension> {
    compileSdk = flutterCompileSdkVersion
    namespace = "com.mr.flutter.plugin.filepicker"

    defaultConfig {
        minSdk = 21
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("proguard-rules.pro")
    }

    lint {
        disable += "InvalidPackage"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

if (shouldApplyKotlinAndroidPlugin) {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

dependencies {
    add("implementation", "androidx.core:core:1.18.0")
    add("implementation", "androidx.core:core-ktx:1.18.0")
    add("implementation", "androidx.annotation:annotation:1.10.0")
    add("implementation", "androidx.lifecycle:lifecycle-runtime:2.10.0")
}
