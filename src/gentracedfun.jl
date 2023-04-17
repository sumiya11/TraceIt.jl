
"""
    gentracedfun(f, name, args, _where, key, world, trace)

Returns an expression that contains the definition of a function with name `name`,
arguments `args`, the where part `_where`. 

The generated function is supposed to do the same things as `f` 
and be "traced" if `trace` is set.
"""
function gentracedfun(f, name, args, _where, key, world, trace)
    sig = gensig(name, args, _where)
    body = genbody(f, name, args, key, world, trace)
    e = Expr(:function)
    e.args = [sig, body]
    e
end

"""
    getmetainfo(m::Base.Method)

Get the name, the "where {T}" part, and the arguments of `m`.
"""
function getmetainfo(m::Base.Method)
    ts, args::Vector{Tuple{String, String}}, _, _ = Base.arg_decl_parts(m)
    # arguments with empty names get a gensym() as a new name 
    args = map(a -> isempty(first(a)) ? (string(gensym()), last(a)) : a, args)
    # arguments with empty type declaration get Any as a new type 
    args = map(a -> isempty(last(a)) ? (first(a), "Any") : a, args)
    m.name, ts, args[2:end]
end

"""
    gensig(name, args, _where)

Generates the signature of a traced function.
"""
function gensig(name, args, _where)
    sig = gensig(name, args)
    if !isnothing(_where)
        args = map(Meta.parse ∘ string, _where)
        args = [sig, args...]
        sig = Expr(:where)
        sig.args = args
    end
    sig
end
function gensig(name, args)
    e = Expr(:call)
    e.args = Any[name]
    for aT in args
        a, T = aT
        # if no type declaration
        if T === ""
            push!(e.args, Symbol(a))
        elseif a === ""
            push!(e.args, Expr(:(::), Meta.parse(string(T))))
        else
            push!(e.args, Expr(:(::), Symbol(a), Meta.parse(string(T))))
        end
    end
    e
end

function getargnames(args)
    argnames = map(
        a -> Symbol(first(a)), 
        args
    )
    argnames
end

@noinline function genbodytrace(f, name, args, key, primary_world)
    argnames = getargnames(args)
    e = quote
        stat = @timed res = Base.invoke_in_world($primary_world, $f, $(argnames...))
        invoked, time, alloc, gctime = $_record_table[$key]
        $_record_table[$key] = (
            invoked + 1, 
            time + stat.time, 
            alloc + stat.bytes, 
            gctime + stat.gctime
        )
        return res
    end
    e
end
@noinline function genbodyuntrace(f, name, args, key, primary_world)
    argnames = getargnames(args)
    e = quote
        res = Base.invoke_in_world($primary_world, $f, $(argnames...))
        return res
    end
    e
end

"""
    genbody(f, name, args, key, primary_world, trace)

Returns an expression that contains the body of the generated traced function.
"""
function genbody(f, name, args, key, primary_world, trace)
    if trace
        e = genbodytrace(f, name, args, key, primary_world)
    else
        e = genbodyuntrace(f, name, args, key, primary_world)
    end
    e
end
