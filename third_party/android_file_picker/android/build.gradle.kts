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

apply(plugin = "com.android.library")

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

dependencies {
    add("implementation", "androidx.core:core:1.18.0")
    add("implementation", "androidx.core:core-ktx:1.18.0")
    add("implementation", "androidx.annotation:annotation:1.10.0")
    add("implementation", "androidx.lifecycle:lifecycle-runtime:2.10.0")
}
