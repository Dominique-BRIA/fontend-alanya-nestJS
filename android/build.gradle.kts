allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirige les builds vers le dossier build Flutter standard
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// CORRECTION DEFINITIVE : Force le SDK de manière sécurisée via les extensions de projet
subprojects {
    project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
        compileSdkVersion(36)
    }
    // Couverture pour les plugins utilisant le nouveau format d'extension découplé
    project.extensions.findByName("android")?.let { androidExtension ->
        if (androidExtension is com.android.build.gradle.BaseExtension) {
            androidExtension.compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
