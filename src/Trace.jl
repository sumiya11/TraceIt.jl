module Trace

# 
include("genfun.jl")

const _method_table = Dict()
const _record_table = Dict()

methodkey(name, args) = (name, map(last, args))

function trace(f; primary_world=Base.get_world_counter())
    # Note(Alex): work out the case with extended functions
    mod = parentmodule(f)
    ms = collect(methods(f))
    @info "Tracing all ($(length(ms))) methods of $mod.$f"
    # Redefine each non-ambiguous method of f by evaluating f
    # in the scope of the parent module and keeping the original signature.
    # Just in case:
    @assert all(m -> m.primary_world <= primary_world, ms)
    for m in ms
        name, ts, args = getallargs(m)
        key = methodkey(name, args)
        # @info "" ts args key
        tracedfun = genfun(f, name, args, nothing, ts, key, primary_world, true)
        _record_table[key] = (invoked=0, time=0.0, alloc=0, gctime=0.0)
        _method_table[key] = (primary_world=primary_world,)
        @eval mod $tracedfun
    end
    nothing
end

"""

"""
function untrace(f)
    mod = parentmodule(f)
    ms = collect(methods(f))
    @info "Un-tracing all ($(length(ms))) methods of $mod.$f"
    # Revert the definition of f for all existing methods
    for m in ms
        name, ts, args = getallargs(m)
        key = methodkey(name, args)
        # @info "" ts args key
        if !haskey(_method_table, key)
            @warn "Method $name - $key was not traced, skipping it"
            continue
        end
        primary_world = _method_table[key].primary_world 
        delete!(_record_table, key)
        delete!(_method_table, key)
        untracedfun = genfun(f, name, args, nothing, ts, key, primary_world, false)
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

"""
function tprint(io::IO=stdout)
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
    # print stuff to io.
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

export trace, untrace, tprint

# Convenience macro @tr and @untr
include("macro.jl")
export @tr, @untr

# Pure madness
include("madness.jl")

end
