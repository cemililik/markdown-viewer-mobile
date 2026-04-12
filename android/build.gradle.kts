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

// Our own Kotlin code compiles to JVM target 17 via
// `compilerOptions.jvmTarget`. The Flutter plugins in our dependency
// tree (dynamic_color, receive_sharing_intent, and friends) still ship
// their Java sources targeting 1.8, which triggers the Kotlin 2.x
// plugin's "Inconsistent JVM-target compatibility" check during
// configuration — even though the resulting bytecode is runtime-safe
// on a Java 17 VM.
//
// We used to patch the plugins' JavaCompile tasks through
// `tasks.withType<JavaCompile>().configureEach { sourceCompatibility =
// "17" }`, but AGP sets those values during its own evaluation phase,
// *before* our `configureEach` callback realizes the task. The
// validation check reads the stale 1.8 value and aborts. Adding
// `plugins.withId("com.android.application") { extensions.configure
// <ApplicationExtension> { compileOptions { ... } } }` hit a symmetric
// problem: `compileOptions` is already finalized by the time the
// plugin callback fires.
//
// The supported escape hatch is the
// `kotlin.jvm.target.validation.mode=ignore` property set in
// `android/gradle.properties`. With that, the validation check is
// silenced and the build proceeds. This block only sets our own
// Kotlin jvmTarget 17 so we still emit modern bytecode for app code.
subprojects {
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
