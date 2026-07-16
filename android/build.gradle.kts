buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.11.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
    }
}

import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory



val rootBuildDir = layout.projectDirectory.dir("../build")

allprojects {
    val relativePath = project.projectDir.path.replace(rootProject.projectDir.path, "").trimStart('\\', '/')
    val targetDir = if (relativePath.isEmpty()) {
        rootBuildDir
    } else {
        rootBuildDir.dir(relativePath.replace('\\', '/'))
    }
    layout.buildDirectory.set(targetDir)
}

subprojects {
    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
            
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


// Hint for local testing: Android emulator uses 10.0.2.2 to reach host's 127.0.0.1.
// This extra property can be read by the app or by dev scripts.
extra["llavaEmulatorHost"] = "10.0.2.2"

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.arthenica.com")
            content {
                includeGroupAndSubgroups("com.arthenica")
            }
        }
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("https://jitpack.io") }
    }
}
