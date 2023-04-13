using Test
# using Trace

# Test that the generated trace functions preserve the general functionality

module Test1
    using Test
    function test0()
        rand()
    end
    function run_test_0()
        @test length(methods(test0)) == 1
        @test 0 ≤ test0() ≤ 1
    end

    function test1(a, b::Int)
        a + b
    end
    function test1(a::Int)
        a
    end
    function run_test_1()
        @test length(methods(test1)) == 2
        @test test1(1, 2) === 3
        @test test1(1.0, 2) === 3.0
        @test test1(7) === 7
    end

    function test2(a, b=nothing)
        if b === nothing
            test2(a + 1)
        else
            test2(a + 2)
        end
    end
    function test2(a)
        a^2
    end
    function run_test_2()
        @test length(methods(test2)) == 2
        @test test2(4) === 16
        @test test2(4, nothing) === 25
        @test test2(4, 0) === 36
    end

    const i32 = Int32
    const i16 = Int16
    const i8  = Int8
    function test3(a::i32, b::i8)
        a + b
    end
    function test3(a::i8, b::i16)
        a + b
    end
    function test3(a::i8, b::i8)
        test3(convert(i8, a), convert(i16, b))
    end
    function run_test_3()
        @test length(methods(test3)) == 3
        @test test3(i32(1), i8(2)) === i32(3)
        @test test3(i8(2), i16(3)) === i16(5)
        @test test3(i8(11), i8(1)) === i16(12)
    end

    function test4(a, b, c::T, d::Y=2) where {T<:Unsigned, Y<:Signed}
        a + c + d
    end
    function run_test_4()
        @test length(methods(test4)) == 2
        @test test4(1, 2, UInt(3), 4) === UInt(8)
        @test test4(1, 2, UInt(3)) === UInt(6)
    end

    abstract type AbstractTest end
    struct AT1 <: AbstractTest end
    struct AT2 <: AbstractTest end
    function test5(
            a::Union{Nothing, Int}, b, c::T
        ) where {T<:AbstractTest}
        b
    end
    function test5(
            a::Union{Nothing, Int}, b::Vector{Int}, c::T
        ) where {T<:AbstractTest}
        sum(b)
    end
    function test5(
            a::Nothing, b, c::AT2
        )
        b^2
    end
    function run_test_5()
        @test length(methods(test5)) == 3
        @test test5(nothing, 2, AT1()) === 2
        @test test5(nothing, 2, AT1()) === 2
        @test test5(nothing, 2, AT2()) === 4
        @test_throws MethodError test5(nothing, [2, 3], AT2()) === 5
        @test test5(3, [2, 3], AT2()) === 5
        @test test5(nothing, [2, 3], AT1()) === 5
    end
end

for i in 0:5
    testi = Symbol(:test, i)
    run_test_i = Symbol(:run_test_, i)

    getproperty(Test1, run_test_i)()
    Trace.trace(getproperty(Test1, testi))
    getproperty(Test1, run_test_i)()
    Trace.untrace(getproperty(Test1, testi))
    getproperty(Test1, run_test_i)()
end

##############
# try a bit more sophisticated tests

# Function extension
module A
    function a(x)
        x
    end
end
module B
    import ..A
    function A.a(x::Int)
        x^2
    end
end
function run_test_0()
    @test A.a(2) === 4
    @test A.a(UInt(2)) === UInt(2)
end

begin
    run_test_0()
    Trace.trace(A.a)
    run_test_0()
    Trace.untrace(A.a)
    run_test_0()
end

# Generated functions
module C
    @generated function yy(x, y::T) where {T<:Signed}
        s = sizeof(T)
        :(
            x >> $s
        )
    end
end
function run_test_1()
    @test C.yy(8, Int8(0)) === 4
    @test C.yy(8, Int16(1)) === 2
    @test C.yy(8, Int32(2)) === 0
    @test C.yy(8, Int64(3)) === 0
    @test_throws MethodError C.yy(8, UInt32(4))
end

begin
    run_test_1()
    Trace.trace(C.yy)
    run_test_1()
    Trace.untrace(C.yy)
    run_test_1()
end

# Keyword arguments
module D
    function f0(x::Int; z = one(x))
        x + z
    end
    function f0(x::UInt; ω = zero(x))
        x + ω
    end
    function f0(x::Vector{T}; w=one(T)) where {T}
        x .+ w
    end
    function f1(; z = [[1, 2], [3]])
        vcat(z...)
    end
end
function run_test_2()
    @test D.f0(2) === 3
    @test D.f0(UInt(2)) === UInt(2)
    @test D.f0(UInt(2), ω=UInt(3)) === UInt(5)
    @test D.f0([2, 3]) == [3, 4]
    @test D.f0([2, 3], w=8) == [10, 11]

    @test D.f1() == [1, 2, 3]
    @test D.f1(z=[[1, 3], [2]]) == [1, 3, 2]
end

begin
    run_test_2()
    Trace.trace(D.f0); Trace.trace(D.f1)
    run_test_2()
    Trace.untrace(D.f0); Trace.untrace(D.f1)
    run_test_2() 
end

# Empty argnames (non-unique argument name)
module O1
    using Test
    function f(::Int, ::Any)
        1
    end
    function f(::Any, ::Any)
        2
    end
    function run_test_0()
        @test f(1, "") === 1
        @test f("", 2) === 2
    end
end
begin
    O1.run_test_0()
    Trace.trace(O1.f)
    O1.run_test_0()
    Trace.untrace(O1.f)
    O1.run_test_0() 
end

# Types from other libs
module X1
    import Random
    function f4(x, y::Random.MersenneTwister=Random.MersenneTwister())
        x + rand(y)
    end
    function f5(y::Random.MersenneTwister)
        rand(y)
    end
    function use_f5()
        y = Random.MersenneTwister()
        f5(y)
    end
    import Random: Xoshiro
    function f6(y::Xoshiro)
        rand(y)
    end
    function use_f6()
        y = Xoshiro()
        f6(y)
    end
end
function run_test_5()
    @test 0.5 ≤ X1.f4(1.5) ≤ 2.5
    @test 0.0 ≤ X1.use_f5() ≤ 1.0
    @test 0.0 ≤ X1.use_f6() ≤ 1.0
end

begin
    run_test_5()
    Trace.trace(X1.f4)
    run_test_5()
    Trace.untrace(X1.f4)
    run_test_5() 
end

##############
# traceall tests

module Test8
    function initialize(n)
        ones(Int, n)
    end
    function compute_this_thing(mem, i)
        s = 0
        for i_ in 1:i
            for j_ in i_:i
                s += mem[i_] + mem[j_]
            end
        end
        s
    end
    function beautifuly(mem)
        map(x -> x^2, mem)
    end
    function do_work(n)
        mem = initialize(n)
        for i in 1:n
            mem[i] = compute_this_thing(mem, i)
        end
        beautifuly(mem)
    end
end
function run_test_8()
    n = 3
    @test Test8.do_work(n) == [4, 81, 2304]
end

begin
    run_test_8()
    Trace.traceall(Test8)
    run_test_8() 
    Trace.untraceall(Test8)
    run_test_8()
end
