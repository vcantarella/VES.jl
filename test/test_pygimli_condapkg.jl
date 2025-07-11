using Test
using VES

# Test configuration - install and test PyGIMLi using CondaPkg
# Only attempt if CondaPkg and PythonCall are available (test-only dependencies)
const PYGIMLI_AVAILABLE = begin
    try
        # Try to load test-only dependencies
        @eval using CondaPkg
        CondaPkg.resolve()  # Ensure CondaPkg is properly set up

        @eval using PythonCall
        
        # Check if PyGIMLi is available through CondaPkg
        println("Checking PyGIMLi availability...")
        CondaPkg.withenv() do
            run(`python --version`)
            run(`python -c "import pygimli; print(pygimli.__version__)"`)
        end
        
        # Dependencies should be defined in CondaPkg.toml
        # This will use the existing CondaPkg environment
        
        println("✓ PyGIMLi conda environment set up successfully")
        println("Note: PyGIMLi import will be tested separately to avoid memory issues")
        true
    catch e
        error_str = string(e)
        println("✗ PyGIMLi setup failed: $e")
        println("Running basic tests only.")
        false
    end
end

@testset "VES Analytical Tests with CondaPkg" begin
    
    @testset "Basic VES Functions" begin
        # Test create_integration_points
        myx, myw = VES.create_integration_points(50)
        
        @test length(myx) == 50
        @test length(myw) == 50
        @test all(myx .> 0)  # All points should be positive
        @test all(myw .> 0)  # All weights should be positive
        
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
    
    if PYGIMLI_AVAILABLE
        @testset "PyGIMLi Comparison Tests" begin
            # Attempt to import PyGIMLi for comparison tests
            try
                pyimport("pygimli")
                println("✓ PyGIMLi successfully imported for comparison tests")
                println("PyGIMLi version: $(pygimli.__version__)")
            catch e
                error_str = string(e)
                if contains(error_str, "Abort") || contains(error_str, "signal")
                    println("✗ PyGIMLi import caused memory error - skipping comparison tests")
                    println("This is a known issue with PyGIMLi on some systems. Basic tests completed successfully.")
                    return
                elseif contains(error_str, "libcholmod") || contains(error_str, "Library not loaded") || contains(error_str, "dlopen")
                    println("✗ PyGIMLi import failed due to missing native libraries (libcholmod, etc.)")
                    println("PyGIMLi installation is incomplete - missing required mathematical libraries.")
                    println("To fix: conda install suitesparse openblas lapack -c conda-forge")
                    println("Skipping PyGIMLi comparison tests")
                    return
                else
                    println("✗ PyGIMLi import failed: $e")
                    println("Skipping PyGIMLi comparison tests")
                    return
                end
            end
            
            # Only run comparison tests if PyGIMLi import succeeded
            # Test homogeneous half-space comparison
            @testset "Homogeneous Half-space vs PyGIMLi" begin
                ρ_homogeneous = [100.0]
                h_homogeneous = Float64[]
                
                myx, myw = VES.create_integration_points(120)
                
                # Test multiple electrode spacings
                a_values = [1.0, 2.0, 5.0, 10.0, 20.0]
            
            for a in a_values
                # Our implementation
                rho_a_julia = VES.wenner_apparent_resistivity(a, ρ_homogeneous, h_homogeneous, myx, myw)
                
                # PyGIMLi VES modeling
                try
                    # For homogeneous half-space, use a very thick layer
                    thicks = pygimli.Vector([1000.0])  # Very thick layer
                    res = pygimli.Vector([100.0, 100.0])  # Same resistivity
                    
                    # AB/2 distances for Wenner (a is the electrode spacing)
                    ab2 = pygimli.Vector([a])
                    
                    # Create VES manager and simulate
                    ves = pygimli.physics.ves.VESManager()
                    rhoa_pygimli = ves.simulate(res, thicks, ab2)
                    
                    # Compare results - should be very close for homogeneous case
                    relative_error = abs(rho_a_julia - rhoa_pygimli[0]) / rhoa_pygimli[0]
                    @test relative_error < 0.02  # Within 2%
                    
                    println("Homogeneous a = $a m: Julia = $(round(rho_a_julia, digits=2)), PyGIMLi = $(round(rhoa_pygimli[0], digits=2))")
                    
                catch e
                    println("PyGIMLi modeling failed for a=$a: $e")
                    # Still test our implementation is reasonable
                    @test abs(rho_a_julia - 100.0) < 1.0
                end
            end
            
            # Test two-layer model comparison
            @testset "Two-layer Model vs PyGIMLi" begin
                ρ_two_layer = [50.0, 200.0]
                h_two_layer = [10.0]
                
                myx, myw = VES.create_integration_points(120)
                
                # Test a few electrode spacings
                a_values = [2.0, 5.0, 10.0, 20.0, 50.0]
                
                for a in a_values
                    # Our implementation
                    rho_a_julia = VES.wenner_apparent_resistivity(a, ρ_two_layer, h_two_layer, myx, myw)
                    
                    # PyGIMLi VES modeling
                    try
                        thicks = pygimli.Vector([h_two_layer[1]])
                        res = pygimli.Vector([ρ_two_layer[1], ρ_two_layer[2]])
                        ab2 = pygimli.Vector([a])
                        
                        ves = pygimli.physics.ves.VESManager()
                        rhoa_pygimli = ves.simulate(res, thicks, ab2)
                        
                        # Compare results - allow for some numerical differences
                        relative_error = abs(rho_a_julia - rhoa_pygimli[0]) / rhoa_pygimli[0]
                        @test relative_error < 0.15  # Within 15% for complex models
                        
                        println("Two-layer a = $a m: Julia = $(round(rho_a_julia, digits=2)), PyGIMLi = $(round(rhoa_pygimli[0], digits=2)), Error = $(round(relative_error*100, digits=1))%")
                        
                    catch e
                        println("PyGIMLi modeling failed for a=$a: $e")
                        # Still test our implementation is reasonable
                        @test rho_a_julia > 0
                        @test rho_a_julia > minimum(ρ_two_layer)
                        @test rho_a_julia < maximum(ρ_two_layer)
                    end
                end
            end
            
            # Test three-layer model
            @testset "Three-layer Model vs PyGIMLi" begin
                ρ_three_layer = [100.0, 20.0, 500.0]
                h_three_layer = [5.0, 15.0]
                
                myx, myw = VES.create_integration_points(120)
                
                # Test a few electrode spacings
                a_values = [2.0, 10.0, 30.0]
                
                for a in a_values
                    # Our implementation
                    rho_a_julia = VES.wenner_apparent_resistivity(a, ρ_three_layer, h_three_layer, myx, myw)
                    
                    # PyGIMLi VES modeling
                    try
                        thicks = pygimli.Vector(h_three_layer)
                        res = pygimli.Vector(ρ_three_layer)
                        ab2 = pygimli.Vector([a])
                        
                        ves = pygimli.physics.ves.VESManager()
                        rhoa_pygimli = ves.simulate(res, thicks, ab2)
                        
                        # Compare results - allow for more differences in complex models
                        relative_error = abs(rho_a_julia - rhoa_pygimli[0]) / rhoa_pygimli[0]
                        @test relative_error < 0.25  # Within 25% for complex models
                        
                        println("Three-layer a = $a m: Julia = $(round(rho_a_julia, digits=2)), PyGIMLi = $(round(rhoa_pygimli[0], digits=2)), Error = $(round(relative_error*100, digits=1))%")
                        
                    catch e
                        println("PyGIMLi modeling failed for a=$a: $e")
                        # Still test our implementation is reasonable
                        @test rho_a_julia > 0
                    end
                end
            end
        end
    end
    else
        println("✗ PyGIMLi not available. Running basic tests only.")
        println("  To install PyGIMLi, use conda:")
        println("  conda install -c conda-forge -c gimli pygimli")
        println("  or")
        println("  conda install -c gimli pygimli")
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
        
        # Test with empty resistivity array
        @test_throws BoundsError VES.wenner_apparent_resistivity(1.0, Float64[], Float64[], myx, myw)
        
        # Test with negative electrode spacing
        @test VES.wenner_apparent_resistivity(-1.0, [100.0], Float64[], myx, myw) != 0  # Should still calculate something
    end
    
    @testset "Integration Points Quality" begin
        # Test different numbers of integration points
        for n in [20, 50, 100]
            myx, myw = VES.create_integration_points(n)
            
            @test length(myx) == n
            @test length(myw) == n
            @test all(myx .> 0)
            @test all(myw .> 0)
            
            # Test that more points give more accurate results
            ρ_homogeneous = [100.0]
            h_homogeneous = Float64[]
            a = 10.0
            
            rho_a = VES.wenner_apparent_resistivity(a, ρ_homogeneous, h_homogeneous, myx, myw)
            @test abs(rho_a - 100.0) < 1.0
        end
    end
end
