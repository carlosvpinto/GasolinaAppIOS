//
//  ContentView.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 8/5/26.
//
//
//  ContentView.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 8/5/26.
//
import SwiftUI
import MapKit

// ==========================================
// 1. VISTA PRINCIPAL
// ==========================================
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
                        Image("icon_carro_b") // Asegúrate de tener este asset en Xcode
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
                                enfocarEstacion(station) // Función para mover cámara y abrir panel
                            }
                    }
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .preferredColorScheme(.dark)
            .ignoresSafeArea()
            
            // CAPA 2: BOTÓN FLOTANTE (RECARGAR)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.refreshSearch()
                    }) {
                        ZStack {
                            Circle().fill(Color(red: 0.05, green: 0.1, blue: 0.2)).frame(width: 50, height: 50)
                            Image(systemName: "arrow.clockwise").font(.title3.bold()).foregroundColor(.white)
                                .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                                .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                        }
                        .overlay(Circle().stroke(Color.red, lineWidth: 2))
                    }
                    .padding(.trailing, 16)
                    // Sube el botón para que no lo tape la lista horizontal
                    .padding(.bottom, viewModel.stations.isEmpty ? 30 : 130)
                }
            }
            
            // CAPA 3: LISTA DE TARJETAS HORIZONTALES (CARRUSEL)
            VStack {
                Spacer()
                if !viewModel.stations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.stations) { station in
                                StationCard(station: station)
                                    .onTapGesture {
                                        enfocarEstacion(station)
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
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
        // BOTTOM SHEET (PANEL INFERIOR)
        .sheet(item: $selectedStation) { station in
            detallesSheet(station: station)
        }
        // ALERTAS DE ERROR
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
        // AUTO-ENCUADRE AL CARGAR LAS ESTACIONES (Cuando la API responde)
        .onChange(of: viewModel.stations) { newValue in
            if !newValue.isEmpty {
                volverAlEncuadreGlobal()
            }
        }
        // AUTO-ENCUADRE AL CERRAR EL SHEET
        .onChange(of: selectedStation) { newValue in
            if newValue == nil && !viewModel.stations.isEmpty {
                volverAlEncuadreGlobal()
            }
        }
    }
    
    // ==========================================
    // 2. FUNCIONES DE CÁMARA
    // ==========================================
    func enfocarEstacion(_ station: GasStation) {
        selectedStation = station
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: station.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            ))
        }
    }
    
    func volverAlEncuadreGlobal() {
        let posicionUsuario = viewModel.isDevMode ? viewModel.devLoc : (viewModel.clManager.location?.coordinate ?? viewModel.devLoc)
        let regionGlobal = regionParaEnfocar(estaciones: viewModel.stations, usuario: posicionUsuario)
        withAnimation(.easeInOut(duration: 1.2)) {
            cameraPosition = .region(regionGlobal)
        }
    }
    
    // ==========================================
    // 3. VISTA DEL PANEL DE DETALLES (BOTTOM SHEET)
    // ==========================================
    @ViewBuilder
    func detallesSheet(station: GasStation) -> some View {
        VStack(spacing: 20) {
            Capsule().frame(width: 40, height: 6).foregroundColor(.gray.opacity(0.3))
            
            HStack {
                Image(getLogoName(for: station.name)).resizable().scaledToFit().frame(width: 50, height: 50)
                VStack(alignment: .leading) {
                    Text(station.name).font(.title2).bold()
                    Text("\(station.distanceMiles, specifier: "%.1f") mi de distancia").font(.subheadline).foregroundColor(.gray)
                }
                Spacer()
                Text(station.formattedPrice).font(.title).bold().foregroundColor(colorForRanking(station.ranking))
            }
            
            Divider()
            
            // SIMULADOR
            VStack(spacing: 15) {
                HStack {
                    Text("Simulador de Ahorro").font(.headline)
                    Spacer()
                    Text("Vehículo: \(tankCapacity, specifier: "%.1f") Gal").font(.caption).foregroundColor(.blue)
                }
                
                HStack(spacing: 30) {
                    GasTankView(progress: gallonsToFill / tankCapacity)
                    
                    VStack(alignment: .leading) {
                        // 1. Usamos la nueva variable 'highestPrice'
                        let savings = (viewModel.highestPrice - station.price) * gallonsToFill
                        
                        // 2. Formateo: Si ahorras algo (>0) es Verde con un "+". Si es 0, queda normal.
                        Text("$\(abs(savings), specifier: savings > 0 ? "+%.2f" : "%.2f")")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(savings > 0 ? .green : .primary)
                        
                        // 3. Cambiamos el texto explicativo para el usuario
                        Text("Frente a la más cara: $\(viewModel.highestPrice, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Llenando \(gallonsToFill, specifier: "%.1f") galones")
                            .font(.subheadline)
                            .bold()
                    }
                    Spacer()
                }
                
                // 4. Actualizamos el Slider para que siempre sea verde (ya que siempre hay ahorro o es igual a 0)
                Slider(value: $gallonsToFill, in: 0...tankCapacity, step: 0.1)
                    .tint(.green)
                    .onChange(of: gallonsToFill) { _ in
                        // Vibración suave al mover el slider
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
            .padding().background(Color(red: 0.1, green: 0.15, blue: 0.25)).cornerRadius(15)
            .padding().background(Color(red: 0.1, green: 0.15, blue: 0.25)).cornerRadius(15)
            
            Button(action: {
                let url = URL(string: "http://maps.apple.com/?daddr=\(station.coordinate.latitude),\(station.coordinate.longitude)")!
                UIApplication.shared.open(url)
            }) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Cómo llegar (Ir)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
            }
            Spacer()
        }
        .padding()
        .presentationDetents([.fraction(0.55), .large]) // El panel sube hasta la mitad primero
    }
}

// ==========================================
// 4. COMPONENTE TARJETA DE LA LISTA (CARRUSEL)
// ==========================================
struct StationCard: View {
    let station: GasStation
    
    var body: some View {
        HStack(spacing: 12) {
            // Número de Ranking
            Text("\(station.ranking)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(station.ranking == 2 ? .black : .white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(colorForRanking(station.ranking)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name).font(.headline).lineLimit(1)
                HStack {
                    Text(station.formattedPrice).font(.title3).bold()
                        .foregroundColor(colorForRanking(station.ranking))
                    Spacer()
                    Text("\(station.distanceMiles, specifier: "%.1f") mi").font(.caption).opacity(0.7)
                }
            }
        }
        .padding()
        .frame(width: 240)
        .background(Color(red: 0.1, green: 0.15, blue: 0.25))
        .foregroundColor(.white)
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(colorForRanking(station.ranking), lineWidth: station.ranking == 1 ? 2 : 1))
    }
}

#Preview {
    ContentView()
}
