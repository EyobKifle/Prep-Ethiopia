allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val project = this
    project.evaluationDependsOn(":app")
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Force compileSdk and targetSdk for all Android subprojects (plugins)
    // to resolve "checkDebugAarMetadata" failures.
    // SDK versions configured in app module
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

