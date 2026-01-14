//
//  FileUploadCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct FileUploadCard: View {
    @Binding var pdfPassword: String
    @Binding var isUploading: Bool
    @Binding var uploadProgress: Double
    @Binding var uploadError: String?
    @Binding var isPresented: Bool
    
    let onFileSelected: (URL) -> Void
    let onUploadComplete: (() -> Void)?
    
    @State private var isDragging = false
    @State private var showFilePicker = false
    @State private var showSuccess = false
    @State private var selectedFileName: String?
    @State private var isPasswordProtected: Bool = false
    @State private var selectedFileURL: URL?
    @State private var showPasswordAlert: Bool = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    init(
        pdfPassword: Binding<String>,
        isUploading: Binding<Bool>,
        uploadProgress: Binding<Double>,
        uploadError: Binding<String?>,
        isPresented: Binding<Bool>,
        onFileSelected: @escaping (URL) -> Void,
        onUploadComplete: (() -> Void)? = nil
    ) {
        self._pdfPassword = pdfPassword
        self._isUploading = isUploading
        self._uploadProgress = uploadProgress
        self._uploadError = uploadError
        self._isPresented = isPresented
        self.onFileSelected = onFileSelected
        self.onUploadComplete = onUploadComplete
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Drag and Drop Area
                    dragDropArea
                    
                    // PDF Password field
                    passwordSection
                    
                    // Selected file info
                    if let fileName = selectedFileName {
                        selectedFileInfo(fileName)
                    }
                    
                    // Upload button
                    uploadButton
                    
                    // Progress bar
                    if isUploading && uploadProgress > 0 {
                        progressSection
                    }
                    
                    // Success state
                    if showSuccess {
                        successState
                    }
                    
                    // Error message
                    if let error = uploadError {
                        errorMessage(error)
                    }
                }
                .padding(24)
            }
            .background(Color(red: 0.18, green: 0.18, blue: 0.18))
            .navigationTitle("Upload Statement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(goldColor)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                .pdf,
                .commaSeparatedText,
                .spreadsheet
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFileName = url.lastPathComponent
                    selectedFileURL = url
                    
                    // Check if PDF is password protected
                    if url.pathExtension.lowercased() == "pdf" {
                        checkPDFPasswordProtection(url: url)
                    } else {
                        isPasswordProtected = false
                        pdfPassword = ""
                    }
                    
                    onFileSelected(url)
                }
            case .failure(let error):
                uploadError = "Failed to select file: \(error.localizedDescription)"
            }
        }
        .alert("Password Required", isPresented: $showPasswordAlert) {
            Button("Cancel") {
                selectedFileName = nil
                selectedFileURL = nil
                isPasswordProtected = false
                pdfPassword = ""
            }
            Button("OK") {
                // Password will be used when uploading
            }
        } message: {
            Text("This PDF file is password protected. Please enter the password in the field below to continue.")
        }
        .onChange(of: isUploading) { oldValue, newValue in
            if !newValue && oldValue && uploadError == nil {
                // Upload completed successfully
                showSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSuccess = false
                    isPresented = false
                    onUploadComplete?()
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var dragDropArea: some View {
        Button(action: {
            showFilePicker = true
        }) {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isDragging ? goldColor.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isDragging ? goldColor : Color.gray.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                                )
                        )
                    
                    VStack(spacing: 16) {
                        Image(systemName: isDragging ? "arrow.down.doc.fill" : "doc.badge.plus")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(isDragging ? goldColor : .gray.opacity(0.6))
                        
                        VStack(spacing: 4) {
                            Text(isDragging ? "Drop file here" : "Tap to select file")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("PDF, CSV, or Excel files")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isUploading)
    }
    
    @ViewBuilder
    private var passwordSection: some View {
        // Only show password section if PDF is selected
        if selectedFileName != nil && selectedFileName?.lowercased().hasSuffix(".pdf") == true {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: isPasswordProtected ? "lock.fill" : "lock.open.fill")
                        .foregroundColor(isPasswordProtected ? .orange : goldColor)
                        .font(.system(size: 16))
                    
                    Text(isPasswordProtected ? "PDF Password (required)" : "PDF Password (optional)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                SecureField(
                    isPasswordProtected ? "Enter password to unlock PDF" : "Enter password if PDF is encrypted",
                    text: $pdfPassword
                )
                .textFieldStyle(PasswordTextFieldStyle())
                .disabled(isUploading)
                
                if isPasswordProtected && pdfPassword.isEmpty {
                    Text("This PDF requires a password to open.")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private func selectedFileInfo(_ fileName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .foregroundColor(goldColor)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Selected File")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.7))
                
                Text(fileName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                selectedFileName = nil
                selectedFileURL = nil
                isPasswordProtected = false
                pdfPassword = ""
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray.opacity(0.6))
                    .font(.system(size: 20))
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var uploadButton: some View {
        Button(action: {
            if selectedFileName != nil {
                // Check if password is required but not provided
                if isPasswordProtected && pdfPassword.isEmpty {
                    showPasswordAlert = true
                    return
                }
                // Trigger upload via onFileSelected callback
                if let url = selectedFileURL {
                    onFileSelected(url)
                }
            } else {
                showFilePicker = true
            }
        }) {
            HStack {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: selectedFileName != nil ? "arrow.up.circle.fill" : "doc.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                Text(isUploading
                     ? "Uploading..."
                     : (selectedFileName != nil ? "Upload File" : "Select File"))
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                (isUploading || (isPasswordProtected && pdfPassword.isEmpty && selectedFileName != nil))
                    ? goldColor.opacity(0.5)
                    : goldColor
            )
            .cornerRadius(16)
        }
        .disabled(isUploading || (isPasswordProtected && pdfPassword.isEmpty && selectedFileName != nil))
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upload Progress")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(uploadProgress))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(goldColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [goldColor, goldColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (uploadProgress / 100), height: 12)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: uploadProgress)
                }
            }
            .frame(height: 12)
        }
        .padding(20)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var successState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text("Upload Successful!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("Your transactions are being processed")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1))
        .cornerRadius(20)
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Helper Functions
    
    private func checkPDFPasswordProtection(url: URL) {
        // Access security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            isPasswordProtected = false
            return
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Try to read PDF data
        guard let pdfData = try? Data(contentsOf: url) else {
            isPasswordProtected = false
            return
        }
        
        // Try to create PDFDocument
        if let pdfDocument = PDFDocument(data: pdfData) {
            // Check if document is encrypted
            if pdfDocument.isEncrypted {
                // Try to unlock with empty password
                if pdfDocument.unlock(withPassword: "") {
                    // Unlocked with empty password - not really protected
                    isPasswordProtected = false
                    pdfPassword = ""
                } else {
                    // Requires password
                    isPasswordProtected = true
                    // Show alert to prompt for password
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPasswordAlert = true
                    }
                }
            } else {
                // Not encrypted
                isPasswordProtected = false
                pdfPassword = ""
            }
        } else {
            // Could not create document - likely password protected
            isPasswordProtected = true
            // Show alert to prompt for password
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showPasswordAlert = true
            }
        }
    }
    
    private func errorMessage(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 20))
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.red)
                .lineLimit(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// Custom TextField Style for password field
struct PasswordTextFieldStyle: TextFieldStyle {
    private let darkCharcoalColor = Color(red: 0.15, green: 0.15, blue: 0.15)
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white)
            .padding(12)
            .background(darkCharcoalColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    FileUploadCard(
        pdfPassword: .constant(""),
        isUploading: .constant(false),
        uploadProgress: .constant(0),
        uploadError: .constant(nil),
        isPresented: .constant(true),
        onFileSelected: { _ in }
    )
}

