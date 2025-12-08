import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import org.jetbrains.kotlin.gradle.ExperimentalKotlinGradlePluginApi
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

val osName = System.getProperty("os.name").lowercase()
val osArch = System.getProperty("os.arch").lowercase()

val platformStr = when {
    osName.contains("win") -> {
        when {
            osArch.contains("aarch64") || osArch.contains("arm64") -> "windows_aarch64"
            osArch.contains("amd64") -> "windows_amd64"
            else -> "windows_386"
        }
    }
    osName.contains("mac") -> {
        if (osArch.contains("aarch64") || osArch.contains("arm")) "darwin_aarch64" else "darwin_amd64"
    }
    osName.contains("nix") || osName.contains("nux") -> {
        if (osArch.contains("aarch64") || osArch.contains("arm")) "linux_aarch64" else "linux_amd64"
    }
    else -> "unknown"
}

val proxyResourcesDir = layout.buildDirectory.dir("compose/proxy-resources")

val prepareProxyResources by tasks.registering(Copy::class) {
    val currentPlatform = platformStr
    val sourceDir = project.rootDir.resolve("fntv-proxy").resolve(currentPlatform)
    
    from(sourceDir)
    into(proxyResourcesDir.map { it.dir("fntv-proxy/$currentPlatform") })
    
    doFirst {
        if (!sourceDir.exists()) {
             throw GradleException("Proxy executable not found at ${sourceDir.absolutePath}")
        }
    }
}

// Tasks will be configured after project evaluation to ensure task existence
afterEvaluate {
    tasks.findByName("processJvmMainResources")?.dependsOn(prepareProxyResources)
    tasks.findByName("jvmProcessResources")?.dependsOn(prepareProxyResources)
    tasks.findByName("processResources")?.dependsOn(prepareProxyResources)
}

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    alias(libs.plugins.composeHotReload)
}

kotlin {
    androidTarget {
        @OptIn(ExperimentalKotlinGradlePluginApi::class)
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_11)
        }
    }

    jvm()
    
    sourceSets {
        androidMain.dependencies {
            implementation(compose.preview)
            implementation(libs.androidx.activity.compose)
        }
        commonMain.dependencies {
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.ui)
            implementation(compose.components.resources)
            implementation(compose.components.uiToolingPreview)
            implementation(libs.androidx.lifecycle.viewmodelCompose)
            implementation(libs.androidx.lifecycle.runtimeCompose)
            implementation(libs.ktor.http)
            implementation(libs.fluent.ui)
            implementation(libs.fluent.icons)
            implementation(libs.window.styler)
            implementation(libs.ktor.client.core)
            implementation(libs.ktor.client.content.negotiation)
            implementation(libs.ktor.serialization.kotlinx.json)
            implementation(libs.ktor.client.okhttp)
            implementation(libs.ktor.serialization.jackson)
            implementation(libs.krypto)
            implementation(libs.kotlin.reflect)
            implementation(libs.jackson.databind)
            implementation(libs.jackson.module.kotlin)
            implementation(libs.koin.compose)
            implementation(libs.koin.compose.viewmodel)
            implementation(libs.coil.compose)
            implementation(libs.coil.network.okhttp)
            implementation(libs.mediamp.all)
            implementation(libs.kotlinx.collections.immutable)
            implementation(libs.androidx.collection)
            implementation(libs.multiplatform.settings)
            implementation(libs.multiplatform.settings.no.arg)
            implementation(libs.haze)
            implementation(libs.haze.materials)
            implementation(libs.kotlinx.datetime)
            implementation(libs.kermit)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }
        jvmMain.dependencies {
            implementation(compose.desktop.currentOs)
            implementation(libs.kotlinx.coroutinesSwing)
            implementation(libs.androidx.runtime.desktop)
//            implementation(libs.vlcj)
            implementation(libs.oshi.core)
            implementation(libs.versioncompare)
            implementation(files("libs/jSystemThemeDetector-3.8.jar"))
//            implementation(libs.mediamp.vlc)
//            implementation(libs.mediamp.vlc.compose)
        }
    }
    
    sourceSets.named("jvmMain") {
        resources.srcDir(proxyResourcesDir)
    }
}


compose.desktop {
    application {
        mainClass = "com.jankinwu.fntv.client.MainKt"

        buildTypes.release.proguard {
            isEnabled = false
//            configurationFiles.from("compose-desktop.pro")
        }
        nativeDistributions {
            targetFormats(TargetFormat.Dmg, TargetFormat.Deb, TargetFormat.Exe, TargetFormat.Rpm)
            // 使用英文作为包名，避免Windows下打包乱码和路径问题
            // Use English package name to avoid garbled text on Windows
            packageName = "FnMedia"
            packageVersion = "1.0.0"
            // Description acts as the process name in Task Manager. Using Chinese here causes garbled text due to jpackage limitations.
            description = "FnMedia"
            vendor = "JankinWu"
            appResourcesRootDir.set(proxyResourcesDir)

            modules("jdk.unsupported")
            windows {
                iconFile.set(project.file("icons/favicon.ico"))
                shortcut = true
                menu = true
                menuGroup = "FnMedia"
                console = false
                dirChooser = true
                upgradeUuid = "9A262498-6C63-4816-A346-056028719600"
            }
            macOS {
                iconFile.set(project.file("icons/favicon.icns"))
                dockName = "飞牛影视"
                setDockNameSameAsPackageName = false
            }
            linux {
                iconFile.set(project.file("icons/favicon.png"))
                packageName = "fntv-client"
                shortcut = true
            }
        }
    }
}

dependencies {
    debugImplementation(compose.uiTooling)
}


android {
    namespace = "com.jankinwu.fntv.client"
    compileSdk = libs.versions.android.compileSdk.get().toInt()

    defaultConfig {
        applicationId = "com.jankinwu.fntv.desktop"
        minSdk = libs.versions.android.minSdk.get().toInt()
        targetSdk = libs.versions.android.targetSdk.get().toInt()
        versionCode = 1
        versionName = "1.0"
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

tasks.withType<org.jetbrains.compose.desktop.application.tasks.AbstractJPackageTask>().configureEach {
    dependsOn(prepareProxyResources)
}

tasks.withType<org.jetbrains.compose.desktop.application.tasks.AbstractRunDistributableTask>().configureEach {
    dependsOn(prepareProxyResources)
}