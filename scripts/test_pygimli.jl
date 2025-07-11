#!/usr/bin/env julia

# Quick script to test PyGIMLi availability and provide installation guidance

println("VES.jl PyGIMLi Integration Test")
println("=" ^ 40)

# Test if PyCall is available
try
    using PyCall
    println("✓ PyCall.jl is available")
    
    # Get Python info
    println("Python executable: ", PyCall.python)
    println("Python version: ", PyCall.pyversion)
    
    # Test PyGIMLi import
    try
        pg = pyimport("pygimli")
        println("✓ PyGIMLi is available!")
        println("PyGIMLi version: ", pg.__version__)
        
        # Test basic functionality
        try
            # Create a simple test
            thicks = pg.Vector([10.0])
            res = pg.Vector([100.0, 200.0])
            ab2 = pg.Vector([5.0, 10.0, 20.0])
            
            ves = pg.physics.ves.VESManager()
            rhoa = ves.simulate(res, thicks, ab2)
            
            println("✓ PyGIMLi VES modeling works!")
            println("Test apparent resistivities: ", [round(x, digits=2) for x in rhoa])
            
        catch e
            println("⚠ PyGIMLi imported but VES modeling failed: ", e)
            println("This might indicate an incomplete installation.")
        end
        
    catch e
        println("✗ PyGIMLi not available: ", e)
        println()
        println("To install PyGIMLi, use conda:")
        println("  conda install -c conda-forge -c gimli pygimli")
        println("  or")
        println("  conda install -c gimli pygimli")
        println()
        println("Note: PyGIMLi is NOT available via pip - conda is required.")
        println()
        println("If you don't have conda, install Miniconda first:")
        println("  https://docs.conda.io/en/latest/miniconda.html")
    end
    
catch e
    println("✗ PyCall.jl not available: ", e)
    println("This shouldn't happen in the test environment.")
end

println()
println("VES.jl will work perfectly without PyGIMLi.")
println("PyGIMLi integration is optional and only used for validation.")
