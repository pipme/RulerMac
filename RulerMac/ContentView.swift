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
    @Published var showAngleDial: Bool = false
    @Published var isActive: Bool = false
    @Published var pointsPerInch: CGFloat = 72.0
    
    func setUnit(_ unit: MeasurementUnit) {
        units = unit
    }
    
    func setSnapIncrement(_ increment: Double) {
        snapIncrement = increment
    }
    
    func toggleAngleDial() {
        showAngleDial.toggle()
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
            let incrementRad = CGFloat(snapIncrement) * .pi / 180.0
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
            // Calculate snapped angle from Start to End
            let dxRaw = currentEnd.x - start.x
            let dyRaw = currentEnd.y - start.y
            let angle = atan2(dyRaw, dxRaw)
            
            let incrementRad = CGFloat(snapIncrement) * .pi / 180.0
            let snapAngle = round(angle / incrementRad) * incrementRad
            
            let uX = cos(snapAngle)
            let uY = sin(snapAngle)
            
            // Use current length but apply to snapped direction
            let currentLength = sqrt(dxRaw * dxRaw + dyRaw * dyRaw)
            
            // Project the input nudge (dx, dy) onto the unit vector
            let projection = dx * uX + dy * uY
            
            // Calculate new length
            let newLength = currentLength + projection
            
            // Calculate new point on the snapped line
            newPoint = CGPoint(
                x: start.x + newLength * uX,
                y: start.y + newLength * uY
            )
            
            // Clamp with angle preservation
            endPoint = clampPointToScreen(newPoint, anchor: start, size: size)
        } else {
            // Free Nudge
            newPoint = CGPoint(x: currentEnd.x + dx, y: currentEnd.y + dy)
            
            // Standard clamp
            endPoint = CGPoint(
                x: max(0, min(newPoint.x, size.width)),
                y: max(0, min(newPoint.y, size.height))
            )
        }
    }
    
    func nudgeStartPoint(dx: CGFloat, dy: CGFloat, in size: CGSize, isShiftPressed: Bool) {
        guard let currentStart = startPoint, let end = endPoint else { return }
        
        var newPoint: CGPoint
        
        if isShiftPressed {
            // Calculate snapped angle from Start to End
            let dxRaw = end.x - currentStart.x
            let dyRaw = end.y - currentStart.y
            let angle = atan2(dyRaw, dxRaw)
            
            let incrementRad = CGFloat(snapIncrement) * .pi / 180.0
            let snapAngle = round(angle / incrementRad) * incrementRad
            
            let uX = cos(snapAngle)
            let uY = sin(snapAngle)
            
            // Use current length
            let currentLength = sqrt(dxRaw * dxRaw + dyRaw * dyRaw)
            
            // Project the input nudge
            let projection = dx * uX + dy * uY
            
            // Calculate new length (moving start towards end shortens the line)
            let newLength = currentLength - projection
            
            // Calculate new point on the snapped line relative to End
            // Start = End - Length * Vector
            newPoint = CGPoint(
                x: end.x - newLength * uX,
                y: end.y - newLength * uY
            )
            
            // Clamp with angle preservation
            startPoint = clampPointToScreen(newPoint, anchor: end, size: size)
        } else {
            newPoint = CGPoint(x: currentStart.x + dx, y: currentStart.y + dy)
            
            // Standard clamp
            startPoint = CGPoint(
                x: max(0, min(newPoint.x, size.width)),
                y: max(0, min(newPoint.y, size.height))
            )
        }
    }
    
    private func clampPointToScreen(_ point: CGPoint, anchor: CGPoint, size: CGSize) -> CGPoint {
        // 1. If point is inside, return it.
        if point.x >= 0 && point.x <= size.width && 
           point.y >= 0 && point.y <= size.height {
            return point
        }
        
        // 2. Calculate intersection t
        let dx = point.x - anchor.x
        let dy = point.y - anchor.y
        var t: CGFloat = 1.0
        
        // Track which bound limited us
        var hitX = false
        var hitY = false
        
        // Check Right Bound (x = width)
        if dx > 0 {
            let tX = (size.width - anchor.x) / dx
            if tX < t {
                t = tX
                hitX = true
                hitY = false
            }
        }
        // Check Left Bound (x = 0)
        else if dx < 0 {
            let tX = (0 - anchor.x) / dx
            if tX < t {
                t = tX
                hitX = true
                hitY = false
            }
        }
        
        // Check Bottom Bound (y = height)
        if dy > 0 {
            let tY = (size.height - anchor.y) / dy
            if tY < t {
                t = tY
                hitY = true
                hitX = false
            } else if abs(tY - t) < 0.00001 && hitX {
                hitY = true // Corner hit
            }
        }
        // Check Top Bound (y = 0)
        else if dy < 0 {
            let tY = (0 - anchor.y) / dy
            if tY < t {
                t = tY
                hitY = true
                hitX = false
            } else if abs(tY - t) < 0.00001 && hitX {
                hitY = true
            }
        }
        
        // 3. Calculate intersection point
        var intersection = CGPoint(x: anchor.x + t * dx, y: anchor.y + t * dy)
        
        // 4. Snap to bounds if we hit them
        // This fixes the "stops before edge" issue due to floating point precision
        if hitX {
            intersection.x = (dx > 0) ? size.width : 0
        }
        if hitY {
            intersection.y = (dy > 0) ? size.height : 0
        }
        
        // 5. Hard clamp as final safety
        return CGPoint(
            x: max(0, min(intersection.x, size.width)),
            y: max(0, min(intersection.y, size.height))
        )
    }
    
    func ensurePointsAreVisible(in size: CGSize) {
        if let start = startPoint {
            startPoint = CGPoint(
                x: max(0, min(start.x, size.width)),
                y: max(0, min(start.y, size.height))
            )
        }
        if let end = endPoint {
            endPoint = CGPoint(
                x: max(0, min(end.x, size.width)),
                y: max(0, min(end.y, size.height))
            )
        }
    }
}

// This view is now for the overlay, not a window
struct RulerOverlayView: View {
    @ObservedObject var controller: RulerViewController
    
    @State private var isShiftPressed = false
    @State private var viewSize: CGSize = .zero
    
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
        
        var degrees = atan2(-dy, dx) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        
        if abs(degrees) < 0.05 || abs(degrees - 360) < 0.05 {
            return 0.0
        }
        
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
        let ppi = controller.pointsPerInch
        
        switch unit {
        case .pixels:
            return value
        case .inches:
            return value / ppi
        case .centimeters:
            return (value / ppi) * 2.54
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
        
        if position.y - boxHeight/2 < padding {
            position.y = midPoint.y + 60
        }
        
        position.x = max(boxWidth/2 + padding, min(position.x, size.width - boxWidth/2 - padding))
        position.y = max(boxHeight/2 + padding, min(position.y, size.height - boxHeight/2 - padding))
        
        return position
    }
    
    var body: some View {
        GeometryReader { geometry in
            let currentEndPoint = getEndPoint(in: geometry.size)
            
            ZStack {
                Color.clear
                    .onAppear { viewSize = geometry.size }
                    .onChange(of: geometry.size) { oldSize, newSize in
                        viewSize = newSize
                        controller.ensurePointsAreVisible(in: newSize)
                    }
                
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
                
                if controller.isActive {
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
                    
                    if let start = controller.startPoint, let end = currentEndPoint {
                        Path { path in
                            path.move(to: start)
                            path.addLine(to: CGPoint(x: end.x, y: start.y))
                            path.addLine(to: end)
                        }
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .shadow(color: .black, radius: 1)
                        
                        Path { path in
                            path.move(to: start)
                            path.addLine(to: end)
                        }
                        .stroke(Color.blue, lineWidth: 3)
                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                        
                        TickMarks(startPoint: start, endPoint: end)
                            .stroke(Color.blue, lineWidth: 1.5)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(controller.activePoint == .start ? Color.yellow : Color.white, lineWidth: controller.activePoint == .start ? 3 : 2))
                            .position(start)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(controller.activePoint == .end ? Color.yellow : Color.white, lineWidth: controller.activePoint == .end ? 3 : 2))
                            .position(end)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                        
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
                    
                    if controller.showAngleDial {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                VStack(spacing: 5) {
                                    Text("Snap Angle")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .shadow(radius: 1)
                                    SnapAngleDial(angle: $controller.snapIncrement)
                                        .frame(width: 140, height: 70)
                                    Text("Drag knob to set")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.9))
                                        .shadow(radius: 1)
                                }
                                .padding(20)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
                let newShiftState = event.modifierFlags.contains(.shift)
                
                // If Shift is released (transition from true to false)
                if self.isShiftPressed && !newShiftState {
                    // Commit the snapped position
                    if let snappedPoint = self.controller.getEffectiveEndPoint(in: self.viewSize, isShiftPressed: true) {
                        self.controller.endPoint = snappedPoint
                    }
                }
                
                self.isShiftPressed = newShiftState
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

struct SnapAngleDial: View {
    @Binding var angle: Double
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            // Center is at bottom middle
            let center = CGPoint(x: width / 2, y: height - 5)
            let radius = min(width / 2, height) - 5
            
            DialFace(angle: angle, center: center, radius: radius)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let vector = CGPoint(x: value.location.x - center.x, y: value.location.y - center.y)
                            var degrees = atan2(-vector.y, vector.x) * 180 / .pi
                            if degrees < 0 { degrees += 360 }
                            
                            if degrees > 180 {
                                degrees = (degrees > 270) ? 0 : 180
                            }
                            
                            let newAngle = round(degrees)
                            angle = (newAngle == 0) ? 180 : newAngle
                            if angle == 0 { angle = 180 }
                        }
                )
        }
    }
}

struct DialFace: View {
    var angle: Double
    var center: CGPoint
    var radius: CGFloat
    
    var body: some View {
        ZStack {
            DialBackground(center: center, radius: radius)
            DialTicks(center: center, radius: radius)
            DialLabels(center: center, radius: radius)
            DialNeedle(angle: angle, center: center, radius: radius)
            DialValueDisplay(angle: angle, center: center, radius: radius)
        }
    }
}

struct DialBackground: View {
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        ZStack {
            Path { path in
                path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                path.addLine(to: center)
                path.closeSubpath()
            }
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.5), Color.black.opacity(0.8)]),
                    center: .bottom,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .shadow(radius: 4)
            
            Path { path in
                path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 2)
        }
    }
}

struct DialTicks: View {
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        ZStack {
            // Minor ticks
            Path { path in
                for i in 0...18 {
                    if i % 3 != 0 {
                        addTick(to: &path, at: i, length: 4.0)
                    }
                }
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
            
            // Major ticks
            Path { path in
                for i in 0...18 {
                    if i % 3 == 0 && i % 9 != 0 {
                        addTick(to: &path, at: i, length: 7.0)
                    }
                }
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
            
            // Cardinal ticks
            Path { path in
                for i in 0...18 {
                    if i % 9 == 0 {
                        addTick(to: &path, at: i, length: 10.0)
                    }
                }
            }
            .stroke(Color.white, lineWidth: 2)
        }
    }
    
    private func addTick(to path: inout Path, at index: Int, length: CGFloat) {
        let tickAngle = Double(index) * 10.0
        let angleRadDouble = -tickAngle * .pi / 180.0
        let angleRad = CGFloat(angleRadDouble)
        
        let p1 = CGPoint(
            x: center.x + (radius - 2) * cos(angleRad),
            y: center.y + (radius - 2) * sin(angleRad)
        )
        let p2 = CGPoint(
            x: center.x + (radius - 2 - length) * cos(angleRad),
            y: center.y + (radius - 2 - length) * sin(angleRad)
        )
        
        path.move(to: p1)
        path.addLine(to: p2)
    }
}

struct DialLabels: View {
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        ForEach([0, 45, 90, 135, 180], id: \.self) { tickAngle in
            let angleRadDouble = -Double(tickAngle) * .pi / 180.0
            let angleRad = CGFloat(angleRadDouble)
            let labelRadius = radius - 22
            let p = CGPoint(
                x: center.x + labelRadius * cos(angleRad),
                y: center.y + labelRadius * sin(angleRad)
            )
            
            Text("\(tickAngle)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .position(p)
        }
    }
}

struct DialNeedle: View {
    let angle: Double
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        let currentAngleRad = CGFloat(-angle * .pi / 180.0)
        let knobPos = CGPoint(
            x: center.x + (radius - 5) * cos(currentAngleRad),
            y: center.y + (radius - 5) * sin(currentAngleRad)
        )
        
        ZStack {
            Path { path in
                path.move(to: center)
                path.addLine(to: knobPos)
            }
            .stroke(Color.blue, lineWidth: 2)
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .position(knobPos)
            
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .position(center)
        }
    }
}

struct DialValueDisplay: View {
    var angle: Double
    var center: CGPoint
    var radius: CGFloat
    
    var body: some View {
        Text("\(Int(angle))°")
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(4)
            .background(Color.black.opacity(0.6))
            .cornerRadius(4)
            .position(x: center.x, y: center.y - radius * 0.4)
    }
}

#Preview {
    ContentView()
}
