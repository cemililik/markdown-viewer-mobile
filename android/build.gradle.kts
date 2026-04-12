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
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force every Android subproject (the app and every plugin) to compile
// with Java 17 source/target and Kotlin jvmTarget 17. Without this,
// individual Flutter plugins (e.g. receive_sharing_intent) compile
// their Java with target 1.8 while their Kotlin runs at 17, which
// fails the "Inconsistent JVM-target compatibility" check on AGP 8+.
//
// Two important details:
//
// 1. The configuration happens directly inside `plugins.withId { ... }`
//    rather than inside `subprojects { afterEvaluate { ... } }`. The
//    outer block that runs `project.evaluationDependsOn(":app")` a few
//    lines above forces some subprojects to finish evaluating before
//    a later `afterEvaluate { ... }` can register, and newer Gradle
//    rejects that with "Cannot run Project.afterEvaluate(Action) when
//    the project is already evaluated". `plugins.withId` fires as soon
//    as the plugin is applied, so it is safe regardless of evaluation
//    ordering.
//
// 2. The extension types are `com.android.build.api.dsl.LibraryExtension`
//    and `ApplicationExtension`, the public DSL introduced by AGP 8.
//    The legacy `com.android.build.gradle.{AppExtension,LibraryExtension}`
//    classes are internal and not safe to configure against in new
//    projects.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension>(
            "android",
        ) {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.api.dsl.ApplicationExtension>(
            "android",
        ) {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    // Kotlin 2.x removed the old `kotlinOptions { jvmTarget = "17" }`
    // DSL at error severity; the replacement is `compilerOptions` with
    // a typed `JvmTarget` enum. See https://kotl.in/u1r8ln.
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
