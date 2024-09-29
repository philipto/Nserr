import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 300)
                } else {
                    Text("No Image Selected")
                        .foregroundColor(.gray)
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Upload", systemImage: "photo")
                        .font(.title)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .onChange(of: selectedPhotoItem) {
                    if let newItem = selectedPhotoItem {
                        Task {
                            do {
                                if let imageData = try await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: imageData) {
                                    selectedImage = uiImage
                                    print("Image uploaded successfully.") // DEBUG: Confirm image upload
                                } else {
                                    print("Failed to convert imageData to UIImage") // DEBUG
                                }
                            } catch {
                                print("Failed to load image: \(error.localizedDescription)")
                            }
                        }
                    }
                }

            }
            .navigationTitle("NSError test")
        }
    }
    
    // Function to convert UIImage to base64
    func imageToBase64(image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            print("Failed to convert image to JPEG data") // DEBUG
            return nil
        }
        return imageData.base64EncodedString()
    }
    
    // Preprocess function for the image
    func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Convert to grayscale
        let grayscale = ciImage.applyingFilter("CIPhotoEffectMono")

        // Apply contrast adjustment
        let contrastAdjusted = grayscale.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 2.0 // Increase contrast
        ])

        let context = CIContext()
        if let outputImage = context.createCGImage(contrastAdjusted, from: contrastAdjusted.extent) {
            return UIImage(cgImage: outputImage)
        }

        return nil
    }


}
