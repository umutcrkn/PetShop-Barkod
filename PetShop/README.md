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

## Notlar

- Veriler UserDefaults ile yerel olarak saklanır
- Tüm ürün bilgileri cihazda kalır
- Stok miktarları otomatik olarak güncellenir

