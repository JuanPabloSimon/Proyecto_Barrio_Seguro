import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Datos de la firma de release. key.properties y el archivo .jks no se
// suben al repositorio (están en android/.gitignore): cada uno los tiene
// en su computadora. Sin ellos, la versión de release se firma con la
// clave de debug y sirve para probar, no para publicar.
val propiedadesDeFirma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
}
val hayFirmaDeRelease = propiedadesDeFirma.containsKey("storeFile")

android {
    namespace = "com.barrioseguro.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Lo pide flutter_local_notifications: permite usar APIs nuevas de
        // Java en versiones viejas de Android ("desugaring").
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identifica a la app en Google Play: una vez publicada, no se cambia.
        applicationId = "com.barrioseguro.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hayFirmaDeRelease) {
                keyAlias = propiedadesDeFirma.getProperty("keyAlias")
                keyPassword = propiedadesDeFirma.getProperty("keyPassword")
                storeFile = file(propiedadesDeFirma.getProperty("storeFile"))
                storePassword = propiedadesDeFirma.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hayFirmaDeRelease) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
