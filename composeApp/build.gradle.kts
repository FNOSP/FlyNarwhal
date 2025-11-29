import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import org.jetbrains.kotlin.gradle.ExperimentalKotlinGradlePluginApi
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

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
            packageName = "FNTVClient"
            packageVersion = "1.0.0"
            modules("jdk.unsupported")
            windows {
                iconFile.set(project.file("icons/favicon.ico"))
                shortcut = true
                menu = true
                menuGroup = "飞牛影视"
                console = false
                dirChooser = true
            }
            macOS {
                iconFile.set(project.file("icons/favicon.icns"))
                dockName = "飞牛影视"
                setDockNameSameAsPackageName = false
            }
            linux {
                iconFile.set(project.file("icons/favicon.png"))
                packageName = "飞牛影视"
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