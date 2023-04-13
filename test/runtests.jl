using SafeTestsets, Test, Pkg
using Trace

if true
    @safetestset "Trace function generation" begin 
        include("trace_function_generation.jl") 
    end

    @safetestset "Trace itself" begin 
        include("trace_itself.jl") 
    end
end
