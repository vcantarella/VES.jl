using Test
using VES

# Test configuration - install and test PyGIMLi using CondaPkg
# Only attempt if CondaPkg and PythonCall are available (test-only dependencies)
const PYGIMLI_AVAILABLE = begin
    try
        
        # Force PythonCall to use the pixi environment Python
        pixi_python = joinpath(pwd(), "test", "test_ves", ".pixi", "envs", "default", "bin", "python")
        
        if !isfile(pixi_python)
            error("Python executable not found in pixi environment: $pixi_python")
        end
        
        # Set PythonCall configuration to use pixi Python
        ENV["JULIA_CONDAPKG_BACKEND"] = "Null"
        ENV["JULIA_PYTHONCALL_EXE"] = pixi_python # optional
        
        # Try to load test-only dependencies
        @eval using PythonCall
        
        # Check if PyGIMLi is available through pixi environment
        println("Checking PyGIMLi availability in pixi environment...")
        
        # Test Python and PyGIMLi availability
        pyexec("import sys; print(f'Using Python: {sys.executable}')", Main)
        pyexec("import pygimli; print(f'PyGIMLi version: {pygimli.__version__}')", Main)

        println("✓ PyGIMLi pixi environment set up successfully")
        println("Note: PyGIMLi import will be tested separately to avoid memory issues")
        true
    catch e
        error_str = string(e)
        println("✗ PyGIMLi setup failed: $e")
        println("Make sure to activate the pixi environment with 'pixi shell -C test/test_ves' before running tests")
        println("Running basic tests only.")
        false
    end
end

@testset "VES Analytical Tests with CondaPkg" begin
    
    if PYGIMLI_AVAILABLE
        @testset "PyGIMLi Comparison Tests" begin

            pygimli = pyimport("pygimli")
            VESManager = pygimli.physics.VESManager
            
            # Only run comparison tests if PyGIMLi import succeeded
            # Test homogeneous half-space comparison
            @testset "Homogeneous Half-space vs PyGIMLi" begin
                ρ_homogeneous = [100.0]
                h_homogeneous = Float64[]
                
                myx, myw = VES.create_integration_points(120)
                
                # Test multiple electrode spacings
                a_values = [1.0, 2.0, 5.0, 10.0, 20.0]
                ab2 = a_values*3/2  # AB/2 distances for Wenner (a is the electrode spacing)
                mn2 = a_values/2

                ves = VESManager()

                # For homogeneous half-space, use a very thick layer
                thicks = [1000.0]  # Very thick layer
                res = [ρ_homogeneous[1], ρ_homogeneous[1]]  # Same resistivity

                synthmodel = pygimli.Vector(vcat(res, thicks))

                rhoa_pygimli, err_pygimli = ves.simulate(
                    synthmodel,
                    ab2 = pygimli.Vector(ab2),
                    mn2 = pygimli.Vector(mn2),
                    noiseLevel=0.01, seed=1337
                )

                # convert to julia object
                rhoa_pygimli = pyconvert(Array, rhoa_pygimli)

                # Our implementation
                rho_a_julia = VES.wenner_apparent_resistivity.(a_values, Ref(ρ_homogeneous), Ref(h_homogeneous), Ref(myx), Ref(myw))
                # compare with PyGIMLi
                for (i, a) in enumerate(a_values)
                    relative_error = abs(rho_a_julia[i] - rhoa_pygimli[i]) / rhoa_pygimli[i]
                    @test relative_error < 0.05  # Within 5% for homogeneous half-space
                    println("Homogeneous a = $a m: Julia = $(round(rho_a_julia[i], digits=2)), PyGIMLi = $(round(rhoa_pygimli[i], digits=2)), Error = $(round(relative_error*100, digits=1))%")
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
                    thicks = pygimli.Vector([h_two_layer[1]])
                    res = pygimli.Vector([ρ_two_layer[1], ρ_two_layer[2]])
                    ab2 = pygimli.Vector([a*3/2])
                    mn2 = pygimli.Vector([a/2])

                    synthmodel = vcat(ρ_two_layer,h_two_layer)
                    
                    ves = pygimli.physics.ves.VESManager()
                    rhoa_pygimli, err_pygimli = ves.simulate(
                        synthmodel,
                        ab2 = pygimli.Vector(ab2),
                        mn2 = pygimli.Vector(mn2),
                        noiseLevel=0.01, seed=1337
                    )
                    # Compare results - allow for some numerical differences
                    rhoa_pygimli_res = pyconvert(Float64, rhoa_pygimli[0])
                    relative_error = abs(rho_a_julia - rhoa_pygimli_res) / rhoa_pygimli_res
                    @test relative_error < 0.15 # Within 15% for complex models

                    println("Two-layer a = $a m: Julia = $(round(rho_a_julia, digits=2)), PyGIMLi = $(round(rhoa_pygimli[0], digits=2)), Error = $(round(relative_error*100, digits=1))%")
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
                    thicks = pygimli.Vector(h_three_layer)
                    res = pygimli.Vector(ρ_three_layer)
                    ab2 = pygimli.Vector([a*3/2])
                    mn2 = pygimli.Vector([a/2])
                    
                    
                    ves = pygimli.physics.ves.VESManager()
                    synthmodel = vcat(ρ_three_layer,h_three_layer)
                    rhoa_pygimli = ves.simulate(synthmodel, ab2, mn2)
                    rhoa_pygimli_res = pyconvert(Float64, rhoa_pygimli[0])

                    # Compare results - allow for more differences in complex models
                    relative_error = abs(rho_a_julia - rhoa_pygimli_res) / rhoa_pygimli_res
                    @test relative_error < 0.25  # Within 25% for complex models

                    println("Three-layer a = $a m: Julia = $(round(rho_a_julia, digits=2)), PyGIMLi = $(round(rhoa_pygimli[0], digits=2)), Error = $(round(relative_error*100, digits=1))%")
                end
            end
        end
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
