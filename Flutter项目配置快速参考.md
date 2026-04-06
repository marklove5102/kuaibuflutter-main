# Flutter项目配置快速参考

## 📋 当前系统环境

- **操作系统**: Windows 11 (24H2, 2009) x64
- **Flutter版本**: 3.41.6 Stable
- **Java版本**: 17.0.5
- **配置日期**: 2026-03-27

## 🔧 环境变量配置

### Flutter镜像源
```powershell
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### Java环境
```powershell
JAVA_HOME=C:\Program Files\Java\jdk-17.0.5
STUDIO_JDK=C:\Program Files\Java\jdk-17.0.5
SKIP_JDK_VERSION_CHECK=1
```

### 浏览器配置
```powershell
CHROME_EXECUTABLE=D:\Chrome-87.0.4280.141\App\chrome.exe
```

### Android环境
```powershell
ANDROID_HOME=C:\Users\Administrator\AppData\Local\Android\Sdk
```

### Android SDK版本
```powershell
# Build-Tools
33.0.1, 34.0.0, 35.0.0, 36.0.0

# NDK
25.1.8937393, 25.2.9519653, 27.3.13750724, 28.2.13676358

# CMake
3.22.1

# Platform
android-34 (API 34)
```

## 📱 新项目必改配置

### 1. android/build.gradle.kts
```kotlin
allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
    }
}
```

### 2. android/settings.gradle.kts
```kotlin
repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        google()
        mavenCentral()
        gradlePluginPortal()
}
```

### 3. android/gradle/wrapper/gradle-wrapper.properties
```properties
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.14-all.zip
```

### 4. android/gradle.properties
```properties
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
org.gradle.java.home=C:\\Program Files\\Java\\jdk-17.0.5
```

## 🚀 快速命令

### 创建项目
```powershell
flutter create project_name
cd project_name
```

### 运行项目
```powershell
# Windows
flutter run -d windows

# Web (Chrome)
flutter run -d chrome

# Android
flutter run -d android
```

### 查看设备
```powershell
flutter devices
```

## ✅ 支持的平台

| 平台 | 命令 | 状态 |
|------|------|------|
| Windows | `flutter run -d windows` | ✅ |
| Web | `flutter run -d chrome` | ✅ |
| Android | `flutter run -d android` | ✅ |

## 📝 配置文件位置

### Android SDK
```
C:\Users\Administrator\AppData\Local\Android\Sdk
```

### Flutter SDK
```
C:\Users\Administrator\Desktop\flutter
```

### Java
```
C:\Program Files\Java\jdk-17.0.5
```

## 🎯 新项目检查清单

创建新项目后，检查以下文件是否需要修改：

- [ ] `android/build.gradle.kts` - 添加阿里云Maven仓库
- [ ] `android/settings.gradle.kts` - 添加阿里云Gradle仓库
- [ ] `android/gradle/wrapper/gradle-wrapper.properties` - 修改Gradle下载源
- [ ] `android/gradle.properties` - 添加Java 17配置

## 🔍 常见问题

### Gradle SSL错误
检查是否已配置阿里云和腾讯云镜像源。

### Java版本错误
检查 `gradle.properties` 中是否已设置 `org.gradle.java.home`。

### 浏览器不支持
使用Chrome而不是Edge，或升级Flutter版本。

## 📞 联系方式

- **Flutter文档**: https://docs.flutter.dev
- **Flutter中文**: https://flutter.cn

---

**文档版本**: 1.0  
**最后更新**: 2026-03-27