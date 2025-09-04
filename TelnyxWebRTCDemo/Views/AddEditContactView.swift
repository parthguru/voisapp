//
//  AddEditContactView.swift
//  TelnyxWebRTCDemo
//
//  Created by AI SWE Agent on 02/09/2025.
//  Copyright © 2025 Telnyx LLC. All rights reserved.
//

import SwiftUI
import PhotosUI

struct AddEditContactView: View {
    let contact: Contact? // nil for add, existing contact for edit
    let onSave: (String, String, UIImage?) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var phoneNumber: String = ""
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingActionSheet = false
    
    private let contactsManager = ContactsManager.shared
    
    var isEditing: Bool {
        contact != nil
    }
    
    var navigationTitle: String {
        isEditing ? "Edit Contact" : "New Contact"
    }
    
    var saveButtonDisabled: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty ||
        phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Profile Image Section
                    ProfileImageSection(
                        image: profileImage,
                        contact: contact,
                        onImageTapped: {
                            showingActionSheet = true
                        }
                    )
                    
                    // Form Fields
                    VStack(spacing: 24) {
                        // Name Field
                        FormField(
                            title: "Name",
                            text: $name,
                            placeholder: "Enter full name",
                            keyboardType: .default
                        )
                        
                        // Phone Number Field
                        FormField(
                            title: "Phone",
                            text: $phoneNumber,
                            placeholder: "Enter phone number",
                            keyboardType: .phonePad
                        )
                    }
                    
                    Spacer()
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
            }
            .background(ProfessionalColors.professionalBackground.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ProfessionalColors.professionalPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(name, phoneNumber, profileImage)
                        dismiss()
                    }
                    .foregroundColor(saveButtonDisabled ? ProfessionalColors.textSecondary : ProfessionalColors.professionalPrimary)
                    .disabled(saveButtonDisabled)
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showingActionSheet) {
            Button("Camera") {
                showingCamera = true
            }
            Button("Photo Library") {
                showingImagePicker = true
            }
            if profileImage != nil || contact?.profileImageData != nil {
                Button("Remove Photo", role: .destructive) {
                    profileImage = nil
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                profileImage = image
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                profileImage = image
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func setupInitialValues() {
        if let contact = contact {
            name = contact.name ?? ""
            phoneNumber = contact.phoneNumber ?? ""
            if let imageData = contact.profileImageData {
                profileImage = UIImage(data: imageData)
            }
        }
    }
}

// MARK: - Profile Image Section
struct ProfileImageSection: View {
    let image: UIImage?
    let contact: Contact?
    let onImageTapped: () -> Void
    
    private let contactsManager = ContactsManager.shared
    
    var displayImage: UIImage? {
        if let image = image {
            return image
        }
        if let contact = contact, let imageData = contact.profileImageData {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: onImageTapped) {
                ZStack {
                    Circle()
                        .fill(contactsManager.avatarColor(for: contact?.name ?? "Unknown"))
                        .frame(width: 120, height: 120)
                    
                    if let displayImage = displayImage {
                        Image(uiImage: displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Add Photo")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // Overlay for edit indication
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 120, height: 120)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(displayImage != nil ? "Tap to change photo" : "Tap to add photo")
                .font(.system(size: 14))
                .foregroundColor(ProfessionalColors.textSecondary)
        }
    }
}

// MARK: - Form Field Component
struct FormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ProfessionalColors.textPrimary)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundColor(ProfessionalColors.textPrimary)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .default ? .words : .none)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ProfessionalColors.professionalSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ProfessionalColors.professionalBorder, lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}