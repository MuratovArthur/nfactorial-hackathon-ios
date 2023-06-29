import SwiftUI

struct ContentView: View {
    @StateObject var locationManager = LocationManager()

    var body: some View {
        VStack {
            Text("Location updates")
                .font(.title)

            if let location = locationManager.currentLocation {
                Text("Latitude: \(location.coordinate.latitude), Longitude: \(location.coordinate.longitude)")
                    .padding()
            } else {
                Text("Location not available")
                    .padding()
            }
        }
        .onAppear {
            locationManager.startUpdatingLocation()
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
        }
    }
}
