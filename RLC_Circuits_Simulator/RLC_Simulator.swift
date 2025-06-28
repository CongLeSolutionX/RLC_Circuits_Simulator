//
//MIT License
//
//Copyright © 2025 Cong Le
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//
//  RLCSimulator.swift
//  MyApp
//
//  Created by Cong Le on 6/28/25.
//

import SwiftUI
import Charts // Required for the graph visualization. Available in iOS 16+

// MARK: - Data Model for Charting (Corrected)
/// A simple struct to hold a single data point for charting.
///
/// This replaces `CGPoint` to ensure compatibility with the `Charts` framework.
/// It uses `Double` (a Plottable type) instead of `CGFloat` and is `Identifiable`.
struct DataPoint: Identifiable {
    let x: Double // Represents time (t)
    let y: Double // Represents charge (q)
    
    /// Conformance to Identifiable, allowing the Chart to uniquely identify each point.
    var id: Double { x }
}

/// An enumeration representing the three possible damping states of an RLC circuit.
enum DampingType: String {
    case underdamped = "Underdamped"
    case criticallyDamped = "Critically Damped"
    case overdamped = "Overdamped"
    
    var color: Color {
        switch self {
        case .underdamped: return .blue
        case .criticallyDamped: return .green
        case .overdamped: return .orange
        }
    }
}

/// An `ObservableObject` that handles the physics simulation of a series RLC circuit.
@MainActor
final class RLCSimulator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var resistance: Double = 2.0 { didSet { recalculate() } }
    @Published var inductance: Double = 0.5 { didSet { recalculate() } }
    @Published var capacitance: Double = 0.1 { didSet { recalculate() } }
    
    // ✅ **FIX 1:** The dataPoints array now uses the corrected `DataPoint` struct.
    @Published private(set) var dataPoints: [DataPoint] = []
    
    @Published private(set) var dampingType: DampingType = .underdamped
    
    // MARK: - Simulation Constants
    
    private let timeStep: Double = 0.02
    private let totalDuration: Double = 10.0
    private let initialCharge: Double = 1.0 // q(0) = 1
    private let initialCurrent: Double = 0.0  // i(0) = q'(0) = 0
    
    init() {
        recalculate()
    }
    
    // MARK: - Core Simulation Logic
    
    private func recalculate() {
        guard inductance > 0, capacitance > 0 else {
            dataPoints = []
            return
        }
        
        let alpha = resistance / (2 * inductance)
        let omega0 = 1.0 / sqrt(inductance * capacitance)
        let dampingRatio = alpha / omega0
        
        if dampingRatio < 1 {
            self.dampingType = .underdamped
        } else if dampingRatio.isEqual(to: 1.0) { // Use isEqual for floating point comparison
            self.dampingType = .criticallyDamped
        } else {
            self.dampingType = .overdamped
        }
        
        var points: [DataPoint] = [] // Use the new struct type
        let numberOfSteps = Int(totalDuration / timeStep)
        
        for i in 0...numberOfSteps {
            let t = Double(i) * timeStep
            var charge: Double
            
            switch self.dampingType {
            case .underdamped:
                let omega_d = omega0 * sqrt(1 - dampingRatio * dampingRatio)
                let A1 = initialCharge
                let A2 = (initialCurrent + alpha * initialCharge) / omega_d
                charge = exp(-alpha * t) * (A1 * cos(omega_d * t) + A2 * sin(omega_d * t))
            case .criticallyDamped:
                let A1 = initialCharge
                let A2 = initialCurrent + alpha * initialCharge
                charge = (A1 + A2 * t) * exp(-alpha * t)
            case .overdamped:
                let s1 = -alpha + sqrt(alpha * alpha - omega0 * omega0)
                let s2 = -alpha - sqrt(alpha * alpha - omega0 * omega0)
                let A1 = (initialCurrent - s2 * initialCharge) / (s1 - s2)
                let A2 = (s1 * initialCharge - initialCurrent) / (s1 - s2)
                charge = A1 * exp(s1 * t) + A2 * exp(s2 * t)
            }
            
            // ✅ **FIX 2:** Append an instance of `DataPoint` instead of `CGPoint`.
            points.append(DataPoint(x: t, y: charge))
        }
        
        self.dataPoints = points
    }
}

/// A SwiftUI view that provides an interactive simulation of a series RLC circuit.
struct RLCCircuitView: View {
    
    @StateObject private var simulator = RLCSimulator()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack {
                    Text("RLC Circuit Behavior")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(simulator.dampingType.rawValue)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(simulator.dampingType.color)
                        .contentTransition(.numericText())
                        .animation(.easeInOut, value: simulator.dampingType)
                }
                
                chartView
                    .padding(.horizontal)
                
                VStack(spacing: 15) {
                    parameterSlider(label: "Resistor (R)", value: $simulator.resistance, range: 0...10, unit: "Ω")
                    parameterSlider(label: "Inductor (L)", value: $simulator.inductance, range: 0.1...2.0, unit: "H")
                    parameterSlider(label: "Capacitor (C)", value: $simulator.capacitance, range: 0.05...0.5, unit: "F")
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
            .navigationTitle("⚡️ RLC Circuit Simulator")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    /// A view representing the graph of charge versus time.
    /// ✅ **FIX 3:** This view now correctly compiles without any changes to its internal logic,
    /// because it receives an array of `DataPoint` where `x` and `y` are of type `Double`.
    private var chartView: some View {
        // Since `DataPoint` is Identifiable, you no longer need `id: \.x`
        Chart(simulator.dataPoints) { point in
            LineMark(
                x: .value("Time (s)", point.x),
                y: .value("Charge (q)", point.y)
            )
            .foregroundStyle(simulator.dampingType.color)
            .interpolationMethod(.catmullRom)
            
            if let firstPoint = simulator.dataPoints.first {
                PointMark(
                    x: .value("Time (s)", firstPoint.x),
                    y: .value("Charge (q)", firstPoint.y)
                )
                .foregroundStyle(.primary)
                .symbolSize(80)
                .annotation(position: .top, alignment: .leading) {
                    Text("q(0) = 1.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .background(.thinMaterial, in: Capsule())
                }
            }
        }
        .chartYScale(domain: -1.1...1.1)
        .chartXAxisLabel("Time (s)")
        .chartYAxisLabel("Charge (q)")
        .frame(height: 250)
        .padding(.bottom, 10)
    }
    
    private func parameterSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(value.wrappedValue, specifier: "%.2f") \(unit)").font(.subheadline).foregroundStyle(.secondary).contentTransition(.numericText())
            }
            Slider(value: value, in: range) { Text(label) }
                .tint(simulator.dampingType.color)
        }
    }
}

#Preview {
    RLCCircuitView()
}
