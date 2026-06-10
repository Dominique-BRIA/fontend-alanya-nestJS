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

// CORRECTION FINALE : Injection précoce de la version du SDK avant la lecture par AGP
subprojects {
    beforeEvaluate {
        setProperty("android.compileSdkVersion", 36)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
