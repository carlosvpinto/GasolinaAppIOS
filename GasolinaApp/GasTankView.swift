import SwiftUI

struct GasTankView: View {
    var progress: Double // De 0.0 a 1.0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Fondo oscuro del tanque
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.5))
                .frame(width: 50, height: 90)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 2))
            
            // Líquido que sube (Animado)
            RoundedRectangle(cornerRadius: 10)
                .fill(fillColor)
                .frame(width: 50, height: 90 * CGFloat(progress))
                .animation(.easeInOut, value: progress)
        }
    }
    
    // Calcula el color dependiendo de qué tan lleno esté
    var fillColor: Color {
        if progress >= 0.6 { return .green }
        else if progress >= 0.25 { return .yellow }
        else { return .red }
    }
}
