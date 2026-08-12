//
//  GasTankView.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 8/7/26.
//

import SwiftUI

struct GasTankView: View {
    let progress: Double // Valor de 0.0 a 1.0
    
    // Lógica de colores dinámica según el llenado
    var tankColor: Color {
        if progress > 0.7 { return .green }
        if progress > 0.3 { return .yellow }
        return .red
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                // Fondo del tanque (vacío)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    )
                
                // Gasolina (líquido que sube)
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [tankColor, tankColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 52, height: CGFloat(progress) * 112)
                    .padding(4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: progress)
                
                // Brillo para efecto de cristal 3D
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 60, height: 120)
            }
            
            // Texto del porcentaje
            Text("\(Int(progress * 100))%")
                .font(.system(.caption, design: .monospaced))
                .bold()
                .foregroundColor(tankColor)
        }
    }
}

// Esto es opcional, sirve para ver el diseño en Xcode sin correr la app
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        GasTankView(progress: 0.5)
    }
}
