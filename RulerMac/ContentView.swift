//
//  ContentView.swift
//  RulerMac
//
//  Created by Li, Chengkun on 21.11.2025.
//

import SwiftUI
import Combine

enum MeasurementUnit: String, CaseIterable {
    case pixels = "px"
    case inches = "in"
    case centimeters = "cm"
}

// Controller to manage state
class RulerViewController: ObservableObject {
    @Published var units: MeasurementUnit = .pixels
    var rulerView: RulerOverlayView
    
    init() {
        self.rulerView = RulerOverlayView(controller: nil)
        self.rulerView.controller = self
    }
    
    func setUnit(_ unit: MeasurementUnit) {
        units = unit
    }
}

// This view is now for the overlay, not a window
struct RulerOverlayView: View {
    @State private var startPoint: CGPoint?
    @State private var endPoint: CGPoint?
    @State private var isDrawing = false
    weak var controller: RulerViewController?
    
    init(controller: RulerViewController?) {
        self.controller = controller
    }
    
    var distance: CGFloat {
        guard let start = startPoint, let end = endPoint else { return 0 }
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }
    
    var angle: CGFloat {
        guard let start = startPoint, let end = endPoint else { return 0 }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let radians = atan2(dy, dx)
        return radians * 180 / .pi
    }
    
    var convertedDistance: CGFloat {
        let unit = controller?.units ?? .pixels
        switch unit {
        case .pixels:
            return distance
        case .inches:
            return distance / 72.0
        case .centimeters:
            return distance / 28.346
        }
    }
    
    var unitString: String {
        controller?.units.rawValue ?? "px"
    }
    
    var midPoint: CGPoint {
        guard let start = startPoint, let end = endPoint else { return .zero }
        return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent background that captures mouse events
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDrawing {
                                    startPoint = clampPoint(value.startLocation, to: geometry.size)
                                    isDrawing = true
                                }
                                endPoint = clampPoint(value.location, to: geometry.size)
                            }
                            .onEnded { _ in
                                isDrawing = false
                            }
                    )
                
                // Only draw ruler if we have both points
                if let start = startPoint, let end = endPoint {
                    // Main ruler line
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    .stroke(Color.blue, lineWidth: 3)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                    
                    // Tick marks
                    TickMarks(startPoint: start, endPoint: end)
                        .stroke(Color.blue, lineWidth: 1.5)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    
                    // Start point
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(start)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                    
                    // End point
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(end)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                    
                    // Measurement label at midpoint
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f %@", convertedDistance, unitString))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(String(format: "%.1f°", angle))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.9))
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    )
                    .position(x: midPoint.x, y: midPoint.y - 30)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func clampPoint(_ point: CGPoint, to size: CGSize) -> CGPoint {
        return CGPoint(
            x: max(0, min(point.x, size.width)),
            y: max(0, min(point.y, size.height))
        )
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Ruler is in menu bar")
                .font(.headline)
            Text("Click the ruler icon ⊞ in the menu bar")
                .font(.caption)
        }
        .padding()
    }
}

struct TickMarks: Shape {
    var startPoint: CGPoint
    var endPoint: CGPoint
    var tickSpacing: CGFloat = 10
    var tickLength: CGFloat = 5
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let distance = sqrt(dx * dx + dy * dy)
        
        guard distance > 0 else { return path }
        
        let dirX = dx / distance
        let dirY = dy / distance
        let perpX = -dirY
        let perpY = dirX
        
        var currentDistance: CGFloat = tickSpacing
        while currentDistance < distance {
            let ratio = currentDistance / distance
            let x = startPoint.x + dx * ratio
            let y = startPoint.y + dy * ratio
            
            let tickSize = (Int(currentDistance) % 50 == 0) ? tickLength * 2 : tickLength
            
            path.move(to: CGPoint(x: x - perpX * tickSize, y: y - perpY * tickSize))
            path.addLine(to: CGPoint(x: x + perpX * tickSize, y: y + perpY * tickSize))
            
            currentDistance += tickSpacing
        }
        
        return path
    }
}

#Preview {
    ContentView()
}
