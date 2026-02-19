pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 国内镜像（可选）
        maven { url = uri("https://mirrors.cloud.tencent.com/android/repository/") }
        maven { url = uri("https://mirrors.cloud.tencent.com/repository/maven-public/") }

        // ⭐ Flutter 官方 Maven 仓库（必须加）
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }

        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")


dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)

    repositories {
        // 国内镜像
        maven { url = uri("https://mirrors.cloud.tencent.com/android/repository/") }
        maven { url = uri("https://mirrors.cloud.tencent.com/repository/maven-public/") }

        // ⭐ Flutter 官方 Maven 仓库（必须加）
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }

        google()
        mavenCentral()
    }
}
