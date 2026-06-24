import SwiftUI
import UIKit

/// Bridges UIImagePickerController for camera / photo-library capture with the
/// system square crop (allowsEditing) — covers the Android logo crop + document
/// image capture in one control.
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var allowsEditing: Bool = true
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = allowsEditing
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            if let image { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Image source picker sheet (SwiftUI — reliable light styling)

/// Bottom sheet for choosing Photo Library / file. Uses SwiftUI (not UIKit
/// `UIAlertController`) because the registration wizard forces a dark scene color
/// scheme for the status bar, which breaks native action-sheet text colours.
struct ImageSourcePickerSheet: View {
    var includeFileOption: Bool = false
    var onPhotoLibrary: () -> Void
    var onFile: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    private let actionBlue = Color(UIColor.systemBlue)
    private let sheetBG = Color(UIColor.systemGroupedBackground)

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                optionButton("Photo Library", action: onPhotoLibrary)
                if includeFileOption, let onFile {
                    Divider()
                    optionButton("Choose File", action: onFile)
                }
            }
            .background(Brand.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                if let onCancel { onCancel() } else { dismiss() }
            } label: {
                Text("Cancel")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(actionBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(sheetBG.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    private func optionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17))
                .foregroundColor(actionBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    /// Compact detent height for the options shown.
    static func detentHeight(includeFileOption: Bool) -> CGFloat {
        includeFileOption ? 204 : 148
    }
}
