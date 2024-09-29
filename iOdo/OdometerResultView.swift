import SwiftUI

struct OdometerResultView: View {
    let image: UIImage
    let recognizedKilometers: String
    
    var body: some View {
        VStack {
            Text("Recognized Kilometers: \(recognizedKilometers)")
                .font(.title2)
                .padding()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 300)
                .border(Color.red, width: 2) // Simulate a frame around the recognized number

            Spacer()
            
            Button(action: {
                // Navigate back to home
            }) {
                Text("Home")
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Odometer Result")
    }
}
