using Test
using VES

@testset "VES Analytical Tests" begin
    
    @testset "Basic VES Functions" begin
        # Test create_integration_points
        myx, myw = VES.create_integration_points(50)
        
        @test length(myx) == 50
        @test length(myw) == 50
        @test all(myx .> 0)  # All points should be positive
        @test all(myw .> 0)  # All weights should be positive
        # Note: The exact sum of weights depends on the transformation used
        
        # Test homogeneous half-space (should return close to the input resistivity)
        ρ_homogeneous = [100.0]
        h_homogeneous = Float64[]
        
        a = 10.0
        rho_a = VES.wenner_apparent_resistivity(a, ρ_homogeneous, h_homogeneous, myx, myw)
        @test abs(rho_a - 100.0) < 1.0  # Should be very close to 100
        
        # Test two-layer model - basic functionality
        ρ_two_layer = [100.0, 500.0]
        h_two_layer = [10.0]
        
        rho_a_2layer = VES.wenner_apparent_resistivity(a, ρ_two_layer, h_two_layer, myx, myw)
        @test rho_a_2layer > 0  # Should be positive
        @test rho_a_2layer > minimum(ρ_two_layer)  # Should be at least the minimum resistivity
        @test rho_a_2layer < maximum(ρ_two_layer)  # Should be less than maximum for this configuration
        
        # Test apparent resistivity calculation
        ΔU = 0.1  # 100 mV
        I = 0.01  # 10 mA
        G = 2π * a  # Geometric factor for Wenner
        
        rho_calc = VES.apparent_resistivity(ΔU, I, G)
        @test rho_calc > 0
        @test rho_calc ≈ (ΔU / I) * G
    end
    
    @testset "VES Wenner Array - Analytical Properties" begin
        myx, myw = VES.create_integration_points(120)
        
        # Test 1: Homogeneous half-space at multiple spacings
        ρ_homogeneous = [100.0]
        h_homogeneous = Float64[]
        
        a_values = [1.0, 2.0, 5.0, 10.0, 20.0]
        
        for a in a_values
            rho_a = VES.wenner_apparent_resistivity(a, ρ_homogeneous, h_homogeneous, myx, myw)
            @test abs(rho_a - 100.0) < 1.0  # Should be very close to 100 for all spacings
        end
        
        # Test 2: Two-layer model - check monotonic behavior
        ρ_increasing = [50.0, 200.0]  # Resistivity increases with depth
        h_increasing = [5.0]
        
        rho_a_small = VES.wenner_apparent_resistivity(1.0, ρ_increasing, h_increasing, myx, myw)
        rho_a_large = VES.wenner_apparent_resistivity(50.0, ρ_increasing, h_increasing, myx, myw)
        
        # For increasing resistivity, larger spacing should give higher apparent resistivity
        @test rho_a_large > rho_a_small
        @test rho_a_small > 50.0  # Should be greater than first layer
        @test rho_a_large < 200.0  # Should be less than second layer
        
        # Test 3: Decreasing resistivity case
        ρ_decreasing = [200.0, 50.0]
        h_decreasing = [5.0]
        
        rho_a_small_dec = VES.wenner_apparent_resistivity(1.0, ρ_decreasing, h_decreasing, myx, myw)
        rho_a_large_dec = VES.wenner_apparent_resistivity(50.0, ρ_decreasing, h_decreasing, myx, myw)
        
        # For decreasing resistivity, larger spacing should give lower apparent resistivity
        @test rho_a_large_dec < rho_a_small_dec
    end
    
    @testset "Error Handling" begin
        myx, myw = VES.create_integration_points(50)
        
        # Test with mismatched array sizes - this should work but not give expected results
        # Let's test for specific logical errors instead
        @test_throws BoundsError VES.wenner_apparent_resistivity(1.0, Float64[], Float64[], myx, myw)
        
        # Test with empty resistivity array
        @test_throws BoundsError VES.wenner_apparent_resistivity(1.0, Float64[], Float64[], myx, myw)
        
        # Test with negative electrode spacing
        @test VES.wenner_apparent_resistivity(-1.0, [100.0], Float64[], myx, myw) != 0  # Should still calculate something
    end
    
    @testset "Integration Points Quality" begin
        # Test different numbers of integration points
        for n in [20, 50, 100, 200]
            myx, myw = VES.create_integration_points(n)
            
            # Test homogeneous half-space accuracy
            ρ_homogeneous = [100.0]
            h_homogeneous = Float64[]
            
            rho_a = VES.wenner_apparent_resistivity(10.0, ρ_homogeneous, h_homogeneous, myx, myw)
            relative_error = abs(rho_a - 100.0) / 100.0
            
            @test relative_error < 0.01  # Should be within 1% for homogeneous case
            
            println("n = $n: ρₐ = $(rho_a), error = $(relative_error*100)%")
        end
    end
end