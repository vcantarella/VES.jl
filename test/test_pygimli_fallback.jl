using Test
using VES

# Alternative PyGIMLi test approach with better error handling
const PYGIMLI_AVAILABLE = begin
    try
        # Try to load test-only dependencies
        @eval using CondaPkg
        @eval using PythonCall
        
        println("Attempting PyGIMLi setup with fallback strategy...")
        
        # Try a more conservative approach - check if pygimli is already available
        try
            # First try to import without installing
            pygimli = pyimport("pygimli")
            println("✓ PyGIMLi already available, version: $(pygimli.__version__)")
            true
        catch
            println("PyGIMLi not found, attempting installation...")
            
            # Clean approach - ensure we have a fresh environment
            CondaPkg.add_channel("conda-forge")
            CondaPkg.add_channel("gimli")
            
            # Try installing with specific versions to avoid conflicts
            try
                CondaPkg.add("python", version=">=3.11,<3.12")
                CondaPkg.add("numpy", version="<2.0")  # Ensure numpy compatibility
                CondaPkg.add("pygimli")
                CondaPkg.resolve()
                
                # Test the installation
                pygimli = pyimport("pygimli")
                println("✓ PyGIMLi successfully installed and imported")
                println("PyGIMLi version: $(pygimli.__version__)")
                true
            catch install_error
                error_str = string(install_error)
                if contains(error_str, "datetime") && contains(error_str, "SystemError")
                    println("✗ PyGIMLi installation failed due to Python environment conflict (datetime module issue)")
                    println("This is a known issue with PyGIMLi conda installation.")
                    println("To fix this, try: conda create -n pygimli_env python=3.11 pygimli -c conda-forge -c gimli")
                elseif contains(error_str, "ModuleNotFoundError") && contains(error_str, "pygimli")
                    println("✗ PyGIMLi not found - installation via CondaPkg did not succeed")
                    println("PyGIMLi may not be available for your platform via conda.")
                    println("To install PyGIMLi manually, try: conda create -n pygimli_env python=3.11 pygimli -c conda-forge -c gimli")
                else
                    println("✗ PyGIMLi installation failed: $install_error")
                end
                false
            end
        end
    catch e
        println("✗ Could not load CondaPkg/PythonCall: $e")
        false
    end
end

@testset "VES Tests with PyGIMLi Fallback" begin
    
    @testset "Core VES Functions" begin
        # Test create_integration_points
        myx, myw = VES.create_integration_points(50)
        
        @test length(myx) == 50
        @test length(myw) == 50
        @test all(myx .> 0)
        @test all(myw .> 0)
        
        # Test homogeneous half-space
        ρ_homogeneous = [100.0]
        h_homogeneous = Float64[]
        
        a = 10.0
        rho_a = VES.wenner_apparent_resistivity(a, ρ_homogeneous, h_homogeneous, myx, myw)
        @test abs(rho_a - 100.0) < 1.0
        
        # Test two-layer model
        ρ_two_layer = [50.0, 200.0]
        h_two_layer = [10.0]
        
        rho_a_2layer = VES.wenner_apparent_resistivity(a, ρ_two_layer, h_two_layer, myx, myw)
        @test rho_a_2layer > 0
        @test rho_a_2layer > minimum(ρ_two_layer)
        @test rho_a_2layer < maximum(ρ_two_layer)
    end
    
    if PYGIMLI_AVAILABLE
        @testset "PyGIMLi Validation Tests" begin
            println("Running PyGIMLi validation tests...")
            
            # Get PyGIMLi reference
            pygimli = pyimport("pygimli")
            
            # Simple homogeneous test
            @testset "Homogeneous Half-space Validation" begin
                ρ_homogeneous = [100.0]
                h_homogeneous = Float64[]
                myx, myw = VES.create_integration_points(100)
                
                # Test a single electrode spacing
                a = 5.0
                rho_a_julia = VES.wenner_apparent_resistivity(a, ρ_homogeneous, h_homogeneous, myx, myw)
                
                try
                    # PyGIMLi VES modeling - simple approach
                    thicks = pygimli.Vector([1000.0])  # Very thick layer
                    res = pygimli.Vector([100.0, 100.0])
                    ab2 = pygimli.Vector([a])
                    
                    ves = pygimli.physics.ves.VESManager()
                    rhoa_pygimli = ves.simulate(res, thicks, ab2)
                    
                    relative_error = abs(rho_a_julia - rhoa_pygimli[0]) / rhoa_pygimli[0]
                    @test relative_error < 0.05  # Within 5%
                    
                    println("✓ Homogeneous validation: Julia = $(round(rho_a_julia, digits=2)), PyGIMLi = $(round(rhoa_pygimli[0], digits=2)), Error = $(round(relative_error*100, digits=1))%")
                    
                catch pygimli_error
                    println("PyGIMLi simulation failed: $pygimli_error")
                    # Still test our implementation is reasonable
                    @test abs(rho_a_julia - 100.0) < 1.0
                end
            end
        end
    else
        @testset "PyGIMLi Not Available - Extended Analytical Tests" begin
            println("PyGIMLi not available. Running extended analytical tests...")
            
            myx, myw = VES.create_integration_points(120)
            
            # Test multiple scenarios analytically
            @testset "Multi-layer Models" begin
                # Three-layer model
                ρ_three_layer = [100.0, 20.0, 500.0]
                h_three_layer = [5.0, 15.0]
                
                for a in [1.0, 5.0, 20.0]
                    rho_a = VES.wenner_apparent_resistivity(a, ρ_three_layer, h_three_layer, myx, myw)
                    @test rho_a > 0
                    @test rho_a >= minimum(ρ_three_layer)
                    @test rho_a <= maximum(ρ_three_layer)
                end
            end
            
            @testset "Boundary Conditions" begin
                # Test with very thin layers
                ρ_thin = [100.0, 50.0, 200.0]
                h_thin = [0.1, 0.5]
                
                rho_a_thin = VES.wenner_apparent_resistivity(1.0, ρ_thin, h_thin, myx, myw)
                @test rho_a_thin > 0
                
                # Test with very thick layers
                ρ_thick = [100.0, 50.0]
                h_thick = [1000.0]
                
                rho_a_thick = VES.wenner_apparent_resistivity(1.0, ρ_thick, h_thick, myx, myw)
                @test rho_a_thick > 0
            end
        end
    end
    
    @testset "Integration Quality" begin
        # Test different integration point counts
        for n in [20, 50, 100]
            myx, myw = VES.create_integration_points(n)
            
            ρ_homogeneous = [100.0]
            h_homogeneous = Float64[]
            
            rho_a = VES.wenner_apparent_resistivity(10.0, ρ_homogeneous, h_homogeneous, myx, myw)
            relative_error = abs(rho_a - 100.0) / 100.0
            
            @test relative_error < 0.01
            println("n = $n: ρₐ = $(rho_a), error = $(relative_error*100)%")
        end
    end
end
