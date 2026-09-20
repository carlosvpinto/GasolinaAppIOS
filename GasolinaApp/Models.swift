//
//  Models.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 8/5/26.
//import Foundation
import CoreLocation

// 1. El modelo para la interfaz (SwiftUI)
struct GasStation: Identifiable, Equatable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let price: Double
    var distanceMiles: Double = 0.0
    var ranking: Int = 0
    
    var formattedPrice: String {
        String(format: "$%.2f", price)
    }

    static func == (lhs: GasStation, rhs: GasStation) -> Bool {
        return lhs.id == rhs.id && lhs.ranking == rhs.ranking && lhs.price == rhs.price
    }
}

// 2. Modelos para la Respuesta de Precios (Endpoint 1)
// 2. Modelos para la Respuesta de Precios (Endpoint 1) - A PRUEBA DE BALAS
struct PricesResponse: Codable {
    let status: String
    var zip: String?
    let gasPrices: [GasPriceItem]?

    enum CodingKeys: String, CodingKey {
        case status, zip
        case gasPrices = "gas_prices"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = (try? container.decode(String.self, forKey: .status)) ?? "error"
        gasPrices = try? container.decode([GasPriceItem].self, forKey: .gasPrices)
        
        // El ZIP a veces viene como número (90001) y a veces como texto ("90001")
        if let strZip = try? container.decode(String.self, forKey: .zip) {
            zip = strZip
        } else if let intZip = try? container.decode(Int.self, forKey: .zip) {
            zip = String(intZip)
        } else {
            zip = nil
        }
    }
}

struct GasPriceItem: Codable {
    var average: String?
    var lowest: String?
    var stationId: String?
    var price: String?
    let station: String?
    let address: String?

    enum CodingKeys: String, CodingKey {
        case average, lowest, price, station, address
        case stationId = "station_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        station = try? container.decode(String.self, forKey: .station)
        address = try? container.decode(String.self, forKey: .address)
        
        // 1. Flexibilidad para stationId (Int o String)
        if let strId = try? container.decode(String.self, forKey: .stationId) {
            stationId = strId
        } else if let intId = try? container.decode(Int.self, forKey: .stationId) {
            stationId = String(intId)
        }
        
        // 2. Flexibilidad para price (Double o String)
        if let strPrice = try? container.decode(String.self, forKey: .price) {
            price = strPrice
        } else if let dblPrice = try? container.decode(Double.self, forKey: .price) {
            price = String(dblPrice)
        }
        
        // 3. Flexibilidad para average (Double o String)
        if let strAvg = try? container.decode(String.self, forKey: .average) {
            average = strAvg
        } else if let dblAvg = try? container.decode(Double.self, forKey: .average) {
            average = String(dblAvg)
        }
        
        // 4. Flexibilidad para lowest (Double o String)
        if let strLow = try? container.decode(String.self, forKey: .lowest) {
            lowest = strLow
        } else if let dblLow = try? container.decode(Double.self, forKey: .lowest) {
            lowest = String(dblLow)
        }
    }
}

// 3. Modelos para Detalles de Estación (Endpoint 2)
struct StationDataResponse: Codable {
    let status: String
    let data: StationDetails?
}

struct StationDetails: Codable {
    let stationId: String?
    let name: String?
    let coordinates: APIByCoordinates?

    enum CodingKeys: String, CodingKey {
        case name, coordinates
        case stationId = "station_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try? container.decode(String.self, forKey: .name)
        coordinates = try? container.decode(APIByCoordinates.self, forKey: .coordinates)
        
        if let strId = try? container.decode(String.self, forKey: .stationId) {
            stationId = strId
        } else if let intId = try? container.decode(Int.self, forKey: .stationId) {
            stationId = String(intId)
        } else {
            stationId = nil
        }
    }
}

struct APIByCoordinates: Codable {
    let lat: Double?
    let lng: Double?

    // 🟢 CAMBIO APLICADO: Agregamos el enum CodingKeys que faltaba
    enum CodingKeys: String, CodingKey {
        case lat
        case lng
    }

    init(from decoder: Decoder) throws {
        // Ahora Swift ya sabe qué es CodingKeys.self
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 1. Intentar procesar LATITUD
        if let dLat = try? container.decode(Double.self, forKey: .lat) {
            self.lat = dLat
        } else if let sLat = try? container.decode(String.self, forKey: .lat) {
            self.lat = Double(sLat)
        } else {
            self.lat = nil
        }

        // 2. Intentar procesar LONGITUD
        if let dLng = try? container.decode(Double.self, forKey: .lng) {
            self.lng = dLng
        } else if let sLng = try? container.decode(String.self, forKey: .lng) {
            self.lng = Double(sLng)
        } else {
            self.lng = nil
        }
    }
}
