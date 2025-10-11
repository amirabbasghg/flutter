pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    val properties = java.util.Properties()
    file("local.properties").inputStream().use { properties.load(it) }
    val flutterSdkPath = properties.getProperty("flutter.sdk")
        ?: throw GradleException("flutter.sdk not set in local.properties")
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
}

include(":app")