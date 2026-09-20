import SwiftUI
import CoreLocation
import MapKit
import Combine
import Contacts

@MainActor
class GasViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    // 🚩 INTERRUPTOR MAESTRO
    @Published var isDevMode: Bool = true
    
    @Published var stations: [GasStation] = []
    @Published var isLoading = false
    @Published var averagePrice: Double = 3.60 // Valor por defecto por si falla la API
    @Published var errorMessage: String? = nil
    
    // 🟢 NUEVO: Controla la cámara del mapa (Centro y Zoom)
        @Published var mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.97, longitude: -118.24),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    
    // Coordenadas constantes de USA (Los Ángeles)
    let devLoc = CLLocationCoordinate2D(latitude: 33.9700, longitude: -118.2400)
    let devZip = "90001"
    
    
    

    
    // 1. Cambia el nombre de la variable y quita el 'private'
    let clManager = CLLocationManager()

    // 2. En el init, asegúrate de usar el nuevo nombre
    override init() {
        super.init()
        clManager.delegate = self // Antes decía locationManager.delegate
        
        if isDevMode {
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
            clManager.requestWhenInUseAuthorization()
            clManager.startUpdatingLocation()
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
            clManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if isDevMode { return }
        
        guard let realLocation = locations.last else {
            self.isLoading = false
            return
        }
        clManager.stopUpdatingLocation()
        
        Task {
            do {
                // 🛠️ MÉTODO MODERNO: Usamos MKLocalSearch para "mirar" las coordenadas
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "\(realLocation.coordinate.latitude), \(realLocation.coordinate.longitude)"
                request.resultTypes = .address
                
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                // Apple ahora prefiere que usemos el objeto 'address' de Contacts
                // Esto elimina la advertencia de 'placemark'
                if let mapItem = response.mapItems.first {
                    // Intentamos extraer el código postal de la dirección formateada
                    if let zip = mapItem.placemark.postalCode {
                        print("✅ ZIP detectado: \(zip)")
                        await self.loadGasStations(zip: zip, userLoc: realLocation)
                    } else {
                        // Si el objeto no tiene ZIP (Caso Venezuela), usamos Los Ángeles como fallback
                        print("⚠️ No hay ZIP en esta zona. Teletransportando a USA...")
                        await self.loadGasStations(zip: "90001", userLoc: CLLocation(latitude: 33.97, longitude: -118.24))
                    }
                }
                
            } catch {
                print("❌ Error en localización moderna: \(error.localizedDescription)")
                // Ante cualquier error de red o GPS, cargamos USA para que el tester vea algo
                await self.loadGasStations(zip: "90001", userLoc: CLLocation(latitude: 33.97, longitude: -118.24))
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
                        
                        // 🟢 NUEVO: Llamamos al auto-encuadre pasando tu posición y las estaciones encontradas
                        self.fitMapToMarkers(userLocation: userLoc.coordinate, stations: rankedStations)
                        
            
        } catch let DecodingError.dataCorrupted(context) {
                    print("❌ JSON Corrupto: \(context)")
                    self.errorMessage = "Error de formato en los datos."
                    self.isLoading = false
                } catch let DecodingError.keyNotFound(key, context) {
                    print("❌ Falta la llave '\(key.stringValue)' en el JSON: \(context.debugDescription)")
                    self.errorMessage = "Faltan datos en el servidor."
                    self.isLoading = false
                } catch let DecodingError.valueNotFound(value, context) {
                    print("❌ Valor nulo encontrado donde se esperaba \(value): \(context.debugDescription)")
                    self.errorMessage = "Datos incompletos."
                    self.isLoading = false
                } catch let DecodingError.typeMismatch(type, context)  {
                    print("❌ Tipo de dato incorrecto. Se esperaba '\(type)': \(context.debugDescription)")
                    self.errorMessage = "Error en el tipo de datos."
                    self.isLoading = false
                } catch {
                    print("❌ ERROR CRÍTICO: \(error.localizedDescription)")
                    self.errorMessage = "Error de conexión o servidor."
                    self.isLoading = false
                }
    }
    
    // 🟢 NUEVA FUNCIÓN: Calcula el zoom perfecto para que quepa todo
        private func fitMapToMarkers(userLocation: CLLocationCoordinate2D, stations: [GasStation]) {
            // 1. Iniciamos los límites con la posición de tu carrito
            var minLat = userLocation.latitude
            var maxLat = userLocation.latitude
            var minLng = userLocation.longitude
            var maxLng = userLocation.longitude
            
            // 2. Comparamos con cada estación para agrandar el marco si es necesario
            for station in stations {
                minLat = min(minLat, station.coordinate.latitude)
                maxLat = max(maxLat, station.coordinate.latitude)
                minLng = min(minLng, station.coordinate.longitude)
                maxLng = max(maxLng, station.coordinate.longitude)
            }
            
            // 3. Calculamos el centro exacto de ese rectángulo
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            )
            
            // 4. Calculamos el "Zoom" (Span). Multiplicamos por 1.4 para dejar un "margen" (padding)
            // para que los pines no queden pegados a los bordes de la pantalla.
            let span = MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.4,
                longitudeDelta: (maxLng - minLng) * 1.4
            )
            
            // 5. Animamos la cámara del mapa
            DispatchQueue.main.async {
                // El 'withAnimation' hace que el mapa vuele suavemente como un dron
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.mapRegion = MKCoordinateRegion(center: center, span: span)
                }
            }
        }
}
