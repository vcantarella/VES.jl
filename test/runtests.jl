using VES
using Test

@testset "VES.jl" begin
    # Include analytical VES tests
    include("test_analytical_ves.jl")
    
    # Include PyGIMLi tests with CondaPkg (if available)
    try
        include("test_pygimli_condapkg.jl")
    catch e
        println("CondaPkg/PythonCall not available, skipping PyGIMLi integration tests: $e")
    end
end
