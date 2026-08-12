//
//  GasApiManager.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 8/5/26.
import Foundation
//
class GasApiManager {
    static let shared = GasApiManager()
    private let baseURL = "https://apigasolina.desoftsis.com/"

    func getPrices(zip: String) async throws -> PricesResponse {
        guard let url = URL(string: "\(baseURL)precios?zip=\(zip)&type=regular&order=asc") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(PricesResponse.self, from: data)
    }

    func getStationDetails(id: String) async throws -> StationDataResponse {
        guard let url = URL(string: "\(baseURL)datos-de-estacion?station_id=\(id)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // --- LÍNEA PARA DEPURAR: Ver qué responde el servidor ---
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 JSON recibido de Estación \(id): \(jsonString)")
        }
        // -------------------------------------------------------

        return try JSONDecoder().decode(StationDataResponse.self, from: data)
    }
}
