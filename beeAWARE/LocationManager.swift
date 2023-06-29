import CoreLocation
import Combine
import UserNotifications
import Foundation

class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject, UNUserNotificationCenterDelegate {
    private let locationManager = CLLocationManager()
    private var locationTimer: Timer?
    private let apiRequestInterval: TimeInterval = 10 // Interval in seconds for API requests

    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        UNUserNotificationCenter.current().delegate = self
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        scheduleLocationTimer()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        invalidateLocationTimer()
    }

    private func scheduleLocationTimer() {
        locationTimer = Timer.scheduledTimer(withTimeInterval: apiRequestInterval, repeats: true) { [weak self] _ in
            guard let location = self?.currentLocation else { return }
            self?.updateLocationInfo(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        locationTimer?.fire()
    }

    private func invalidateLocationTimer() {
        locationTimer?.invalidate()
        locationTimer = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed with error: \(error.localizedDescription)")
    }

    func updateLocationInfo(latitude: Double, longitude: Double) {
        guard let url = URL(string: "http://172.20.10.2:5000/danger_level?latitude=\(latitude)&longitude=\(longitude)") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                print("Failed to get danger level: \(error.localizedDescription)")
            } else if let data = data {
                let dangerLevel = String(data: data, encoding: .utf8)
                print("Danger Level: \(dangerLevel ?? "unknown")")
                DispatchQueue.main.async {
                    self.scheduleLocationNotification(dangerLevelResponse: dangerLevel ?? "unknown")
                }
            }
        }.resume()
    }

    func scheduleLocationNotification(dangerLevelResponse: String) {
        guard let data = dangerLevelResponse.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonDict = jsonObject as? [String: Any],
              let dangerLevel = jsonDict["danger_level"] as? Int else {
            print("Invalid danger level response format")
            return
        }
        
        var notificationMessage = ""
        
        switch dangerLevel {
        case 1:
            notificationMessage = "Danger Level: Safe"
        case 2:
            notificationMessage = "Danger Level: Medium"
        case 3:
            notificationMessage = "Danger Level: High"
        default:
            notificationMessage = "Danger Level: Unknown"
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Danger Level Update"
        content.body = notificationMessage
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
}
