# Android Kod Örnekleri

Bu dosya iOS uygulamasından Android'e port edilmiş kod örneklerini içerir.

## 1. Product.kt

```kotlin
package com.petshop.models

import com.google.gson.annotations.SerializedName
import java.util.UUID

data class Product(
    @SerializedName("id")
    val id: String = UUID.randomUUID().toString(),
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("description")
    val description: String,
    
    @SerializedName("price")
    val price: Double,
    
    @SerializedName("barcode")
    val barcode: String,
    
    @SerializedName("stock")
    val stock: Int
)
```

## 2. Company.kt

```kotlin
package com.petshop.models

import com.google.gson.annotations.SerializedName
import java.util.Date
import java.util.UUID

data class Company(
    @SerializedName("id")
    val id: String = UUID.randomUUID().toString(),
    
    @SerializedName("name")
    val name: String,
    
    @SerializedName("username")
    val username: String,
    
    @SerializedName("encryptedPassword")
    val encryptedPassword: String,
    
    @SerializedName("createdAt")
    val createdAt: Date,
    
    @SerializedName("trialExpiresAt")
    val trialExpiresAt: Date
) {
    fun isTrialExpired(): Boolean {
        return Date() > trialExpiresAt
    }
    
    fun remainingTrialDays(): Int {
        val diff = trialExpiresAt.time - Date().time
        return maxOf(0, (diff / (1000 * 60 * 60 * 24)).toInt())
    }
}
```

## 3. GitHubService.kt (Retrofit ile)

```kotlin
package com.petshop.services

import com.petshop.models.Product
import com.petshop.models.Sale
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import java.util.Base64

interface GitHubApi {
    @GET("/repos/{owner}/{repo}/contents/{path}")
    suspend fun getFile(
        @Path("owner") owner: String,
        @Path("repo") repo: String,
        @Path("path") path: String,
        @Header("Authorization") auth: String,
        @Header("Accept") accept: String = "application/vnd.github.v3+json"
    ): GitHubFileResponse
    
    @PUT("/repos/{owner}/{repo}/contents/{path}")
    suspend fun putFile(
        @Path("owner") owner: String,
        @Path("repo") repo: String,
        @Path("path") path: String,
        @Header("Authorization") auth: String,
        @Header("Accept") accept: String = "application/vnd.github.v3+json",
        @Body body: GitHubFileRequest
    ): GitHubFileResponse
}

data class GitHubFileResponse(
    val sha: String,
    val content: String
)

data class GitHubFileRequest(
    val message: String,
    val content: String,
    val sha: String? = null
)

class GitHubService private constructor() {
    companion object {
        @Volatile
        private var INSTANCE: GitHubService? = null
        
        fun getInstance(): GitHubService {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: GitHubService().also { INSTANCE = it }
            }
        }
    }
    
    private val owner = "umutcrkn"
    private val repo = "PetShop-Barkod"
    private val baseURL = "https://api.github.com"
    
    private var token: String? = null
    private var apiBaseURL: String? = null
    
    private val retrofit: Retrofit by lazy {
        val logging = HttpLoggingInterceptor()
        logging.level = HttpLoggingInterceptor.Level.BODY
        
        val client = OkHttpClient.Builder()
            .addInterceptor(logging)
            .build()
        
        Retrofit.Builder()
            .baseUrl(baseURL)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
    }
    
    private val api: GitHubApi by lazy {
        retrofit.create(GitHubApi::class.java)
    }
    
    fun setToken(token: String) {
        this.token = token
    }
    
    fun setAPIURL(url: String) {
        this.apiBaseURL = url
    }
    
    suspend fun getFileContent(path: String): ByteArray {
        val auth = "token $token"
        val response = api.getFile(owner, repo, path, auth)
        return Base64.getDecoder().decode(response.content.replace("\n", ""))
    }
    
    suspend fun putFileContent(path: String, content: ByteArray, message: String, sha: String? = null) {
        val auth = "token $token"
        val base64Content = Base64.getEncoder().encodeToString(content)
        val request = GitHubFileRequest(message, base64Content, sha)
        api.putFile(owner, repo, path, auth, body = request)
    }
    
    suspend fun getProducts(path: String): List<Product> {
        val data = getFileContent(path)
        val json = String(data)
        // Gson ile parse et
        // return gson.fromJson(json, Array<Product>::class.java).toList()
    }
    
    suspend fun saveProducts(products: List<Product>, path: String) {
        // Gson ile serialize et
        // val json = gson.toJson(products)
        // putFileContent(path, json.toByteArray(), "Update products")
    }
}
```

## 4. EncryptionService.kt (Android Security Crypto)

```kotlin
package com.petshop.services

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import java.util.Base64

class EncryptionService private constructor(private val context: Context) {
    companion object {
        @Volatile
        private var INSTANCE: EncryptionService? = null
        
        fun getInstance(context: Context): EncryptionService {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: EncryptionService(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    private val masterKey: MasterKey by lazy {
        MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
    }
    
    private val sharedPreferences: SharedPreferences by lazy {
        EncryptedSharedPreferences.create(
            context,
            "encryption_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }
    
    private var encryptionKey: SecretKey? = null
    
    suspend fun loadEncryptionKey(forceReload: Boolean = false) = withContext(Dispatchers.IO) {
        // GitHub'dan encryption key'i yükle
        // iOS ile aynı mantık
    }
    
    fun encrypt(text: String): String {
        val key = getOrCreateKey()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        
        val encrypted = cipher.doFinal(text.toByteArray())
        val iv = cipher.iv
        
        val combined = ByteArray(iv.size + encrypted.size)
        System.arraycopy(iv, 0, combined, 0, iv.size)
        System.arraycopy(encrypted, 0, combined, iv.size, encrypted.size)
        
        return Base64.getEncoder().encodeToString(combined)
    }
    
    suspend fun decryptAsync(encryptedText: String): String = withContext(Dispatchers.IO) {
        try {
            val combined = Base64.getDecoder().decode(encryptedText)
            val iv = ByteArray(12) // GCM IV size
            val encrypted = ByteArray(combined.size - 12)
            
            System.arraycopy(combined, 0, iv, 0, 12)
            System.arraycopy(combined, 12, encrypted, 0, encrypted.size)
            
            val key = getOrCreateKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val spec = GCMParameterSpec(128, iv)
            cipher.init(Cipher.DECRYPT_MODE, key, spec)
            
            val decrypted = cipher.doFinal(encrypted)
            String(decrypted)
        } catch (e: Exception) {
            ""
        }
    }
    
    private fun getOrCreateKey(): SecretKey {
        if (encryptionKey == null) {
            // GitHub'dan yükle veya yeni oluştur
            val keyBytes = ByteArray(32)
            SecureRandom().nextBytes(keyBytes)
            encryptionKey = SecretKeySpec(keyBytes, "AES")
        }
        return encryptionKey!!
    }
}
```

## 5. LoginScreen.kt (Jetpack Compose)

```kotlin
package com.petshop.ui.login

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun LoginScreen(
    onLoginSuccess: () -> Unit,
    viewModel: LoginViewModel = viewModel()
) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var isLoading by remember { mutableStateOf(false) }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Pet Malzeme Satış",
            style = MaterialTheme.typography.headlineLarge
        )
        
        Spacer(modifier = Modifier.height(32.dp))
        
        OutlinedTextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("Kullanıcı Adı") },
            modifier = Modifier.fillMaxWidth()
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Parola") },
            modifier = Modifier.fillMaxWidth(),
            visualTransformation = PasswordVisualTransformation()
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Button(
            onClick = {
                isLoading = true
                viewModel.login(username, password) { success, error ->
                    isLoading = false
                    if (success) {
                        onLoginSuccess()
                    } else {
                        errorMessage = error
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isLoading && username.isNotEmpty() && password.isNotEmpty()
        ) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp))
            } else {
                Text("Giriş Yap")
            }
        }
        
        errorMessage?.let {
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = it,
                color = MaterialTheme.colorScheme.error
            )
        }
    }
}
```

## 6. MainActivity.kt

```kotlin
package com.petshop

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.petshop.ui.login.LoginScreen
import com.petshop.ui.mainmenu.MainMenuScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    var isLoggedIn by remember { mutableStateOf(false) }
                    
                    if (isLoggedIn) {
                        MainMenuScreen(
                            onLogout = { isLoggedIn = false }
                        )
                    } else {
                        LoginScreen(
                            onLoginSuccess = { isLoggedIn = true }
                        )
                    }
                }
            }
        }
    }
}
```

## Önemli Notlar

1. **Gson Date Format**: iOS ile uyumlu olması için Date formatını ISO8601 olarak ayarlayın
2. **Encryption Key**: GitHub'dan aynı encryption key'i kullanın (iOS ile paylaşılan)
3. **API Endpoints**: Aynı GitHub API endpoint'lerini kullanın
4. **Error Handling**: 409 hataları için retry mekanizması ekleyin
5. **Coroutines**: Tüm async işlemler için Coroutines kullanın

## Sonraki Adımlar

1. Tüm model dosyalarını oluşturun
2. Servisleri implement edin
3. ViewModel'leri oluşturun
4. UI ekranlarını Compose ile oluşturun
5. Navigation'ı ayarlayın

