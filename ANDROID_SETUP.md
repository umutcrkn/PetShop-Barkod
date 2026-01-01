# Android Studio Koala 2024.1.1 - Kurulum Rehberi

## Adım 1: Yeni Android Projesi Oluşturma

1. Android Studio'yu açın
2. **File** > **New** > **New Project**
3. **Empty Activity** seçin
4. Proje ayarları:
   - **Name**: PetShop
   - **Package name**: com.petshop
   - **Save location**: İstediğiniz konum
   - **Language**: Kotlin
   - **Minimum SDK**: API 24 (Android 7.0)
   - **Build configuration language**: Kotlin DSL (build.gradle.kts)
5. **Finish** butonuna tıklayın

## Adım 2: Gradle Bağımlılıklarını Ekleme

`app/build.gradle.kts` dosyasını açın ve aşağıdaki bağımlılıkları ekleyin:

```kotlin
dependencies {
    // Jetpack Compose
    implementation(platform("androidx.compose:compose-bom:2023.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.8.2")
    
    // ViewModel & LiveData
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.7.0")
    
    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    
    // Retrofit (GitHub API için)
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    
    // Encryption (AES-GCM)
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    
    // Barcode Scanner
    implementation("com.google.mlkit:barcode-scanning:17.2.0")
    implementation("androidx.camera:camera-camera2:1.3.1")
    implementation("androidx.camera:camera-lifecycle:1.3.1")
    implementation("androidx.camera:camera-view:1.3.1")
    
    // JSON
    implementation("com.google.code.gson:gson:2.10.1")
    
    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.6")
}
```

## Adım 3: Proje Yapısını Oluşturma

Aşağıdaki klasör yapısını oluşturun:

```
app/src/main/java/com/petshop/
├── models/
│   ├── Product.kt
│   ├── Sale.kt
│   ├── Company.kt
│   └── CompanyError.kt
├── services/
│   ├── GitHubService.kt
│   ├── EncryptionService.kt
│   ├── DataManager.kt
│   └── CompanyManager.kt
├── ui/
│   ├── login/
│   │   ├── LoginScreen.kt
│   │   └── LoginViewModel.kt
│   ├── mainmenu/
│   │   ├── MainMenuScreen.kt
│   │   └── MainMenuViewModel.kt
│   ├── products/
│   │   ├── AddProductScreen.kt
│   │   ├── ProductListScreen.kt
│   │   └── ProductViewModel.kt
│   └── sales/
│       ├── SalesScreen.kt
│       └── SalesViewModel.kt
└── MainActivity.kt
```

## Adım 4: AndroidManifest.xml Ayarları

`app/src/main/AndroidManifest.xml` dosyasına izinleri ekleyin:

```xml
<manifest ...>
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    
    <application ...>
        ...
    </application>
</manifest>
```

## Adım 5: build.gradle.kts Ayarları

`app/build.gradle.kts` dosyasında Compose'u etkinleştirin:

```kotlin
android {
    ...
    buildFeatures {
        compose = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
    }
}
```

## Sonraki Adımlar

1. Model dosyalarını oluşturun (Product.kt, Company.kt, vb.)
2. GitHubService'i Retrofit ile implement edin
3. EncryptionService'i Android Security Crypto ile implement edin
4. UI'ı Jetpack Compose ile oluşturun

Detaylı kod örnekleri için `ANDROID_CODE_EXAMPLES.md` dosyasına bakın.

