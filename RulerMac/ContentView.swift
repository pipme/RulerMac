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
    @State private var isShiftPressed = false
    weak var controller: RulerViewController?
    
    init(controller: RulerViewController?) {
        self.controller = controller
    }
    
    func getEndPoint(in size: CGSize) -> CGPoint? {
        guard let start = startPoint, let end = endPoint else { return nil }
        
        if isShiftPressed {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let angle = atan2(dy, dx)
            
            // Snap to 45 degree increments (pi/4)
            let snapAngle = round(angle / (.pi / 4)) * (.pi / 4)
            let rawDistance = sqrt(dx*dx + dy*dy)
            
            // Calculate intersection with bounds to maintain angle
            let cosA = cos(snapAngle)
            let sinA = sin(snapAngle)
            
            var tLimit = CGFloat.infinity
            
            // Check X bounds
            if abs(cosA) > 0.001 {
                if cosA > 0 {
                    tLimit = min(tLimit, (size.width - start.x) / cosA)
                } else {
                    tLimit = min(tLimit, (0 - start.x) / cosA)
                }
            }
            
            // Check Y bounds
            if abs(sinA) > 0.001 {
                if sinA > 0 {
                    tLimit = min(tLimit, (size.height - start.y) / sinA)
                } else {
                    tLimit = min(tLimit, (0 - start.y) / sinA)
                }
            }
            
            let distance = min(rawDistance, tLimit)
            
            return CGPoint(
                x: start.x + distance * cosA,
                y: start.y + distance * sinA
            )
        }
        return end
    }

    func getDistance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func getAngle(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        var degrees = atan2(dy, dx) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return degrees
    }
    
    func getDeltaX(from start: CGPoint, to end: CGPoint) -> CGFloat {
        return abs(end.x - start.x)
    }
    
    func getDeltaY(from start: CGPoint, to end: CGPoint) -> CGFloat {
        return abs(end.y - start.y)
    }
    
    func convert(_ value: CGFloat) -> CGFloat {
        let unit = controller?.units ?? .pixels
        switch unit {
        case .pixels:
            return value
        case .inches:
            return value / 72.0
        case .centimeters:
            return value / 28.346
        }
    }
    
    func getConvertedDistance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        convert(getDistance(from: start, to: end))
    }
    
    var unitString: String {
        controller?.units.rawValue ?? "px"
    }
    
    func getMidPoint(from start: CGPoint, to end: CGPoint) -> CGPoint {
        return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let currentEndPoint = getEndPoint(in: geometry.size)
            
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
                
                // Instructions when not drawing
                if startPoint == nil {
                    VStack {
                        Text("Click and drag to measure")
                        Text("Hold Shift to snap to 45° angles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                }
                
                // Only draw ruler if we have both points
                if let start = startPoint, let end = currentEndPoint {
                    // Triangle lines (Delta X/Y)
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: CGPoint(x: end.x, y: start.y))
                        path.addLine(to: end)
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .shadow(color: .black, radius: 1)
                    
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
                    let midPoint = getMidPoint(from: start, to: end)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Dist:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.1f %@", getConvertedDistance(from: start, to: end), unitString))
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Angle:")
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(format: "%.1f°", getAngle(from: start, to: end)))
                        }
                        
                        Divider().background(Color.white.opacity(0.5))
                        
                        HStack {
                            Text("ΔX:")
                            Spacer()
                            Text(String(format: "%.1f", convert(getDeltaX(from: start, to: end))))
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("ΔY:")
                            Spacer()
                            Text(String(format: "%.1f", convert(getDeltaY(from: start, to: end))))
                        }
                        .font(.caption)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(width: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.75))
                            .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    )
                    .position(x: midPoint.x, y: midPoint.y - 60)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
                self.isShiftPressed = event.modifierFlags.contains(.shift)
                return event
            }
        }
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
