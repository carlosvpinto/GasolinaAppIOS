//
//  ContentView.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 8/5/26.
//
import SwiftUI
import MapKit

// 2. VISTA PRINCIPAL
struct ContentView: View {
    @StateObject var viewModel = GasViewModel()
    @State private var selectedStation: GasStation?
    
    // Cámara inicial apuntando a USA
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 33.9700, longitude: -118.2400), distance: 8000)
    )
    
    @State private var gallonsToFill: Double = 14.0
    private let tankCapacity: Double = 14.0

    var body: some View {
        ZStack {
            // CAPA 1: MAPA
            Map(position: $cameraPosition) {
                // ICONO DEL CARRO ACTUAL
                if viewModel.isDevMode {
                    Annotation("Me", coordinate: viewModel.devLoc) {
                        Image("icon_carro_b")
                            .resizable().scaledToFit().frame(width: 40, height: 40).shadow(radius: 3)
                    }
                } else {
                    UserAnnotation {
                        Image("icon_carro_b")
                            .resizable().scaledToFit().frame(width: 40, height: 40).shadow(radius: 3)
                    }
                }

                // GASOLINERAS USANDO EL COMPONENTE MODULAR
                ForEach(viewModel.stations) { station in
                    Annotation(station.name, coordinate: station.coordinate) {
                        StationMarkerView(station: station)
                            .onTapGesture {
                                selectedStation = station
                            }
                    }
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .preferredColorScheme(.dark)
            .ignoresSafeArea()

            // CAPA 2: BOTÓN FLOTANTE (FAB)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.refreshSearch()
                        withAnimation {
                            if viewModel.isDevMode {
                                cameraPosition = .camera(MapCamera(centerCoordinate: viewModel.devLoc, distance: 8000))
                            } else {
                                cameraPosition = .userLocation(fallback: .automatic)
                            }
                        }
                    }) {
                        ZStack {
                            Circle().fill(Color(red: 0.05, green: 0.1, blue: 0.2)).frame(width: 60, height: 60)
                            Image(systemName: "arrow.clockwise").font(.title2.bold()).foregroundColor(.white)
                                .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                                .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                        }
                        .overlay(Circle().stroke(Color.red, lineWidth: 3))
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, viewModel.stations.isEmpty ? 30 : 160)
                }
            }

            // CAPA 3: LISTA DE TARJETAS
            VStack {
                Spacer()
                if !viewModel.stations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(viewModel.stations) { station in
                                StationCard(station: station)
                                    .onTapGesture { selectedStation = station }
                            }
                        }
                        .padding()
                    }
                }
            }

            // CAPA 4: INDICADOR DEV
            if viewModel.isDevMode {
                VStack {
                    Text("MODO DESARROLLO (USA)")
                        .font(.caption2).bold().padding(5)
                        .background(Color.orange).foregroundColor(.black).cornerRadius(5)
                    Spacer()
                }.padding(.top, 60)
            }
            
            // CAPA 5: CARGANDO
            if viewModel.isLoading {
                ProgressView().padding().background(.ultraThinMaterial).cornerRadius(10)
            }
        }
        .sheet(item: $selectedStation) { station in
            detallesSheet(station: station)
        }
        .alert("Aviso", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        // AJUSTE AUTOMÁTICO DE CÁMARA PARA QUE QUEPAN TODOS
        // AJUSTE AUTOMÁTICO DE CÁMARA
        // AJUSTE AUTOMÁTICO DE CÁMARA
        .onChange(of: viewModel.stations) {
            if !viewModel.stations.isEmpty {
                // Obtenemos la posición del usuario (Real o DEV)
                let posicionUsuario = viewModel.isDevMode ? viewModel.devLoc : (viewModel.clManager.location?.coordinate ?? viewModel.devLoc)
                
                // Calculamos la región perfecta
                let region = regionParaEnfocar(estaciones: viewModel.stations, usuario: posicionUsuario)
                
                // Movemos la cámara
                withAnimation(.easeInOut(duration: 1.5)) {
                    cameraPosition = .region(region)
                }
            }
        }
    }

    // VISTA DEL PANEL DE DETALLES (HOJA INFERIOR)
    @ViewBuilder
    func detallesSheet(station: GasStation) -> some View {
        VStack(spacing: 20) {
            Capsule().frame(width: 40, height: 6).foregroundColor(.gray.opacity(0.3))
            
            HStack {
                Image(getLogoName(for: station.name)).resizable().scaledToFit().frame(width: 50, height: 50)
                VStack(alignment: .leading) {
                    Text(station.name).font(.title2).bold()
                    Text("\(station.distanceMiles, specifier: "%.1f") miles away").font(.subheadline)
                }
                Spacer()
                Text(station.formattedPrice).font(.title).bold().foregroundColor(.green)
            }
            
            Divider()
            
            VStack(spacing: 15) {
                Text("Savings Simulator").font(.headline)
                HStack(spacing: 30) {
                    GasTankView(progress: gallonsToFill / tankCapacity)
                    VStack(alignment: .leading) {
                        let savings = (viewModel.averagePrice - station.price) * gallonsToFill
                        Text("$\(savings, specifier: "%+.2f")")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(savings >= 0 ? .green : .red)
                        Text("Compared to local avg: $\(viewModel.averagePrice, specifier: "%.2f")").font(.caption2).foregroundColor(.secondary)
                        Text("Filling \(gallonsToFill, specifier: "%.1f") gallons").font(.subheadline).bold()
                    }
                }
                Slider(value: $gallonsToFill, in: 0...tankCapacity, step: 0.5)
                    .tint(viewModel.averagePrice - station.price >= 0 ? .green : .red)
            }
            .padding().background(Color(red: 0.05, green: 0.1, blue: 0.2)).cornerRadius(15)
            
            Button("Navigate to Station") {
                let url = URL(string: "http://maps.apple.com/?daddr=\(station.coordinate.latitude),\(station.coordinate.longitude)")!
                UIApplication.shared.open(url)
            }.buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding().presentationDetents([.medium])
    }
}

// 3. COMPONENTE TARJETA DE LA LISTA
struct StationCard: View {
    let station: GasStation
    var body: some View {
        HStack(spacing: 12) {
            Text("\(station.ranking)").font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(station.ranking == 1 ? .blue : .red).frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name).font(.headline).lineLimit(1)
                HStack {
                    Text(station.formattedPrice).font(.title3).bold()
                    Spacer()
                    Text("\(station.distanceMiles, specifier: "%.1f") mi").font(.caption).opacity(0.7)
                }
            }
        }
        .padding().frame(width: 260).background(Color(red: 0.05, green: 0.1, blue: 0.2))
        .foregroundColor(.white).cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(station.ranking == 1 ? .blue : .red.opacity(0.5), lineWidth: 2))
    }
}

// 4. FUNCIONES DE AYUDA (LOGOS Y CÁMARA)
func getLogoName(for stationName: String) -> String {
    let name = stationName.lowercased()
    if name.contains("76") { return "76_1" }
    if name.contains("costco") { return "costco_2" }
    if name.contains("shell") { return "shell_2" }
    if name.contains("mobil") { return "mobil_2" }
    if name.contains("exxon") { return "exxon_1" }
    if name.contains("chevron") { return "exxon_1" }
    if name.contains("eleven") || name.contains("7-") { return "gasolina_1" }
    return "gasolina_1"
}

func regionParaEnfocar(estaciones: [GasStation], usuario: CLLocationCoordinate2D) -> MKCoordinateRegion {
    var minLat = usuario.latitude
    var maxLat = usuario.latitude
    var minLng = usuario.longitude
    var maxLng = usuario.longitude
    
    // Encontramos los límites extremos
    for station in estaciones {
        minLat = min(minLat, station.coordinate.latitude)
        maxLat = max(maxLat, station.coordinate.latitude)
        minLng = min(minLng, station.coordinate.longitude)
        maxLng = max(maxLng, station.coordinate.longitude)
    }
    
    // Calculamos el centro
    let centro = CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLng + maxLng) / 2
    )
    
    // Calculamos el "span" (qué tan abierto es el zoom)
    // Añadimos un multiplicador (1.5) para que no queden pegados al borde (padding)
    let span = MKCoordinateSpan(
        latitudeDelta: abs(maxLat - minLat) * 1.5,
        longitudeDelta: abs(maxLng - minLng) * 1.5
    )
    
    return MKCoordinateRegion(center: centro, span: span)
}



#Preview {
    ContentView()
}
