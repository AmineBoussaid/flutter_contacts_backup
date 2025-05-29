import org.gradle.api.tasks.Delete
import com.android.build.gradle.BaseExtension

// ✅ Correct Kotlin DSL buildscript block
buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.7.10")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(name)
    layout.buildDirectory.set(newSubprojectBuildDir)
}

// ✅ Optional: patch missing namespace (safe to keep)
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            extensions.findByType(BaseExtension::class.java)?.let { androidExt ->
                if (androidExt.namespace == null) {
                    androidExt.namespace = "patched.${project.name}"
                }
            }
        }
    }

    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
