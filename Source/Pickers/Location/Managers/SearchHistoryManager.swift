import UIKit
import MapKit
import Contacts

struct SearchHistoryManager {
    
	fileprivate let HistoryKey = "RecentLocationsKey"
	fileprivate var defaults = UserDefaults.standard
	
	func history() -> [Location] {
		let history = defaults.object(forKey: HistoryKey) as? [NSDictionary] ?? []
		return history.flatMap(Location.fromDefaultsDic)
	}
	
	func addToHistory(_ location: Location) {
		guard let dic = location.toDefaultsDic() else { return }
		
		var history  = defaults.object(forKey: HistoryKey) as? [NSDictionary] ?? []
		let historyNames = history.flatMap { $0[LocationDicKeys.name] as? String }
        let alreadyInHistory = location.name.flatMap(historyNames.contains) ?? false
		if !alreadyInHistory {
			history.insert(dic, at: 0)
			defaults.set(history, forKey: HistoryKey)
		}
	}
}

struct LocationDicKeys {
	static let name = "Name"
	static let locationCoordinates = "LocationCoordinates"
	static let placemarkCoordinates = "PlacemarkCoordinates"
	static let placemarkAddressDic = "PlacemarkAddressDic"
}

struct CoordinateDicKeys {
	static let latitude = "Latitude"
	static let longitude = "Longitude"
}

extension CLLocationCoordinate2D {
    
	func toDefaultsDic() -> NSDictionary {
		return [CoordinateDicKeys.latitude: latitude, CoordinateDicKeys.longitude: longitude]
	}
	
	static func fromDefaultsDic(_ dic: NSDictionary) -> CLLocationCoordinate2D? {
		guard let latitude = dic[CoordinateDicKeys.latitude] as? NSNumber,
			let longitude = dic[CoordinateDicKeys.longitude] as? NSNumber else { return nil }
		return CLLocationCoordinate2D(latitude: latitude.doubleValue, longitude: longitude.doubleValue)
	}
}

extension CNMutablePostalAddress {
    convenience init(placemark: CLPlacemark) {
        self.init()
        street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }           // remove nils, so that...
            .joined(separator: " ")      // ...only if both != nil, add a space.
        /*
         // Equivalent street assignment, w/o flatMap + joined:
         if let subThoroughfare = placemark.subThoroughfare,
         let thoroughfare = placemark.thoroughfare {
         street = "\(subThoroughfare) \(thoroughfare)"
         } else {
         street = (placemark.subThoroughfare ?? "") + (placemark.thoroughfare ?? "")
         }
         */
        city = placemark.locality ?? ""
        state = placemark.administrativeArea ?? ""
        postalCode = placemark.postalCode ?? ""
        country = placemark.country ?? ""
        isoCountryCode = placemark.isoCountryCode ?? ""
        if #available(iOS 10.3, *) {
            subLocality = placemark.subLocality ?? ""
            subAdministrativeArea = placemark.subAdministrativeArea ?? ""
        }
    }
}

extension Location {
    
	func toDefaultsDic() -> NSDictionary? {
        var postalAddress: CNPostalAddress?
        if #available(iOS 11.0, *) {
            postalAddress = placemark.postalAddress
        } else {
            postalAddress = CNMutablePostalAddress.init(placemark: placemark)
        }
        guard let address = postalAddress,
            let placemarkCoordinatesDic = placemark.location?.coordinate.toDefaultsDic()
            else { return nil }
        
        let formatter = CNPostalAddressFormatter()
        let addressDic = formatter.string(from: address)
        
        var dic: [String: AnyObject] = [
            LocationDicKeys.locationCoordinates: location.coordinate.toDefaultsDic(),
            LocationDicKeys.placemarkAddressDic: addressDic as AnyObject,
            LocationDicKeys.placemarkCoordinates: placemarkCoordinatesDic
        ]
        if let name = name { dic[LocationDicKeys.name] = name as AnyObject? }
        return dic as NSDictionary?
	}
	
	class func fromDefaultsDic(_ dic: NSDictionary) -> Location? {
		guard let placemarkCoordinatesDic = dic[LocationDicKeys.placemarkCoordinates] as? NSDictionary,
			let placemarkCoordinates = CLLocationCoordinate2D.fromDefaultsDic(placemarkCoordinatesDic),
			let placemarkAddressDic = dic[LocationDicKeys.placemarkAddressDic] as? [String: AnyObject]
			else { return nil }
		
		let coordinatesDic = dic[LocationDicKeys.locationCoordinates] as? NSDictionary
		let coordinate = coordinatesDic.flatMap(CLLocationCoordinate2D.fromDefaultsDic)
		let location = coordinate.flatMap { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
		
		return Location(name: dic[LocationDicKeys.name] as? String,
			location: location, placemark: MKPlacemark(
                coordinate: placemarkCoordinates, addressDictionary: placemarkAddressDic))
	}
}
