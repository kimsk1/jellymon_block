import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val pluginName = "HiveBridge"
val pluginPackageName = "com.jellymon.hive"

android {
    namespace = pluginPackageName
    compileSdk = 36

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = pluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
        buildConfigField("String", "GODOT_PLUGIN_NAME", "\"$pluginName\"")
        setProperty("archivesBaseName", pluginName)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

dependencies {
    implementation("org.godotengine:godot:4.7.0.stable")

    implementation(platform("com.com2us.android.hive:hive-sdk-bom:26.4.0"))
    implementation("com.com2us.android.hive:hive-sdk")
    implementation("com.com2us.android.hive:hive-authv4-provider-google-credential-signin")
    implementation("com.com2us.android.hive:hive-authv4-provider-google-playgames")
    implementation("com.android.installreferrer:installreferrer")

    implementation("com.com2us.android.adiz:hive-adiz:3.0.0")
}

val addonsDir = rootProject.projectDir.resolve("../../addons/$pluginName")

tasks.register<Copy>("copyDebugAar") {
    dependsOn("assembleDebug")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("$pluginName-debug.aar")
    into(addonsDir.resolve("bin/debug"))
}

tasks.register<Copy>("copyReleaseAar") {
    dependsOn("assembleRelease")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("$pluginName-release.aar")
    into(addonsDir.resolve("bin/release"))
}
