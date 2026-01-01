# Android Uygulaması Geliştirme Rehberi

Bu iOS uygulamasını Android'de çalıştırmak için aşağıdaki adımları izleyin.

## Seçenek 1: Kotlin/Android Studio ile Native Android Uygulaması (Önerilen)

### Gereksinimler
- Android Studio (Arctic Fox veya üzeri)
- Kotlin 1.5.0 veya üzeri
- Android SDK 24 (Android 7.0) veya üzeri
- Gradle 7.0 veya üzeri

### Yapılacaklar

#### 1. Proje Yapısı
```
PetShop-Android/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/petshop/
│   │   │   │   ├── models/
│   │   │   │   │   ├── Product.kt
│   │   │   │   │   ├── Sale.kt
│   │   │   │   │   ├── Company.kt
│   │   │   │   │   ├── DataManager.kt
│   │   │   │   │   ├── CompanyManager.kt
│   │   │   │   │   ├── GitHubService.kt
│   │   │   │   │   └── EncryptionService.kt
│   │   │   │   ├── ui/
│   │   │   │   │   ├── LoginActivity.kt
│   │   │   │   │   ├── MainMenuActivity.kt
│   │   │   │   │   ├── AddProductActivity.kt
│   │   │   │   │   ├── ProductListActivity.kt
│   │   │   │   │   ├── SalesActivity.kt
│   │   │   │   │   └── ...
│   │   │   │   └── MainActivity.kt
│   │   │   └── res/
│   │   └── test/
│   └── build.gradle
└── build.gradle
```

#### 2. Bağımlılıklar (build.gradle)
```kotlin
dependencies {
    // Jetpack Compose
    implementation "androidx.compose.ui:ui:$compose_version"
    implementation "androidx.compose.material:material:$compose_version"
    implementation "androidx.compose.ui:ui-tooling-preview:$compose_version"
    implementation "androidx.activity:activity-compose:1.4.0"
    
    // ViewModel & LiveData
    implementation "androidx.lifecycle:lifecycle-viewmodel-compose:2.4.0"
    implementation "androidx.lifecycle:lifecycle-runtime-ktx:2.4.0"
    
    // Coroutines
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.5.2"
    
    // Retrofit (GitHub API için)
    implementation "com.squareup.retrofit2:retrofit:2.9.0"
    implementation "com.squareup.retrofit2:converter-gson:2.9.0"
    
    // Encryption (AES-GCM)
    implementation "androidx.security:security-crypto:1.1.0-alpha03"
    
    // Barcode Scanner
    implementation "com.google.mlkit:barcode-scanning:17.0.0"
    implementation "androidx.camera:camera-camera2:1.1.0"
    implementation "androidx.camera:camera-lifecycle:1.1.0"
    implementation "androidx.camera:camera-view:1.1.0"
}
```

#### 3. Model Dönüşümleri

**Product.kt** (iOS Product.swift'ten)
```kotlin
data class Product(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val description: String,
    val price: Double,
    val barcode: String,
    val stock: Int
)
```

**Company.kt** (iOS Company.swift'ten)
```kotlin
data class Company(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val username: String,
    val encryptedPassword: String,
    val createdAt: Date,
    val trialExpiresAt: Date
) {
    fun isTrialExpired(): Boolean = Date() > trialExpiresAt
    fun remainingTrialDays(): Int {
        val diff = trialExpiresAt.time - Date().time
        return max(0, (diff / (1000 * 60 * 60 * 24)).toInt())
    }
}
```

#### 4. GitHubService.kt (iOS GitHubService.swift'ten)
- Retrofit kullanarak GitHub API'ye bağlanın
- Aynı endpoint'leri kullanın: `/repos/{owner}/{repo}/contents/{path}`
- PUT ve GET istekleri için Retrofit interface oluşturun

#### 5. EncryptionService.kt (iOS EncryptionService.swift'ten)
- Android Security Crypto kütüphanesini kullanın
- AES-GCM şifreleme için `AndroidKeystore` kullanın
- GitHub'dan encryption key'i yükleyin (iOS ile aynı mantık)

#### 6. UI Dönüşümleri

**SwiftUI → Jetpack Compose**

iOS:
```swift
struct LoginView: View {
    @State private var username: String = ""
    var body: some View {
        TextField("Kullanıcı Adı", text: $username)
    }
}
```

Android (Compose):
```kotlin
@Composable
fun LoginScreen(
    viewModel: LoginViewModel = viewModel()
) {
    var username by remember { mutableStateOf("") }
    TextField(
        value = username,
        onValueChange = { username = it },
        label = { Text("Kullanıcı Adı") }
    )
}
```

### Önemli Notlar

1. **GitHub API**: Aynı endpoint'leri kullanın, kod mantığı aynı kalacak
2. **Encryption**: iOS ve Android aynı encryption key'i kullanmalı (GitHub'dan)
3. **Data Models**: JSON encoding/decoding aynı olmalı (iOS ile uyumlu)
4. **Barcode Scanner**: ML Kit Barcode Scanning kullanın
5. **UserDefaults → SharedPreferences**: Android'de SharedPreferences kullanın

## Seçenek 2: Flutter ile Cross-Platform

Flutter kullanarak hem iOS hem Android için tek kod tabanı oluşturabilirsiniz.

### Avantajlar
- Tek kod tabanı
- Aynı UI/UX
- Daha hızlı geliştirme

### Dezavantajlar
- Mevcut Swift kodunu Dart'a çevirmek gerekir
- Native özellikler için platform channel'lar gerekebilir

## Seçenek 3: React Native

JavaScript/TypeScript ile cross-platform uygulama.

### Avantajlar
- Web teknolojileri bilgisi yeterli
- Büyük topluluk

### Dezavantajlar
- Performans native'den düşük olabilir
- Tüm kodun JavaScript'e çevrilmesi gerekir

## Önerilen Yaklaşım

**Kotlin/Android Studio ile Native Android Uygulaması** geliştirmek en iyi seçenektir çünkü:
- Mevcut GitHub API entegrasyonu aynı kalır
- Native performans
- Android özelliklerine tam erişim
- iOS ile aynı backend kullanılır

## Hızlı Başlangıç

1. Android Studio'da yeni bir "Empty Activity" projesi oluşturun
2. Jetpack Compose'u etkinleştirin
3. Models klasörünü oluşturun ve iOS modellerini Kotlin'e çevirin
4. GitHubService'i Retrofit ile implement edin
5. UI'ı Compose ile oluşturun

## Yardım

Android uygulamasını geliştirmek için adım adım rehber ister misiniz?

