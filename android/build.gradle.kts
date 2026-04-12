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
// Implementation note: we configure the compile *tasks* directly
// instead of writing through the Android extension's compileOptions
// DSL. Earlier revisions of this block used
// `plugins.withId("com.android.application") { extensions.configure
// <ApplicationExtension> { compileOptions { ... } } }`, but on recent
// AGP / Gradle the `compileOptions` property is already finalized by
// the time `plugins.withId` fires, so the assignment crashes with
// "sourceCompatibility has been finalized". Patching the JavaCompile
// and KotlinCompile tasks via `tasks.withType(...).configureEach`
// runs late enough to survive that lifecycle and still overrides the
// Flutter plugins' defaults before the compilation tasks execute.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
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
