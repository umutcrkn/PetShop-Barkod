//
//  BackupExportView.swift
//  PetShop
//
//  Backup and email export view
//

import SwiftUI
import MessageUI

struct BackupExportView: View {
    @StateObject private var dataManager = DataManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var emailAddress: String = ""
    @State private var showMailComposer = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("E-posta Adresi")) {
                    TextField("ornek@email.com", text: $emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Section(header: Text("Yedekleme Bilgileri")) {
                    HStack {
                        Text("Toplam Ürün")
                        Spacer()
                        Text("\(dataManager.products.count)")
                            .foregroundColor(.blue)
                    }
                    
                    Text("Yedekleme CSV formatında oluşturulacak ve belirttiğiniz e-posta adresine gönderilecektir.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: exportAndSend) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Yedekle ve Gönder")
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(emailAddress.isEmpty || !isValidEmail(emailAddress))
                }
            }
            .navigationTitle("Yedekleme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposeView(
                    email: emailAddress,
                    csvContent: generateCSV(),
                    onDismiss: {
                        dismiss()
                    }
                )
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func generateCSV() -> String {
        var csv = "Ürün Adı,Açıklama,Fiyat,Barkod,Stok\n"
        
        for product in dataManager.products.sorted(by: { $0.name < $1.name }) {
            let name = escapeCSVField(product.name)
            let description = escapeCSVField(product.description)
            let price = String(format: "%.2f", product.price)
            let barcode = product.barcode
            let stock = String(product.stock)
            
            csv += "\(name),\(description),\(price),\(barcode),\(stock)\n"
        }
        
        return csv
    }
    
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
    
    private func exportAndSend() {
        guard !emailAddress.isEmpty else {
            errorMessage = "Lütfen e-posta adresi giriniz!"
            showError = true
            return
        }
        
        guard isValidEmail(emailAddress) else {
            errorMessage = "Geçerli bir e-posta adresi giriniz!"
            showError = true
            return
        }
        
        guard !dataManager.products.isEmpty else {
            errorMessage = "Yedeklenecek ürün bulunamadı!"
            showError = true
            return
        }
        
        guard MFMailComposeViewController.canSendMail() else {
            errorMessage = "Mail göndermek için cihazınızda bir mail hesabı yapılandırmanız gerekiyor. Ayarlar > Mail > Hesaplar bölümünden mail hesabı ekleyebilirsiniz."
            showError = true
            return
        }
        
        showMailComposer = true
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let email: String
    let csvContent: String
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        
        // Set email properties
        composer.setToRecipients([email])
        composer.setSubject("Pi Code - Ürün Yedeği")
        composer.setMessageBody("Merhaba,\n\nÜrün yedeği ekte gönderilmiştir.\n\nİyi çalışmalar.", isHTML: false)
        
        // Attach CSV file
        if let csvData = csvContent.data(using: .utf8) {
            composer.addAttachmentData(csvData, mimeType: "text/csv", fileName: "urun_yedegi_\(formatDate()).csv")
        }
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                self.onDismiss()
            }
        }
    }
    
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

