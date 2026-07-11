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
    val projectDirName = project.projectDir.absolutePath
    val buildDirName = newBuildDir.asFile.absolutePath
    val projectDrive = if (projectDirName.length >= 2 && projectDirName[1] == ':') projectDirName.substring(0, 2).lowercase() else ""
    val buildDrive = if (buildDirName.length >= 2 && buildDirName[1] == ':') buildDirName.substring(0, 2).lowercase() else ""
    if (projectDrive == buildDrive) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}
subprojects {
    plugins.withId("com.android.library") {
        val androidComponents = extensions.findByType(com.android.build.api.variant.LibraryAndroidComponentsExtension::class.java)
        androidComponents?.beforeVariants { variantBuilder ->
            variantBuilder.enableUnitTest = false
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
