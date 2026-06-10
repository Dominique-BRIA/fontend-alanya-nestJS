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

// FORCE LE SDK VIA LA CONFIGURATION DYNAMIQUE DES PLUGINS
subprojects {
    project.plugins.withId("com.android.library") {
        project.extensions.getByType<com.android.build.gradle.LibraryExtension>().apply {
            compileSdk = 36
        }
    }
    project.plugins.withId("com.android.application") {
        project.extensions.getByType<com.android.build.gradle.AppExtension>().apply {
            compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
