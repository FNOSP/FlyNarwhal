import org.gradle.api.tasks.JavaExec
import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import org.jetbrains.kotlin.gradle.ExperimentalKotlinGradlePluginApi
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.io.ByteArrayOutputStream
import java.net.URL
import java.net.HttpURLConnection

val osName = System.getProperty("os.name").lowercase()
val osArch = System.getProperty("os.arch").lowercase()

val appVersion = "1.7.3"
val appVersionSuffix = ""

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
val allAppResourcesDir = layout.buildDirectory.dir("compose/all-app-resources")

val kcefPreparedDir = layout.buildDirectory.dir("kcef/prepared")

val kcefDownloaderClasspath by configurations.creating {
    isCanBeConsumed = false
    isCanBeResolved = true
}

dependencies {
    add(
        kcefDownloaderClasspath.name,
        if (System.getProperty("os.name").lowercase().contains("win")) {
            "dev.datlag:kcef:2024.04.20.4"
        } else {
            libs.kcef.get().toString()
        }
    )
    add(kcefDownloaderClasspath.name, libs.ktor.client.core.get().toString())
    add(kcefDownloaderClasspath.name, libs.ktor.client.okhttp.get().toString())
    add(kcefDownloaderClasspath.name, libs.ktor.client.content.negotiation.get().toString())
    add(kcefDownloaderClasspath.name, libs.ktor.serialization.kotlinx.json.get().toString())
    add(kcefDownloaderClasspath.name, libs.ktor.http.get().toString())
}

val downloadKcefBundle by tasks.registering(JavaExec::class) {
    val compileKotlinJvmTask = tasks.named<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>("compileKotlinJvm")
    dependsOn(compileKotlinJvmTask)

    mainClass.set("com.jankinwu.fntv.client.utils.KcefBundleDownloader")

    val installDir = kcefPreparedDir.map { it.dir("kcef-bundle") }
    val cacheDir = kcefPreparedDir.map { it.dir("kcef-cache") }
    val logDir = kcefPreparedDir.map { it.dir("kcef-logs") }

    val installDirFile = installDir.get().asFile

    val classesDir = compileKotlinJvmTask.flatMap { it.destinationDirectory }
    classpath = files(classesDir, kcefDownloaderClasspath)

    onlyIf {
        !installDirFile.exists() || installDirFile.listFiles()?.isEmpty() != false
    }

    doFirst {
        installDirFile.deleteRecursively()
        cacheDir.get().asFile.deleteRecursively()
        logDir.get().asFile.deleteRecursively()
    }

    systemProperty("java.awt.headless", "false")

    args(
        installDir.get().asFile.absolutePath,
        cacheDir.get().asFile.absolutePath,
        logDir.get().asFile.absolutePath,
        "1800"
    )

    outputs.dir(installDir)

    enabled = osName.contains("win")
}

val prepareKcefResources by tasks.registering(Copy::class) {
    dependsOn(downloadKcefBundle)

    val sourceDir = kcefPreparedDir.map { it.dir("kcef-bundle") }
    from(sourceDir)
    into(proxyResourcesDir.map { it.dir("kcef-bundle") })

    enabled = osName.contains("win")
}

val prepareProxyResources by tasks.registering(Copy::class) {
    val sourceDir = project.rootDir.resolve("fntv-proxy")
    
    from(sourceDir)
    into(proxyResourcesDir.map { it.dir("fntv-proxy") })
    
    doFirst {
        if (!sourceDir.exists()) {
             throw GradleException("Proxy executable directory not found at ${sourceDir.absolutePath}")
        }
    }
}

fun resolveFlutterExecutable(project: Project): File? {
    val explicit = System.getenv("FLUTTER_EXECUTABLE")?.trim().orEmpty()
    if (explicit.isNotBlank()) return File(explicit)

    val flutterHome = System.getenv("FLUTTER_HOME")?.trim()
        ?: System.getenv("FLUTTER_ROOT")?.trim()
        ?: System.getenv("FLUTTER_SDK")?.trim()

    if (!flutterHome.isNullOrBlank()) {
        val flutterBin = File(flutterHome, "bin")
        val flutterBat = File(flutterBin, "flutter.bat")
        val flutterExe = File(flutterBin, "flutter")
        val result = when {
            flutterBat.exists() -> flutterBat
            flutterExe.exists() -> flutterExe
            else -> null
        }
        if (result != null) return result
    }

    val localFlutterBat = project.rootDir.resolve("flutter/bin/flutter.bat")
    if (localFlutterBat.exists()) return localFlutterBat

    return listOf(
        File(System.getProperty("user.home"), "sdk/flutter/bin/flutter"),
        File(System.getProperty("user.home"), "sdk/flutter/bin/flutter.bat"),
        File(System.getProperty("user.home"), "fvm/default/bin/flutter"),
        File("/opt/homebrew/bin/flutter"),
        File("/usr/local/bin/flutter"),
        File("C:/src/flutter/bin/flutter.bat")
    ).find { it.exists() }
}

val flutterPlayerProjectDir = project.rootDir.resolve("flutter-player")
val flutterTmpBuildRoot = File("/tmp/fntv_flutter_player_build")

val cleanFlutterPlayerDirs by tasks.registering(Delete::class) {
    delete(
        flutterPlayerProjectDir.resolve("build"),
        flutterPlayerProjectDir.resolve(".dart_tool"),
    )
    if (osName.contains("mac")) {
        delete(flutterTmpBuildRoot)
    }
}

val cleanFlutterPlayer by tasks.registering(Exec::class) {
    workingDir = flutterPlayerProjectDir

    val flutterExecutable = resolveFlutterExecutable(project)
    val flutterPath = flutterExecutable?.absolutePath ?: "flutter"

    notCompatibleWithConfigurationCache("Runs flutter clean; configuration cache is not supported for this Exec task.")

    if (osName.contains("win")) {
        commandLine("cmd", "/c", flutterPath, "clean")
    } else {
        commandLine(flutterPath, "clean")
    }

    dependsOn(cleanFlutterPlayerDirs)
}

val buildFlutterPlayer by tasks.registering {
    // By default, we support incremental builds. Use 'rebuildFlutterPlayer' for a full clean build.
    notCompatibleWithConfigurationCache("Runs flutter build; configuration cache is not supported for this Exec task.")

    // Inputs for incremental build support
    inputs.dir(flutterPlayerProjectDir.resolve("lib"))
    inputs.dir(flutterPlayerProjectDir.resolve("assets"))
    inputs.file(flutterPlayerProjectDir.resolve("pubspec.yaml"))

    doLast {
        val targetOs = when {
            osName.contains("win") -> "windows"
            osName.contains("mac") -> "macos"
            else -> "linux"
        }

        val flutterExecutable = resolveFlutterExecutable(project)
        println("Flutter executable: ${flutterExecutable?.absolutePath ?: "not found, using 'flutter' from PATH"}")

        val flutterPath = flutterExecutable?.absolutePath ?: "flutter"

        fun readFlutterBuildDir(): String? {
            val output = ByteArrayOutputStream()
            project.exec {
                workingDir = flutterPlayerProjectDir
                commandLine(flutterPath, "config", "--machine")
                standardOutput = output
            }

            val json = output.toString(Charsets.UTF_8).trim()
            val match = Regex("\"build-dir\"\\s*:\\s*\"([^\"]*)\"").find(json) ?: return null
            return match.groupValues.getOrNull(1)
        }

        fun setFlutterBuildDir(relativeBuildDir: String?) {
            val arg = if (relativeBuildDir.isNullOrBlank()) "--build-dir=" else "--build-dir=$relativeBuildDir"
            project.exec {
                workingDir = flutterPlayerProjectDir
                commandLine(flutterPath, "config", arg)
            }
        }

        val originalBuildDir = if (osName.contains("mac")) readFlutterBuildDir() else null
        val tempBuildDir = if (osName.contains("mac")) {
            flutterPlayerProjectDir.toPath().relativize(flutterTmpBuildRoot.toPath()).toString()
        } else {
            null
        }

        var buildFailure: Exception? = null
        if (osName.contains("mac")) {
            setFlutterBuildDir(tempBuildDir)
        }

        try {
            project.exec {
                workingDir = flutterPlayerProjectDir

                if (osName.contains("mac")) {
                    environment("CURL_CA_BUNDLE", "/etc/ssl/cert.pem")
                }

                if (osName.contains("win")) {
                    commandLine("cmd", "/c", flutterPath, "build", targetOs, "--release")
                } else {
                    commandLine(flutterPath, "build", targetOs, "--release")
                }
            }
        } catch (e: Exception) {
            buildFailure = e
        } finally {
            if (osName.contains("mac")) {
                setFlutterBuildDir(originalBuildDir)
            }
        }

        if (buildFailure != null) throw buildFailure
    }
}

val rebuildFlutterPlayer by tasks.registering {
    group = "flutter"
    description = "Cleans and rebuilds the Flutter player."
    dependsOn(cleanFlutterPlayer)
    dependsOn(buildFlutterPlayer)
}

val flutterHotRestart by tasks.registering {
    group = "flutter"
    description = "Triggers a hot-restart of the Flutter player if it was started via 'flutter run'."
    doLast {
        val playerPort = 47922
        try {
            val connection = URL("http://127.0.0.1:$playerPort/play").openConnection() as HttpURLConnection
            connection.connectTimeout = 500
            connection.readTimeout = 500
            if (connection.responseCode == 200) {
                logger.lifecycle("Flutter player is running. You can use hot-restart in your terminal where 'flutter run' is active.")
            } else {
                logger.warn("Flutter player is not responding on port $playerPort.")
            }
        } catch (e: Exception) {
            logger.warn("Could not connect to Flutter player. Make sure it's running via 'flutter run'.")
        }
    }
}

val prepareAllAppResources by tasks.registering(Copy::class) {
    dependsOn(prepareProxyResources, prepareUpdaterResources, buildFlutterPlayer)
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE

    // 1. Copy platform-specific resources from appResources/
    val currentPlatformDir = when {
        osName.contains("win") -> if (osArch.contains("aarch64") || osArch.contains("arm64")) "windows-arm64" else "windows-x64"
        osName.contains("mac") -> if (osArch.contains("aarch64") || osArch.contains("arm")) "macos-arm64" else "macos-x64"
        else -> if (osArch.contains("aarch64") || osArch.contains("arm")) "linux-arm64" else "linux-x64"
    }

    val archSpecificResources = project.file("appResources/$currentPlatformDir")
    if (archSpecificResources.exists()) {
        from(archSpecificResources)
    }

    // 2. Copy proxy resources
    from(proxyResourcesDir)

    // 3. Copy Flutter player output
    val flutterProjectDir = project.rootDir.resolve("flutter-player")
    val flutterSourceDir = when {
        osName.contains("win") -> {
            listOf(
                flutterProjectDir.resolve("build/windows/x64/runner/Release"),
                flutterProjectDir.resolve("build/windows/runner/Release")
            ).firstOrNull { it.exists() } ?: flutterProjectDir.resolve("build/windows/x64/runner/Release")
        }
        osName.contains("mac") -> {
            val tmpSource = flutterTmpBuildRoot.resolve("macos/Build/Products/Release")
            if (tmpSource.exists()) tmpSource else flutterProjectDir.resolve("build/macos/Build/Products/Release")
        }
        else -> flutterProjectDir.resolve("build/linux/x64/release/bundle")
    }

    if (osName.contains("mac")) {
        // On macOS, use rsync to preserve symlinks in the .app bundle
        doLast {
            if (flutterSourceDir.exists()) {
                val appBundle = flutterSourceDir.listFiles()?.find { it.name.endsWith(".app") }
                if (appBundle != null) {
                    val destDir = allAppResourcesDir.get().asFile
                    destDir.mkdirs()
                    
                    // Clean up existing .app bundle to avoid symlink issues
                    val existingApp = destDir.resolve(appBundle.name)
                    if (existingApp.exists()) {
                        logger.lifecycle("Cleaning up existing app bundle: ${existingApp.absolutePath}")
                        existingApp.deleteRecursively()
                    }

                    logger.lifecycle("Syncing Flutter app bundle using rsync: ${appBundle.absolutePath} -> ${existingApp.absolutePath}")
                    project.exec {
                        // Use rsync -a to preserve symlinks and -L is NOT used to keep them as links
                        // Ensure the destination is the full path including the .app folder name
                        commandLine("rsync", "-a", "--delete", appBundle.absolutePath + "/", existingApp.absolutePath + "/")
                    }
                }
            }
        }
    } else {
        from(flutterSourceDir) {
            if (flutterSourceDir.exists()) {
                if (osName.contains("win")) {
                    include("flutter-player.exe")
                    include("flutter_player.exe")
                    include("*.dll")
                    include("data/**")
                } else {
                    include("flutter-player")
                    include("flutter_player")
                    include("lib/**")
                    include("data/**")
                }
            }
        }
    }

    into(allAppResourcesDir)
}

val buildUpdater by tasks.registering(Exec::class) {
    val updaterDir = project.rootDir.resolve("fntv-updater")
    workingDir = updaterDir

    if (osName.contains("win")) {
        commandLine("cmd", "/c", "build.bat", platformStr)
    } else {
        commandLine("echo", "Skipping updater build: Not on Windows")
    }
}

val prepareUpdaterResources by tasks.registering(Copy::class) {
    dependsOn(buildUpdater)
    enabled = osName.contains("win")
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    
    val currentPlatform = platformStr
    val sourceDir = project.rootDir.resolve("fntv-updater/build").resolve(currentPlatform)
    
    from(sourceDir) {
        include("fntv-updater.exe")
    }
    into(proxyResourcesDir.map { it.dir("fntv-updater/$currentPlatform") })
}

val mergeResources by tasks.registering(Copy::class) {
    dependsOn(prepareProxyResources, prepareUpdaterResources, prepareKcefResources)
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    from(proxyResourcesDir)
    from(file("appResources"))
    dependsOn(prepareAllAppResources)
    from(allAppResourcesDir)
    into(layout.buildDirectory.dir("mergedResources"))
}

val stopFntvProxyBeforePackaging by tasks.registering(Exec::class) {
    enabled = osName.contains("win")
    isIgnoreExitValue = true
    commandLine(
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        "\$ErrorActionPreference='SilentlyContinue'; Get-Process fntv-proxy | Stop-Process -Force; exit 0"
    )
}

// Tasks will be configured after project evaluation to ensure task existence
afterEvaluate {
    // Ensure resources are prepared before processing
    listOf(
        "processJvmMainResources",
        "jvmProcessResources",
        "processResources",
        "prepareAppResources",
        "run",
        "jvmRun",
        "createDistributable",
        "createReleaseDistributable",
        "createDebugDistributable",
        "runDistributable",
        "runReleaseDistributable",
        "runDebugDistributable",
        "packageRelease",
        "packageDebug",
        "package"
    ).mapNotNull { tasks.findByName(it) }.forEach { task ->
        task.dependsOn(mergeResources)
        task.dependsOn(prepareAllAppResources)
        task.dependsOn(prepareUpdaterResources)
    }

    tasks.withType<org.jetbrains.compose.desktop.application.tasks.AbstractJPackageTask>().configureEach {
        dependsOn(mergeResources)
        dependsOn(stopFntvProxyBeforePackaging)
    }

    tasks.findByName("createDistributable")?.dependsOn(stopFntvProxyBeforePackaging)

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        dependsOn(generateBuildConfig)
        dependsOn(buildFlutterPlayer)
    }

    tasks.withType<JavaExec>().configureEach {
        jvmArgs("--add-opens", "java.desktop/sun.awt=ALL-UNNAMED")
        jvmArgs("--add-opens", "java.desktop/java.awt.peer=ALL-UNNAMED")

        if (project.hasProperty("dev")) {
            systemProperty("fntv.dev", "true")
        }

        if (System.getProperty("os.name").contains("Mac")) {
            jvmArgs("--add-opens", "java.desktop/sun.lwawt=ALL-UNNAMED")
            jvmArgs("--add-opens", "java.desktop/sun.lwawt.macosx=ALL-UNNAMED")
        }
    }
}

val buildConfigDir = layout.buildDirectory.dir("generated/source/buildConfig/commonMain")

val generateBuildConfig by tasks.registering {
    val outputDir = buildConfigDir
    val version = appVersion
    val suffix = appVersionSuffix

    // Read secrets from environment variables or project properties
    val reportApiSecret = System.getenv("REPORT_API_SECRET") ?: project.findProperty("REPORT_API_SECRET")?.toString() ?: ""
    val reportUrl = System.getenv("REPORT_URL") ?: project.findProperty("REPORT_URL")?.toString() ?: ""
    var flyNarwhalApiSecret = System.getenv("FLY_NARWHAL_API_SECRET") ?: project.findProperty("FLY_NARWHAL_API_SECRET")?.toString() ?: ""

    inputs.property("version", version)
    inputs.property("suffix", suffix)
    inputs.property("reportApiSecret", reportApiSecret)
    inputs.property("reportUrl", reportUrl)
    outputs.dir(outputDir)

    doLast {
        val fullVersion = if (suffix.isEmpty()) version else "$version-$suffix"
        val configFile = outputDir.get().file("com/jankinwu/fntv/client/BuildConfig.kt").asFile
        configFile.parentFile.mkdirs()
        configFile.writeText("""
            package com.jankinwu.fntv.client

            object BuildConfig {
                const val VERSION_NAME = "$fullVersion"
                const val REPORT_API_SECRET = "$reportApiSecret"
                const val REPORT_URL = "$reportUrl"
                const val FLY_NARWHAL_API_SECRET = "$flyNarwhalApiSecret"
            }
        """.trimIndent())
    }
}

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    // alias(libs.plugins.composeHotReload)
}

kotlin {
    jvmToolchain(21)

    @OptIn(ExperimentalKotlinGradlePluginApi::class)
    compilerOptions {
        freeCompilerArgs.add("-Xmulti-dollar-interpolation")
    }

    androidTarget {
        @OptIn(ExperimentalKotlinGradlePluginApi::class)
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_11)
        }
    }

    jvm()
    
    sourceSets {
        commonMain {
            kotlin.srcDir(buildConfigDir)
        }
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
            implementation(libs.kotlinx.io.core)
            implementation(libs.compottie)
            implementation(libs.filekit.core)
            implementation(libs.filekit.dialogs)
            implementation(libs.filekit.dialogs.compose)
            implementation(libs.filekit.coil)
            implementation(libs.multiplatform.markdown.renderer)
            implementation(libs.compose.webview)
            implementation(libs.com.saralapps.composemultiplatformwebview4)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }
        jvmMain.dependencies {
            implementation(compose.desktop.currentOs)
            implementation(libs.kotlinx.coroutinesSwing)
            implementation(libs.androidx.runtime.desktop)
            if (System.getProperty("os.name").lowercase().contains("win")) {
                implementation("dev.datlag:kcef:2024.04.20.3")
            } else {
                implementation(libs.kcef)
            }
//            implementation(libs.kcef)
            implementation(libs.ktor.server.core)
            implementation(libs.ktor.server.netty)
            implementation(libs.ktor.server.content.negotiation)
//            implementation(libs.vlcj)
            implementation(libs.oshi.core)
            implementation(libs.versioncompare)
            implementation(libs.jSystemThemeDetector)
            implementation(libs.jfa.get().toString()) {
                exclude(group = "net.java.dev.jna")
            }
//            implementation(libs.jna)
        }
    }
    
    sourceSets.named("jvmMain") {
        resources.srcDir(proxyResourcesDir)
    }
}


compose.desktop {
    application {
        mainClass = "com.jankinwu.fntv.client.MainKt"
        val macJvmArgs = listOf(
            "--add-opens", "java.desktop/sun.awt=ALL-UNNAMED",
            "--add-opens", "java.desktop/java.awt.peer=ALL-UNNAMED",
            "--add-opens", "java.desktop/sun.lwawt=ALL-UNNAMED",
            "--add-opens", "java.desktop/sun.lwawt.macosx=ALL-UNNAMED"
        )
        if (osName.contains("mac")) {
            jvmArgs += macJvmArgs
        }

        buildTypes.release.proguard {
            isEnabled = true
            obfuscate.set(true)
            configurationFiles.from(project.rootDir.resolve("compose-desktop.pro"))
        }
        nativeDistributions {
            if (osName.contains("mac")) {
                outputBaseDir.set(
                    layout.dir(
                        providers.provider {
                            File(System.getProperty("java.io.tmpdir")).resolve("FlyNarwhal-compose-binaries")
                        }
                    )
                )
            }

            targetFormats(TargetFormat.Dmg, TargetFormat.Deb, TargetFormat.Exe, TargetFormat.Rpm, TargetFormat.Pkg)
            // 使用英文作为包名，避免Windows下打包乱码和路径问题
            // Use English package name to avoid garbled text on Windows
            packageName = "FlyNarwhal"
            packageVersion = appVersion
            // Description acts as the process name in Task Manager. Using Chinese here causes garbled text due to jpackage limitations.
            description = "FlyNarwhal"
            vendor = "JankinWu"
            appResourcesRootDir.set(layout.buildDirectory.dir("mergedResources"))
            modules("jdk.unsupported")
            windows {
                iconFile.set(project.file("icons/favicon.ico"))
                shortcut = true
                menu = true
                menuGroup = "FlyNarwhal"
                console = false
                dirChooser = true
                upgradeUuid = "9A262498-6C63-4816-A346-056028719600"
            }
            macOS {
                iconFile.set(project.file("icons/favicon.icns"))
                dockName = "飞鲸影视"
                setDockNameSameAsPackageName = false
                // 设置最低支持的 macOS 版本，确保在 macOS 14 上构建的包也能在旧系统运行
                minimumSystemVersion = "11.0"
            }
            linux {
                iconFile.set(project.file("icons/favicon.png"))
                packageName = "fly-narwhal"
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
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

tasks.withType<org.jetbrains.compose.desktop.application.tasks.AbstractJPackageTask>().configureEach {
    dependsOn(prepareAllAppResources)
    dependsOn(prepareUpdaterResources)
    val version = appVersion

    doLast {
        val destDir = destinationDir.get().asFile
        val currentOs = System.getProperty("os.name").lowercase()
        val osName = when {
            currentOs.contains("mac") -> "MacOS"
            currentOs.contains("nix") || currentOs.contains("nux") -> "Linux"
            else -> "Unknown"
        }
        val arch = System.getProperty("os.arch").lowercase().let {
            when (it) {
                "x86_64" -> "amd64"
                else -> it
            }
        }
        
        destDir.listFiles()?.forEach { file ->
            val ext = file.extension
            if (ext in listOf("dmg", "deb", "rpm")) {
                val newName = "FlyNarwhal_Setup_${osName}_${arch}_${version}.${ext}"
                val newFile = file.parentFile.resolve(newName)
                if (file.name != newName) {
                    file.renameTo(newFile)
                    logger.lifecycle("Renamed output to: ${newFile.name}")
                }
            }
        }
    }
}

tasks.withType<org.jetbrains.compose.desktop.application.tasks.AbstractRunDistributableTask>().configureEach {
    dependsOn(mergeResources)
}

/*
// Fix for ProGuard crashing on newer Kotlin module metadata
tasks.withType<Jar>().configureEach {
    exclude("META-INF/*.kotlin_module")
}
*/
