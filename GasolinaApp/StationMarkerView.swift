import SwiftUI

struct StationMarkerView: View {
    let station: GasStation
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Medalla con el número de ranking
            Text("\(station.ranking)")
                .font(.caption2).bold()
                // Si es el #2 (Amarillo) usamos letra negra, si no, blanca
                .foregroundColor(station.ranking == 2 ? .black : .white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(colorForRanking(station.ranking)))
                .offset(x: 15, y: 10)
                .zIndex(1)
            
            // 2. Cuadro blanco del Logo
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                    .shadow(radius: 3)
                
                Image(getLogoName(for: station.name))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            }
            
            // 3. Triangulito que apunta hacia abajo
            Image(systemName: "triangle.fill")
                .resizable()
                .frame(width: 15, height: 10)
                .foregroundColor(.white)
                .rotationEffect(.degrees(180))
                .offset(y: -2)
                .shadow(radius: 1)
            
            // 4. Etiqueta del Precio
            Text(station.formattedPrice)
                .font(.caption).bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(colorForRanking(station.ranking))
                .foregroundColor(station.ranking == 2 ? .black : .white)
                .cornerRadius(5)
        }
    }
}
