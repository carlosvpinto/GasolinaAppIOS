//
//  StationMarkerView.swift
//  GasolinaApp
//
//  Created by Carlos Vicente Pinto on 8/12/26.
//

import SwiftUI

struct StationMarkerView: View {
    let station: GasStation
    
    var body: some View {
        // Extraemos la lógica de color a una variable local para ayudar al compilador
        let themeColor = station.ranking == 1 ? Color.blue : Color.red
        
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // LOGO
                Image(getLogoName(for: station.name))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .background(Color.white)
                    .cornerRadius(5)
                    .shadow(radius: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(themeColor, lineWidth: 2)
                    )

                // BURBUJA DEL NÚMERO
                Text("\(station.ranking)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(themeColor)
                    .clipShape(Circle())
                    .offset(x: 8, y: -8)
            }
            
            // PRECIO (Usando la variable que creamos en el modelo)
            Text(station.formattedPrice)
                .font(.caption2).bold()
                .padding(4)
                .background(themeColor)
                .foregroundStyle(.white)
                .cornerRadius(5)
                .shadow(radius: 2)
        }
    }
}


