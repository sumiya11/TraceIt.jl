module TraceIt

@doc read(joinpath(dirname(@__DIR__), "README.md"), String) TraceIt

# Generate definitions of traced functions 
include("gentracedfun.jl")

# Method signature --> primary world
const _method_table = Dict()
# Method signature --> collected statistics 
const _record_table = Dict()
# Method key in the tables
methodkey(name, args) = (name, map(last, args))

"""
    trace(f)

Registers function `f` for tracing.
"""
function trace(f; primary_world=Base.get_world_counter())
    # Redefines each non-ambiguous method of f by evaluating f
    # in the scope of the parent module and keeping the original signature.
    mod = parentmodule(f)
    ms = collect(methods(f))
    @info "Tracing all ($(length(ms))) methods of $mod.$f"
    @assert all(m -> m.primary_world <= primary_world, ms)
    something_went_wrong = false
    for m in ms
        name, types, args = getmetainfo(m)
        key = methodkey(name, args)
        tracedfun = gentracedfun(f, name, args, types, key, primary_world, true)
        try 
            @eval mod $tracedfun
            _record_table[key] = (invoked=0, time=0.0, alloc=0, gctime=0.0)
            _method_table[key] = (primary_world=primary_world,)
        catch e
            # ignore it for now
            something_went_wrong = true 
        end
    end
    something_went_wrong && (@warn "Unable to trace some of the methods of $f")
    nothing
end

"""
    untrace(f)

Removes the tracing of function `f`.
"""
function untrace(f)
    # Reverts the definition of f for all existing methods
    # using the primary world stored in _method_table
    mod = parentmodule(f)
    ms = collect(methods(f))
    @info "Un-tracing all ($(length(ms))) methods of $mod.$f"
    for m in ms
        name, types, args = getmetainfo(m)
        key = methodkey(name, args)
        if !haskey(_method_table, key)
            @warn "Method $name, $args was not traced, skipping it"
            continue
        end
        primary_world = _method_table[key].primary_world 
        delete!(_record_table, key)
        delete!(_method_table, key)
        untracedfun = gentracedfun(f, name, args, types, key, primary_world, false)
        @eval mod $untracedfun
    end
    nothing
end

# Partially adapted from NamedArrays.jl, the license is MIT
leftalign(s, l) = rpad(s, l, " ")
rightalign(s, l) = lpad(s, l, " ")
sprint_colpart(widths::Vector{Int}, s::Vector) = join(map((width, s)->lpad(s, width, " "), widths, s), "  ")
function sprintrow(namewidth::Int, name, widths::Vector{Int}, names; sep=" │ ")
    s = string(leftalign(name, namewidth), sep, sprint_colpart(widths, names))
    s
end

"""
    printtrace(io::IO=stdout)

Prints statistics collected from the traced functions to `io`.
"""
function printtrace(io::IO=stdout)
    # Group records by function name
    rownames = unique(map(string ∘ first, collect(keys(_record_table))))
    colnames = ["called", "mem, b", "gctime, s", "time, s", "time, %"]
    coltypes = [Int, Int, Float64, Float64, Float64]
    perm = [1, 3, 4, 2]
    m, n = length(rownames), length(colnames)
    rows = map(_ -> Vector{Any}(undef, n), 1:m)    
    for (key, val) in _record_table
        rowidx = findfirst(==(string(first(key))), rownames)
        !isassigned(rows[rowidx], 1) && (rows[rowidx] = [zero(T) for T in coltypes])
        for i in 1:n-1
            rows[rowidx][i] += val[perm[i]]
        end
    end
    for (key, _) in _record_table
        _record_table[key] = (invoked=0, time=0.0, alloc=0, gctime=0.0)
    end
    lastrow = map(i -> sum(row -> row[i],  rows; init=zero(coltypes[i])), 1:n)
    lastrow[end] = 1.0
    for row in rows
        row[end] = row[end-1] / lastrow[end-1]
    end
    sortp = sort(collect(1:m), by=i -> -rows[i][end])
    rows = rows[sortp]
    rownames = rownames[sortp]
    strrows = Vector{Vector{String}}(undef, m)
    maxlens = zeros(Int, n)
    function make_strings_row(row)
        a,b,c,d,e = row
        [
            string(a), string(b), 
            string(round(c, digits=9)), 
            string(round(d, digits=9)),
            string(round(100*e, digits=2))*" %"
        ]
    end
    for i in eachindex(rows)
        row = rows[i]
        strrows[i] = make_strings_row(row)
        maxlens = max.(maxlens, map(length, strrows[i]))
    end
    corner = "func. ╲ stat."
    strlastrow = make_strings_row(lastrow)
    maxlens = max.(maxlens, map(length, strlastrow))
    colwidths = max.(maxlens, map(length, colnames))
    rownamewidth = max(1, max(length(corner), maximum(map(length, rownames); init=0)))
    header = sprintrow(rownamewidth, rightalign("Func. ╲ Stat.", rownamewidth), colwidths, colnames)
    # feature(Alex): also return the array with statistics?
    println(io, header)
    println(io, "─"^(rownamewidth+1), "┼", "─"^(length(header)-rownamewidth-2))
    for (name, strrow) in zip(rownames, strrows)
        println(io, sprintrow(rownamewidth, name, colwidths, strrow))
    end
    println(io, "─"^(rownamewidth+1), "┼", "─"^(length(header)-rownamewidth-2))
    println(io, sprintrow(rownamewidth, "Σ", colwidths, strlastrow))
    nothing
end

export trace, untrace, printtrace

# Convenience macro @trace and @untrace
include("macro.jl")
export @trace, @untrace

# Pure madness
include("madness.jl")

end
