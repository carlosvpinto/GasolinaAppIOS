//
//  Helpers.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 9/20/26.
//
import SwiftUI
import MapKit

// Devuelve el color del semáforo basado en el ranking
func colorForRanking(_ rank: Int) -> Color {
    switch rank {
    case 1: return .green
    case 2: return .yellow
    default: return .red
    }
}

// Devuelve el nombre del Asset del logo
func getLogoName(for stationName: String) -> String {
    let name = stationName.lowercased()
    
    // Nombres ajustados EXACTAMENTE a tu carpeta Assets:
    if name.contains("76") { return "76_1" }
    if name.contains("costco") { return "costco_2" }
    if name.contains("shell") { return "shell_2" }
    if name.contains("mobil") { return "mobil_2" }
    if name.contains("exxon") { return "exxon_1" }
    
    // Como NO tienes el logo de Chevron, le decimos que use el genérico por ahora
    // (O puedes usar "exxon_1" si prefieres)
    if name.contains("chevron") { return "gasolina_1" }
    
    if name.contains("eleven") || name.contains("7-") { return "gasolina_1" }
    
    // El genérico por defecto
    return "gasolina_1"
}

// Calcula la cámara del mapa para que todos quepan en pantalla
func regionParaEnfocar(estaciones: [GasStation], usuario: CLLocationCoordinate2D) -> MKCoordinateRegion {
    var minLat = usuario.latitude
    var maxLat = usuario.latitude
    var minLng = usuario.longitude
    var maxLng = usuario.longitude
    
    for station in estaciones {
        minLat = min(minLat, station.coordinate.latitude)
        maxLat = max(maxLat, station.coordinate.latitude)
        minLng = min(minLng, station.coordinate.longitude)
        maxLng = max(maxLng, station.coordinate.longitude)
    }
    
    let centro = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
    let span = MKCoordinateSpan(latitudeDelta: abs(maxLat - minLat) * 1.5, longitudeDelta: abs(maxLng - minLng) * 1.5)
    return MKCoordinateRegion(center: centro, span: span)
}
