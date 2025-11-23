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

enum ActivePoint {
    case start
    case end
}

// Controller to manage state
class RulerViewController: ObservableObject {
    @Published var units: MeasurementUnit = .pixels
    @Published var startPoint: CGPoint?
    @Published var endPoint: CGPoint?
    @Published var isDrawing = false
    @Published var activePoint: ActivePoint = .end
    @Published var snapIncrement: Double = 45.0
    
    func setUnit(_ unit: MeasurementUnit) {
        units = unit
    }
    
    func setSnapIncrement(_ increment: Double) {
        snapIncrement = increment
    }
    
    func toggleActivePoint() {
        activePoint = (activePoint == .start) ? .end : .start
    }
    
    func getEffectiveEndPoint(in size: CGSize, isShiftPressed: Bool) -> CGPoint? {
        guard let start = startPoint, let end = endPoint else { return nil }
        
        if isShiftPressed {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let angle = atan2(dy, dx)
            
            // Snap to user-selected increments (converted to radians)
            let incrementRad = snapIncrement * .pi / 180.0
            let snapAngle = round(angle / incrementRad) * incrementRad
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
    
    func nudgeEndPoint(dx: CGFloat, dy: CGFloat, in size: CGSize, isShiftPressed: Bool) {
        guard let start = startPoint, let currentEnd = endPoint else { return }
        
        var newPoint: CGPoint
        
        if isShiftPressed {
            // Constrained Nudge: Move only along the snapped line
            let vectorX = currentEnd.x - start.x
            let vectorY = currentEnd.y - start.y
            let angle = atan2(vectorY, vectorX)
            
            let incrementRad = snapIncrement * .pi / 180.0
            let snapAngle = round(angle / incrementRad) * incrementRad
            
            // Unit vector for the snapped angle
            let uX = cos(snapAngle)
            let uY = sin(snapAngle)
            
            // Project the input nudge (dx, dy) onto the unit vector
            // Dot product determines how much to move along the line
            // We use a minimum threshold to ensure movement if the user intends it
            let projection = dx * uX + dy * uY
            
            // If projection is significant, apply it along the vector
            // If it's 0 (perpendicular), we don't move, which is correct for a constraint
            
            // However, to be user friendly, if the user presses a key that is "mostly" in the direction,
            // we should move. The dot product handles this naturally.
            // But for 45 degrees, pressing Right (1,0) gives 0.707 projection.
            // We might want to scale it back up so 1 key press = 1 unit of distance roughly.
            
            let moveAmount = projection
            
            // Apply movement along the snapped vector
            newPoint = CGPoint(
                x: currentEnd.x + moveAmount * uX,
                y: currentEnd.y + moveAmount * uY
            )
            
            // If the point didn't move (perpendicular key press), try to be smart?
            // No, strict constraint is less confusing. "Up" on a horizontal line should do nothing.
            
        } else {
            // Free Nudge
            newPoint = CGPoint(x: currentEnd.x + dx, y: currentEnd.y + dy)
        }
        
        // Clamp to screen
        endPoint = CGPoint(
            x: max(0, min(newPoint.x, size.width)),
            y: max(0, min(newPoint.y, size.height))
        )
    }
    
    func nudgeStartPoint(dx: CGFloat, dy: CGFloat, in size: CGSize, isShiftPressed: Bool) {
        guard let currentStart = startPoint, let end = endPoint else { return }
        
        var newPoint: CGPoint
        
        if isShiftPressed {
            // Constrained Nudge for Start Point
            // Moving start point changes the vector origin, but we want to maintain the angle relative to End Point?
            // Or just move the start point along the line?
            // Let's move along the line to keep the angle constant.
            
            let vectorX = end.x - currentStart.x
            let vectorY = end.y - currentStart.y
            let angle = atan2(vectorY, vectorX)
            
            let incrementRad = snapIncrement * .pi / 180.0
            let snapAngle = round(angle / incrementRad) * incrementRad
            
            let uX = cos(snapAngle)
            let uY = sin(snapAngle)
            
            let projection = dx * uX + dy * uY
            
            // Note: Moving start point "Right" (positive dx) effectively shortens the line if end is to the right.
            // But here we just want to move the point in space.
            // If we move start point along the vector, the angle remains exactly the same.
            
            newPoint = CGPoint(
                x: currentStart.x + projection * uX,
                y: currentStart.y + projection * uY
            )
        } else {
            newPoint = CGPoint(x: currentStart.x + dx, y: currentStart.y + dy)
        }
        
        // Clamp to screen
        startPoint = CGPoint(
            x: max(0, min(newPoint.x, size.width)),
            y: max(0, min(newPoint.y, size.height))
        )
    }
}

// This view is now for the overlay, not a window
struct RulerOverlayView: View {
    @ObservedObject var controller: RulerViewController
    @State private var isShiftPressed = false
    
    init(controller: RulerViewController) {
        self.controller = controller
    }
    
    func getEndPoint(in size: CGSize) -> CGPoint? {
        controller.getEffectiveEndPoint(in: size, isShiftPressed: isShiftPressed)
    }

    func getDistance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func getAngle(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        // In screen coordinates, Y increases downwards.
        // Standard math: 0 is Right, 90 is Up, 180 is Left, 270 is Down.
        // Screen coords: 0 is Right, 90 is Down (positive Y), etc.
        // To match standard protractor feel (0 Right, 90 Up/Top):
        // We invert Y for the calculation.
        
        var degrees = atan2(-dy, dx) * 180 / .pi
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
        let unit = controller.units
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
        controller.units.rawValue
    }
    
    func getMidPoint(from start: CGPoint, to end: CGPoint) -> CGPoint {
        return CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }
    
    func getInfoBoxPosition(midPoint: CGPoint, in size: CGSize) -> CGPoint {
        let boxWidth: CGFloat = 140
        let boxHeight: CGFloat = 110
        let padding: CGFloat = 10
        
        var position = CGPoint(x: midPoint.x, y: midPoint.y - 60)
        
        // Check if top is cut off
        if position.y - boxHeight/2 < padding {
            // Move below the midpoint
            position.y = midPoint.y + 60
        }
        
        // Clamp X to be within screen
        position.x = max(boxWidth/2 + padding, min(position.x, size.width - boxWidth/2 - padding))
        
        // Clamp Y to be within screen
        position.y = max(boxHeight/2 + padding, min(position.y, size.height - boxHeight/2 - padding))
        
        return position
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
                                if !controller.isDrawing {
                                    controller.startPoint = clampPoint(value.startLocation, to: geometry.size)
                                    controller.isDrawing = true
                                }
                                controller.endPoint = clampPoint(value.location, to: geometry.size)
                            }
                            .onEnded { _ in
                                controller.isDrawing = false
                            }
                    )
                
                // Instructions when not drawing
                if controller.startPoint == nil {
                    VStack {
                        Text("Click and drag to measure")
                        Text("Hold Shift to snap to \(Int(controller.snapIncrement))° angles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Use Arrow keys to fine-tune (Hold ⌥ for 10px)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        Text("Press Space to switch active point")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                }
                
                // Only draw ruler if we have both points
                if let start = controller.startPoint, let end = currentEndPoint {
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
                        .overlay(Circle().stroke(controller.activePoint == .start ? Color.yellow : Color.white, lineWidth: controller.activePoint == .start ? 3 : 2))
                        .position(start)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                    
                    // End point
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(controller.activePoint == .end ? Color.yellow : Color.white, lineWidth: controller.activePoint == .end ? 3 : 2))
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
                    .position(getInfoBoxPosition(midPoint: midPoint, in: geometry.size))
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
