android {
    namespace = "com.example.alanya"
    
    // CORRECTION : On utilise la propriété moderne 'compileSdk' à la place de 'compileSdkVersion'
    compileSdk = 36
    
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.alanya"
        minSdk = flutter.minSdkVersion
        
        // CORRECTION : On force aussi le targetSdk à 36 pour éviter les surprises
        targetSdk = 36
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
