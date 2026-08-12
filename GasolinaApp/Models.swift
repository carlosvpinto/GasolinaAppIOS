//
//  Models.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 8/5/26.
//

import Foundation
import CoreLocation

// 1. El modelo para la interfaz (SwiftUI)
struct GasStation: Identifiable, Equatable { // <--- Agregamos Equatable
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let price: Double
    var distanceMiles: Double = 0.0
    var ranking: Int = 0
    
    // Propiedad para el formateo de precio que hicimos antes
    var formattedPrice: String {
        String(format: "$%.2f", price)
    }

    // 🛠️ Función necesaria para Equatable:
    // Comparamos el ID y el Ranking para saber si la lista cambió
    static func == (lhs: GasStation, rhs: GasStation) -> Bool {
        return lhs.id == rhs.id && lhs.ranking == rhs.ranking && lhs.price == rhs.price
    }
}

// 2. Modelos para la Respuesta de Precios (Endpoint 1)
struct PricesResponse: Codable {
    let status: String
    let zip: String?
    let gasPrices: [GasPriceItem]?

    enum CodingKeys: String, CodingKey {
        case status, zip
        case gasPrices = "gas_prices"
    }
}

struct GasPriceItem: Codable {
    let average: String?
    let lowest: String?
    let stationId: String?
    let price: String?
    let station: String?
    let address: String?

    enum CodingKeys: String, CodingKey {
        case average, lowest, price, station, address
        case stationId = "station_id"
    }
}

// 3. Modelos para Detalles de Estación (Endpoint 2) - VERSIÓN FLEXIBLE
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
        
        // Flexibilidad para el ID (acepta String o Int)
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

    init(from decoder: Decoder) throws {
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
