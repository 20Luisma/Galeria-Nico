import java.io.File
import java.util.Properties

// Carga de las propiedades del keystore
val keystoreProperties = Properties()
val keystorePropertiesFile = File(project.rootDir, "key.properties")

if (keystorePropertiesFile.exists()) {
    println("DEBUG: key.properties encontrado en: ${keystorePropertiesFile.absolutePath}")
    keystorePropertiesFile.inputStream().use {
        keystoreProperties.load(it)
    }
} else {
    println("ERROR: key.properties NO ENCONTRADO en: ${keystorePropertiesFile.absolutePath}.")
    throw GradleException("Archivo key.properties no encontrado en ${keystorePropertiesFile.absolutePath}. La compilación de APK de release requiere este archivo.")
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nikoazaretto.galeria"

    // ✅ Actualizado a API 36
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.nikoazaretto.galeria"
        minSdk = flutter.minSdkVersion
        // ✅ Target SDK actualizado a 36
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
                ?: throw GradleException("Propiedad 'storeFile' no encontrada en key.properties")

            storeFile = rootProject.file(storeFilePath)

            storePassword = keystoreProperties.getProperty("storePassword")
                ?: throw GradleException("Propiedad 'storePassword' no encontrada en key.properties")
            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: throw GradleException("Propiedad 'keyAlias' no encontrada en key.properties")
            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: throw GradleException("Propiedad 'keyPassword' no encontrada en key.properties")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-ktx:1.9.2")
    implementation("com.google.android.material:material:1.12.0")
}
