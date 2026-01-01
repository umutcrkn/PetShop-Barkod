# Evcil Hayvan Dükkanı iOS Uygulaması

Bu iOS uygulaması, evcil hayvan malzemesi satan dükkanlar için tasarlanmış basit ve kullanışlı bir yönetim sistemidir.

## Özellikler

### 1. Kullanıcı Girişi
- Kullanıcı adı: `admin`
- Varsayılan parola: `admin`
- Şifre değiştirme özelliği

### 2. Ana Menü
- Ürün Ekleme butonu
- Satış butonu
- Çıkış yapma özelliği

### 3. Ürün Ekleme
- Ürün adı
- Ürün açıklaması
- Fiyat
- Barkod numarası (kamera ile okutma veya manuel giriş)
- Stok miktarı

### 4. Satış
- Barkod okutma (kamera ile) veya manuel giriş
- Ürün bilgilerini görüntüleme
- Adet seçimi
- Sepete ekleme
- Toplam tutar hesaplama
- Satış tamamlama
- Otomatik stok güncelleme

## Kurulum

1. Xcode'da yeni bir iOS projesi oluşturun (SwiftUI App)
2. Bu dosyaları projenize ekleyin
3. `Info.plist` dosyasındaki kamera izni ayarlarını kontrol edin
4. Projeyi derleyin ve çalıştırın

## Gereksinimler

- iOS 14.0 veya üzeri
- Xcode 12.0 veya üzeri
- Swift 5.0 veya üzeri
- Kamera erişimi (barkod okuma için)

## Kullanım

1. Uygulamayı açın ve `admin` / `admin` ile giriş yapın
2. Ana menüden "Ürün Ekleme" veya "Satış" seçeneğini seçin
3. Barkod okutmak için kamera simgesine tıklayın
4. Ürünleri ekleyin ve satışları tamamlayın

## GitHub Entegrasyonu

Bu uygulama verilerini GitHub repository'sinde saklar. Tüm ürün ve satış verileri GitHub'da `data/products.json` ve `data/sales.json` dosyalarında tutulur.

### GitHub Token Kurulumu

1. GitHub.com'a giriş yapın
2. Sağ üst köşedeki profil resminize tıklayın > **Settings**
3. Sol menüden **Developer settings** > **Personal access tokens** > **Tokens (classic)**
4. **Generate new token (classic)** butonuna tıklayın
5. Token'a bir isim verin (örn: "PetShop App")
6. **repo** yetkisini seçin (tüm repo yetkileri)
7. **Generate token** butonuna tıklayın
8. Oluşturulan token'ı kopyalayın (bir daha gösterilmeyecek!)
9. Uygulamada **Ayarlar** > **GitHub Ayarları** bölümüne gidin
10. Token'ı yapıştırın ve **Token Kaydet** butonuna tıklayın

### Veri Senkronizasyonu

- Uygulama açıldığında otomatik olarak GitHub'dan veriler yüklenir
- Ürün ekleme, güncelleme veya satış yapıldığında veriler otomatik olarak GitHub'a gönderilir
- **Ayarlar** ekranından manuel olarak veri çekme veya gönderme işlemi yapabilirsiniz

### Çoklu Cihaz Desteği

GitHub entegrasyonu sayesinde:
- iOS ve Android cihazlardan aynı verilere erişebilirsiniz
- Tüm cihazlar aynı veri kaynağını kullanır
- Veriler GitHub'da merkezi olarak saklanır

## Notlar

- Veriler GitHub'da saklanır (local cache olarak UserDefaults da kullanılır)
- Tüm ürün bilgileri GitHub repository'sinde tutulur
- Stok miktarları otomatik olarak güncellenir
- İnternet bağlantısı gereklidir (offline durumda local cache kullanılır)

