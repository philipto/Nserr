import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var recognizedKilometers = ""
    
    // Using the provided API key
    let apiKey = "AIzaSyBr4_p1SiK8yzY8_Qj6txbbyZg6pMRnFjw"

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
                                    recognizeMileageFromImage(uiImage) // Automatically recognize mileage after upload
                                } else {
                                    print("Failed to convert imageData to UIImage") // DEBUG
                                }
                            } catch {
                                print("Failed to load image: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                Text("Recognized Kilometers: \(recognizedKilometers)")
                    .font(.title2)
                    .padding()
            }
            .navigationTitle("Odometer Scanner")
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

    // Function to send the image to Google Cloud Vision API and process the recognized text
    func recognizeMileageFromImage(_ image: UIImage) {
        // Preprocess the image before sending it to Google Cloud Vision
        guard let preprocessedImage = preprocessImage(image) else {
            print("Failed to preprocess image")
            return
        }

        guard let base64Image = imageToBase64(image: preprocessedImage) else {
            print("Failed to convert preprocessed image to base64") // DEBUG
            return
        }

        let requestUrl = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(apiKey)")!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "requests": [
                [
                    "image": [
                        "content": base64Image
                    ],
                    "features": [
                        [
                            "type": "TEXT_DETECTION"
                        ]
                    ]
                ]
            ]
        ]

        let requestBodyData = try! JSONSerialization.data(withJSONObject: requestBody, options: [])

        let task = URLSession.shared.uploadTask(with: request, from: requestBodyData) { data, response, error in
            guard let data = data, error == nil else {
                print("Error occurred: \(error?.localizedDescription ?? "Unknown error")") // DEBUG
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let responses = json["responses"] as? [[String: Any]],
                   let textAnnotations = responses.first?["textAnnotations"] as? [[String: Any]] {
                    
                    // Extract all recognized text by concatenating each "description" from textAnnotations
                    let allRecognizedText = textAnnotations.compactMap { $0["description"] as? String }.joined(separator: " ")

                    print("DEBUG: All recognized text: \(allRecognizedText)") // DEBUG

                    // Dispatch the UI update to show the full recognized text
                    DispatchQueue.main.async {
                        // Regular expression to find sequences of 4 or more digits (e.g., odometer readings)
                        let regex = try? NSRegularExpression(pattern: "\\b\\d{4,}\\b")
                        let matches = regex?.matches(in: allRecognizedText, options: [], range: NSRange(location: 0, length: allRecognizedText.utf16.count))
                        
                        // Extract all matched numbers into an array
                        let results = matches?.compactMap {
                            Range($0.range, in: allRecognizedText).map { String(allRecognizedText[$0]) }
                        }

                        // DEBUG: Print all found numbers
                        print("DEBUG: Found numbers - \(results ?? [])")
                        
                        // Find the longest number in the array
                        if let longestNumber = results?.max(by: { $0.count < $1.count }) {
                            self.recognizedKilometers = longestNumber
                        } else {
                            self.recognizedKilometers = "No valid odometer reading found"
                        }
                    }
                }
            } catch {
                print("Failed to decode JSON response: \(error.localizedDescription)")
            }
        }

        task.resume()
    }
}
