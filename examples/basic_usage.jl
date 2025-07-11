# Example Usage of VES.jl

using VES

# Create integration points (needed for numerical integration)
myx, myw = VES.create_integration_points(120)

# Example 1: Homogeneous half-space
println("=== Homogeneous Half-space Example ===")
ρ_homogeneous = [100.0]  # 100 Ω·m
h_homogeneous = Float64[]  # No layer boundaries

# Test different electrode spacings
a_values = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]

println("Electrode spacing (m) | Apparent resistivity (Ω·m)")
println("---------------------|---------------------------")
for a in a_values
    rho_a = VES.wenner_apparent_resistivity(a, ρ_homogeneous, h_homogeneous, myx, myw)
    println("$(lpad(a, 20)) | $(rpad(round(rho_a, digits=2), 25))")
end

# Example 2: Two-layer model
println("\n=== Two-layer Model Example ===")
ρ_two_layer = [50.0, 200.0]  # 50 Ω·m over 200 Ω·m
h_two_layer = [10.0]  # First layer is 10 m thick

println("Electrode spacing (m) | Apparent resistivity (Ω·m)")
println("---------------------|---------------------------")
for a in a_values
    rho_a = VES.wenner_apparent_resistivity(a, ρ_two_layer, h_two_layer, myx, myw)
    println("$(lpad(a, 20)) | $(rpad(round(rho_a, digits=2), 25))")
end

# Example 3: Four-layer model (your specific case)
println("\n=== Four-layer Model Example ===")
ρ_four_layer = [69.1, 127.1, 193.4, 11.7]  # Four layers
h_four_layer = [3.3, 75.6, 72.6]  # Three layer boundaries

println("Electrode spacing (m) | Apparent resistivity (Ω·m)")
println("---------------------|---------------------------")
for a in a_values
    rho_a = VES.wenner_apparent_resistivity(a, ρ_four_layer, h_four_layer, myx, myw)
    println("$(lpad(a, 20)) | $(rpad(round(rho_a, digits=2), 25))")
end

# Example 4: Using measured data to calculate apparent resistivity
println("\n=== Measured Data Example ===")
ΔU = 0.050  # 50 mV measured potential difference
I = 0.010   # 10 mA injected current
a = 5.0     # 5 m electrode spacing

# Geometric factor for Wenner array
G = 2π * a

# Calculate apparent resistivity
rho_measured = VES.apparent_resistivity(ΔU, I, G)
println("Measured potential difference: $(ΔU*1000) mV")
println("Injected current: $(I*1000) mA")
println("Electrode spacing: $a m")
println("Geometric factor: $(round(G, digits=2))")
println("Apparent resistivity: $(round(rho_measured, digits=2)) Ω·m")
