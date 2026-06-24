import SwiftUI
import GoogleMaps
import CoreLocation

/// Google Maps picker for the Create Account location step — mirrors the Distributor
/// app's `GMSMapView` usage (tap to drop a draggable pin, drag to refine, reverse
/// geocode to fill the address). Set `focus` to recenter the map on a chosen address.
struct GoogleMapView: UIViewRepresentable {
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var address: String
    /// When set, the map recenters + drops a pin there (then is cleared back to nil).
    @Binding var focus: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> GMSMapView {
        // Johannesburg, South Africa — same default camera as the Android trader app.
        let start = CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473)
        let camera = GMSCameraPosition.camera(withTarget: start, zoom: 9)
        let map = GMSMapView(frame: .zero, camera: camera)
        map.delegate = context.coordinator
        map.settings.compassButton = false
        map.settings.zoomGestures = true
        map.settings.scrollGestures = true
        context.coordinator.map = map
        if let lat = latitude, let lng = longitude {
            context.coordinator.placePin(CLLocationCoordinate2D(latitude: lat, longitude: lng),
                                         on: map, zoom: true)
        }
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        if let target = focus {
            context.coordinator.placePin(target, on: map, zoom: true)
            DispatchQueue.main.async { self.focus = nil }
        }
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        private let parent: GoogleMapView
        weak var map: GMSMapView?
        private var marker: GMSMarker?
        private let geocoder = CLGeocoder()

        init(_ parent: GoogleMapView) { self.parent = parent }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            placePin(coordinate, on: mapView, zoom: false)
            commit(coordinate, reverse: true)
        }

        func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
            commit(marker.position, reverse: true)
        }

        /// Moves/creates the pin and (optionally) animates the camera — does NOT write
        /// bindings, so it is safe to call from make/update.
        func placePin(_ coord: CLLocationCoordinate2D, on map: GMSMapView, zoom: Bool) {
            if marker == nil {
                let pin = GMSMarker(position: coord)
                pin.isDraggable = true
                pin.map = map
                marker = pin
            } else {
                marker?.position = coord
            }
            if zoom {
                map.animate(to: GMSCameraPosition.camera(withTarget: coord, zoom: 15))
            }
        }

        private func commit(_ coord: CLLocationCoordinate2D, reverse: Bool) {
            parent.latitude = coord.latitude
            parent.longitude = coord.longitude
            if reverse { reverseGeocode(coord) }
        }

        private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
            geocoder.reverseGeocodeLocation(
                CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            ) { [weak self] placemarks, _ in
                guard let p = placemarks?.first else { return }
                let line = [p.name, p.locality, p.country].compactMap { $0 }.joined(separator: ", ")
                if !line.isEmpty { self?.parent.address = line }
            }
        }
    }
}
