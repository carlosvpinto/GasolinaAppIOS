import SwiftUI
import CoreLocation
import MapKit
import Combine

@MainActor
class GasViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    // 🚩 INTERRUPTOR MAESTRO
    @Published var isDevMode: Bool = false
    
    @Published var stations: [GasStation] = []
    @Published var isLoading = false
    @Published var averagePrice: Double = 3.60 // Valor por defecto por si falla la API
    @Published var errorMessage: String? = nil
    
    // Coordenadas constantes de USA (Los Ángeles)
    let devLoc = CLLocationCoordinate2D(latitude: 33.9700, longitude: -118.2400)
    let devZip = "90001"
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    
    override init() {
        super.init()
        locationManager.delegate = self
        
        // Carga inicial automática
        if isDevMode {
            print("🛠️ Modo DEV: Cargando USA de inmediato")
            startInitialFetch()
        } else {
            requestLocation()
        }
    }
    
    private func startInitialFetch() {
        let location = CLLocation(latitude: devLoc.latitude, longitude: devLoc.longitude)
        Task { await self.loadGasStations(zip: devZip, userLoc: location) }
    }
    
    func requestLocation() {
        if isDevMode {
            refreshSearch()
        } else {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
    }
    
    func refreshSearch() {
        print("🔄 Refrescando...")
        self.isLoading = true
        self.errorMessage = nil // Limpiamos el error anterior para que el spinner pueda salir
        self.stations = []
        
        if isDevMode {
            let location = CLLocation(latitude: devLoc.latitude, longitude: devLoc.longitude)
            Task { await self.loadGasStations(zip: devZip, userLoc: location) }
        } else {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if isDevMode { return }
        
        guard let realLocation = locations.last else {
            self.isLoading = false
            return
        }
        locationManager.stopUpdatingLocation()
        
        Task {
            do {
                // Intentamos traducir coordenadas a ZIP
                let placemarks = try await geocoder.reverseGeocodeLocation(realLocation)
                
                if let zip = placemarks.first?.postalCode {
                    print("✅ ZIP real detectado: \(zip)")
                    await self.loadGasStations(zip: zip, userLoc: realLocation)
                } else {
                    // CASO VENEZUELA: El GPS funciona, pero no hay ZIP
                    print("⚠️ Ubicación sin código postal (Probablemente fuera de USA)")
                    self.errorMessage = "Tu ubicación actual no tiene un código postal compatible con la búsqueda de gasolina en USA."
                    self.isLoading = false
                }
            } catch {
                // ERROR DE RED O GPS
                print("❌ Error de localización: \(error.localizedDescription)")
                self.errorMessage = "No pudimos determinar tu ubicación exacta. Revisa tu conexión."
                self.isLoading = false
            }
        }
    }
    
    func loadGasStations(zip: String, userLoc: CLLocation) async {
        print("🚀 Iniciando petición al servidor para el ZIP: \(zip)")
        
        // 1. Preparación inicial
        self.isLoading = true
        self.errorMessage = nil // Limpiamos errores anteriores
        self.stations = []      // Limpiamos la lista para mostrar el cargando
        
        do {
            // 2. Llamada principal de precios
            let response = try await GasApiManager.shared.getPrices(zip: zip)
            
            // 3. Capturar el promedio real del API (Primer item de la lista)
            if let prices = response.gasPrices, let firstItem = prices.first, let avgString = firstItem.average {
                let cleanAvg = avgString.replacingOccurrences(of: "$", with: "")
                self.averagePrice = Double(cleanAvg) ?? 3.60
                print("📊 Promedio del área capturado: $\(self.averagePrice)")
            }
            
            // 4. Validar si hay estaciones reales (El primer item es el promedio, por eso buscamos count > 1)
            guard let prices = response.gasPrices, prices.count > 1 else {
                print("⚠️ El servidor no devolvió estaciones para el ZIP: \(zip)")
                self.errorMessage = "No se encontraron estaciones en esta zona."
                self.isLoading = false
                return
            }
            
            var foundStations: [GasStation] = []
            // Tomamos máximo 5 estaciones (saltando el promedio que es el index 0)
            let topItems = Array(prices.dropFirst().prefix(5))
            
            // 5. Ciclo para obtener coordenadas y detalles de cada estación
            for item in topItems {
                if let id = item.stationId {
                    do {
                        let detailRes = try await GasApiManager.shared.getStationDetails(id: id)
                        
                        if let detail = detailRes.data,
                           let coords = detail.coordinates,
                           let lat = coords.lat, let lng = coords.lng {
                            
                            let stationLoc = CLLocation(latitude: lat, longitude: lng)
                            
                            // Conversión de metros a Millas
                            let distanceInMeters = userLoc.distance(from: stationLoc)
                            let distanceInMiles = distanceInMeters / 1609.34
                            
                            // Limpieza del precio
                            let priceNum = Double(item.price?.replacingOccurrences(of: "$", with: "") ?? "0") ?? 0.0
                            
                            let newStation = GasStation(
                                id: id,
                                name: detail.name ?? item.station ?? "Gas Station",
                                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                                price: priceNum,
                                distanceMiles: distanceInMiles
                            )
                            foundStations.append(newStation)
                        }
                    } catch {
                        print("⚠️ Error al obtener detalles de la estación \(id): \(error.localizedDescription)")
                        // Si una estación falla, el ciclo continúa con las demás
                    }
                }
            }
            
            // 6. Verificar si después de buscar detalles tenemos alguna estación válida
            if foundStations.isEmpty {
                self.errorMessage = "No hay datos de ubicación para las estaciones encontradas."
                self.isLoading = false
                return
            }
            
            // 7. Ordenar por precio y asignar ranking
            let sortedStations = foundStations.sorted { $0.price < $1.price }
            var rankedStations: [GasStation] = []
            
            for (index, var station) in sortedStations.enumerated() {
                station.ranking = index + 1 // Puesto 1, 2, 3...
                rankedStations.append(station)
            }
            
            // 8. Actualización final de la interfaz
            self.stations = rankedStations
            self.isLoading = false
            print("🎉 Proceso completado. Estaciones en pantalla: \(self.stations.count)")
            
        } catch {
            // 9. Manejo de errores de conexión o servidor
            print("❌ ERROR CRÍTICO: \(error.localizedDescription)")
            self.errorMessage = "Error de conexión. Revisa tu internet e inténtalo de nuevo."
            self.isLoading = false
        }
    }
}
