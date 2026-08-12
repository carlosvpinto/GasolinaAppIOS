//
//  ContentView.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 8/5/26.
//
import SwiftUI
import MapKit


struct ContentView: View {
    @StateObject var viewModel = GasViewModel()
    @State private var selectedStation: GasStation?
    
    // Cámara inicial: Si es DEV, apunta a USA
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 33.9700, longitude: -118.2400), distance: 8000)
    )
    
    @State private var gallonsToFill: Double = 14.0
    private let tankCapacity: Double = 14.0
    

    var body: some View {
        ZStack {
            // CAPA 1: MAPA
            Map(position: $cameraPosition) {
                // ICONO DEL CARRO
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

                // GASOLINERAS
                ForEach(viewModel.stations) { station in
                    Annotation(station.name, coordinate: station.coordinate) {
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) { // Capas para el logo y el número
                                // LOGO DE LA ESTACIÓN
                                Image(getLogoName(for: station.name))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 35, height: 35)
                                    .background(Color.white)
                                    .cornerRadius(5)
                                    .shadow(radius: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(station.ranking == 1 ? .blue : .red, lineWidth: 2)
                                    )

                                // BURBUJA DEL NÚMERO (RANKING)
                                Text("\(station.ranking)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 18, height: 18)
                                    .background(station.ranking == 1 ? .blue : .red) // Azul para la #1, Rojo para el resto
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8) // Lo saca un poco del borde
                            }
                            
                            // PRECIO
                            Text("$\(station.price, specifier: "%.2f")")
                                .font(.caption2).bold()
                                .padding(4)
                                .background(station.ranking == 1 ? .blue : .red)
                                .foregroundStyle(.white)
                                .cornerRadius(5)
                        }
                        .onTapGesture { selectedStation = station }
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
        
        
    }

    // VISTA DEL PANEL DE DETALLES
    @ViewBuilder
        func detallesSheet(station: GasStation) -> some View {
            VStack(spacing: 20) {
                Capsule().frame(width: 40, height: 6).foregroundColor(.gray.opacity(0.3))
                
                // Encabezado con logo y precio
                HStack {
                    Image(getLogoName(for: station.name)).resizable().frame(width: 50, height: 50)
                    VStack(alignment: .leading) {
                        Text(station.name).font(.title2).bold()
                        Text("\(station.distanceMiles, specifier: "%.1f") miles away").font(.subheadline)
                    }
                    Spacer()
                    Text("$\(station.price, specifier: "%.2f")").font(.title).bold().foregroundColor(.green)
                }
                
                Divider()
                
                // SECCIÓN DEL SIMULADOR CON TANQUE
                VStack(spacing: 15) {
                    Text("Savings Simulator").font(.headline)
                    
                    HStack(spacing: 30) {
                        // El Tanque Visual
                        GasTankView(progress: gallonsToFill / tankCapacity)
                        
                        // Los números del ahorro
                        VStack(alignment: .leading) {
                            let savings = (viewModel.averagePrice - station.price) * gallonsToFill
                            
                            Text("$\(savings, specifier: "%+.2f")")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(savings >= 0 ? .green : .red)
                            
                            Text("Promedio local: $\(viewModel.averagePrice, specifier: "%.2f")")
                                .font(.caption2).foregroundColor(.secondary)
                            
                            Text("Llenando \(gallonsToFill, specifier: "%.1f") galones")
                                .font(.subheadline).bold()
                        }
                    }
                    
                    // Slider para controlar los galones
                    Slider(value: $gallonsToFill, in: 0...tankCapacity, step: 0.5)
                        .tint(viewModel.averagePrice - station.price >= 0 ? .green : .red)
                }
                .padding()
                .background(Color(red: 0.05, green: 0.1, blue: 0.2)) // Tu azul Navy
                .cornerRadius(15)
                
                Button("Navigate to Station") {
                    let url = URL(string: "http://maps.apple.com/?daddr=\(station.coordinate.latitude),\(station.coordinate.longitude)")!
                    UIApplication.shared.open(url)
                }.buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .presentationDetents([.medium])
        }
}

// TARJETA DE ESTACIÓN
struct StationCard: View {
    let station: GasStation
    
    var body: some View {
        HStack(spacing: 12) {
            // NÚMERO DE RANKING GRANDE
            Text("\(station.ranking)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(station.ranking == 1 ? .blue : .red)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name).font(.headline).lineLimit(1)
                
                HStack {
                    Text("$\(station.price, specifier: "%.2f")")
                        .font(.title3).bold()
                    Spacer()
                    Text(String(format: "%.1f mi", station.distanceMiles))
                        .font(.caption).opacity(0.7)
                }
            }
        }
        .padding()
        .frame(width: 260)
        .background(Color(red: 0.05, green: 0.1, blue: 0.2)) // Azul Navy
        .foregroundColor(.white)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(station.ranking == 1 ? .blue : .red.opacity(0.5), lineWidth: 2)
        )
    }
}

func getLogoName(for stationName: String) -> String {
    // Convertimos a minúsculas para comparar sin errores
    let name = stationName.lowercased()
    
    // IMPORTANTE: Todas las comparaciones deben ser en MINÚSCULAS
    if name.contains("76") { return "76_1" }
    if name.contains("costco") { return "costco_2" }
    
    // Corregido: "shell" en minúscula
    if name.contains("shell") { return "shell_2" }
    
    if name.contains("mobil") { return "mobil_2" }
    if name.contains("exxon") { return "exxon_1" }
    
    // Agregamos las que aparecen en tu mapa:
    if name.contains("chevron") { return "exxon_1" } // Usa el de exxon si no tienes uno de chevron
    if name.contains("eleven") || name.contains("7-") { return "gasolina_1" } // O el logo de 7-eleven si lo tienes
    
    return "gasolina_1"
}

func areaParaEnfocar(estaciones: [GasStation], usuario: CLLocationCoordinate2D) -> MKMapRect {
    // 1. Empezamos con un punto que es la posición del usuario
    var rect = MKMapRect(origin: MKMapPoint(usuario), size: MKMapSize(width: 0, height: 0))
    
    // 2. Expandimos el rectángulo para incluir cada estación
    for station in estaciones {
        let stationPoint = MKMapPoint(station.coordinate)
        rect = rect.union(MKMapRect(origin: stationPoint, size: MKMapSize(width: 0, height: 0)))
    }
    
    return rect
}





#Preview {
    ContentView()
}
