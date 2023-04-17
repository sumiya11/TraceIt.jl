using SafeTestsets, Test, Pkg
using TraceIt

if true
    @safetestset "TraceIt function generation" begin 
        include("trace_function_generation.jl") 
    end

    # @safetestset "TraceIt itself" begin 
    #     include("trace_itself.jl")
    # end
end
