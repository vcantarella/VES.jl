# PyGIMLi Comparison Script for VES.jl
# This script compares VES.jl results with PyGIMLi for validation

using VES

# Try to use CondaPkg for better conda integration
const USE_CONDAPKG = try
    using CondaPkg
    using PythonCall
    true
catch
    false
end

# Fallback to PyCall if CondaPkg is not available
if !USE_CONDAPKG
    try
        using PyCall
    catch
        println("Neither CondaPkg nor PyCall available. Cannot run PyGIMLi comparison.")
        exit(1)
    end
end

# Function to check if PyGIMLi is available and install if using CondaPkg
function check_pygimli()
    if USE_CONDAPKG
        try
            println("Using CondaPkg for PyGIMLi integration...")
            
            # Set up conda channels and install pygimli
            CondaPkg.add_channel("conda-forge")
            CondaPkg.add_channel("gimli")
            CondaPkg.add("pygimli")
            
            # Import using PythonCall
            pg = pyimport("pygimli")
            println("✓ PyGIMLi successfully installed and imported with CondaPkg")
            println("PyGIMLi version: $(pg.__version__)")
            return true, pg
        catch e
            println("✗ PyGIMLi installation/import failed with CondaPkg: $e")
            return false, nothing
        end
    else
        try
            pg = pyimport("pygimli")
            println("✓ PyGIMLi successfully imported with PyCall")
            println("PyGIMLi version: $(pg.__version__)")
            return true, pg
        catch e
            println("✗ PyGIMLi not available with PyCall: $e")
            println("Install PyGIMLi using conda:")
            println("  conda install -c conda-forge -c gimli pygimli")
            println("  or")
            println("  conda install -c gimli pygimli")
            println("")
            println("Note: PyGIMLi is not available via pip, only through conda.")
            return false, nothing
        end
    end
end

# Main comparison function with real PyGIMLi integration
function compare_with_pygimli()
    available, pg = check_pygimli()
    
    if !available
        println("Running VES.jl tests without PyGIMLi comparison...")
        return run_basic_tests()
    end
    
    println("Running VES.jl vs PyGIMLi comparison...")
    
    # Create integration points
    myx, myw = VES.create_integration_points(120)
    
    # Test cases with real PyGIMLi modeling
    test_cases = [
        ("Homogeneous", [100.0], Float64[], [2.0, 5.0, 10.0, 20.0]),
        ("Two-layer (high over low)", [100.0, 50.0], [10.0], [2.0, 5.0, 10.0, 20.0]),
        ("Two-layer (low over high)", [50.0, 200.0], [10.0], [2.0, 5.0, 10.0, 20.0]),
        ("Three-layer", [100.0, 20.0, 500.0], [5.0, 15.0], [2.0, 10.0, 30.0]),
    ]
    
    println("\n" * "="^80)
    println("VES.jl vs PyGIMLi Comparison Results")
    println("="^80)
    
    for (name, ρ, h, a_values) in test_cases
        println("\n$name:")
        println("Resistivities: $(join(ρ, ", ")) Ω·m")
        if !isempty(h)
            println("Thicknesses: $(join(h, ", ")) m")
        end
        
        println("\nSpacing (m) | VES.jl (Ω·m) | PyGIMLi (Ω·m) | Difference (%)")
        println("-----------|-------------|---------------|---------------")
        
        for a in a_values
            # Our implementation
            rho_julia = VES.wenner_apparent_resistivity(a, ρ, h, myx, myw)
            
            # PyGIMLi implementation
            try
                if length(ρ) == 1
                    # Homogeneous case - use very thick layer
                    thicks = pg.Vector([1000.0])
                    res = pg.Vector([ρ[1], ρ[1]])
                else
                    # Multi-layer case
                    thicks = pg.Vector(h)
                    res = pg.Vector(ρ)
                end
                
                ab2 = pg.Vector([a])
                
                ves = pg.physics.ves.VESManager()
                rhoa_pygimli = ves.simulate(res, thicks, ab2)
                
                rho_pygimli = rhoa_pygimli[0]
                
                # Calculate difference
                difference = abs(rho_julia - rho_pygimli) / rho_pygimli * 100
                
                println("$(lpad(string(a), 10)) | $(lpad(string(round(rho_julia, digits=2)), 11)) | $(lpad(string(round(rho_pygimli, digits=2)), 13)) | $(lpad(string(round(difference, digits=1)), 13))")
                
            catch e
                println("$(lpad(string(a), 10)) | $(lpad(string(round(rho_julia, digits=2)), 11)) | $(lpad("ERROR", 13)) | $(lpad("N/A", 13))")
                println("                     PyGIMLi error: $e")
            end
        end
    end
    
    return true
end

# Basic test without PyGIMLi
function run_basic_tests()
    println("\n" * "="^60)
    println("VES.jl Basic Functionality Tests")
    println("="^60)
    
    myx, myw = VES.create_integration_points(120)
    
    # Test homogeneous half-space
    println("\nHomogeneous Half-space Test (100 Ω·m):")
    ρ_homo = [100.0]
    h_homo = Float64[]
    
    a_values = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]
    
    println("Spacing (m) | Apparent ρ (Ω·m) | Error from 100 (%)")
    println("-----------|------------------|-------------------")
    
    for a in a_values
        rho_a = VES.wenner_apparent_resistivity(a, ρ_homo, h_homo, myx, myw)
        error = abs(rho_a - 100.0) / 100.0 * 100
        println("$(lpad(string(a), 10)) | $(lpad(string(round(rho_a, digits=2)), 16)) | $(lpad(string(round(error, digits=2)), 17))")
    end
    
    # Test two-layer model
    println("\nTwo-layer Test (50 Ω·m over 200 Ω·m, 10 m thick):")
    ρ_two = [50.0, 200.0]
    h_two = [10.0]
    
    println("Spacing (m) | Apparent ρ (Ω·m) | Trend")
    println("-----------|------------------|--------")
    
    rho_prev = 0.0
    for a in a_values
        rho_a = VES.wenner_apparent_resistivity(a, ρ_two, h_two, myx, myw)
        trend = if rho_prev == 0.0
            "start"
        elseif rho_a > rho_prev
            "↑"
        elseif rho_a < rho_prev
            "↓"
        else
            "="
        end
        println("$(lpad(string(a), 10)) | $(lpad(string(round(rho_a, digits=2)), 16)) | $(lpad(trend, 6))")
        rho_prev = rho_a
    end
    
    return true
end

# Run the comparison
if abspath(PROGRAM_FILE) == @__FILE__
    compare_with_pygimli()
end
