
"""
    getallargs(m::Base.Method)

"""
function getallargs(m::Base.Method)
    ts, args::Vector{Tuple{String, String}}, _, _ = Base.arg_decl_parts(m)
    kwargs = Base.kwarg_decl(m)
    # Discover default values for keyword args 
    # nkwargs = length(kwargs)
    # Base.uncompressed_ir(m).code[1]
    args = map(a -> isempty(first(a)) ? (string(gensym()), last(a)) : a, args)
    args = map(a -> isempty(last(a)) ? (first(a), "Any") : a, args)
    m.name, ts, args[2:end]
end

"""
    getsigstr(name, args::Vector{Tuple{String, String}}, ts)

"""
function getsigstr(name, args::Vector{Tuple{String, String}}, ts)
    in_parentheses = join(map(a -> join(a, "::"), args), ", ")
    in_where = "$(join(ts, ","))"
    Meta.parse(in_parentheses), Meta.parse(in_where)
end

"""
    gensig(name, args, kwargs, _where)

"""
function gensig(name, args, kwargs, _where)
    sig = gensig(name, args, kwargs)
    if !isnothing(_where)
        args = map(Meta.parse ∘ string, _where)
        args = [sig, args...]
        sig = Expr(:where)
        sig.args = args
    end
    sig
end
function gensig(name, args, kwargs)
    @assert isnothing(kwargs)
    gensig(name, args)
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
    genbody(name, args, primary_world, trace)
"""
function genbody(f, name, args, key, primary_world, trace)
    if trace
        e = genbodytrace(f, name, args, key, primary_world)
    else
        e = genbodyuntrace(f, name, args, key, primary_world)
    end
    e
end

"""
    genfun()
"""
function genfun(f, name, args, kwargs, _where, key, world, trace)
    sig = gensig(name, args, kwargs, _where)
    @info "" sig
    body = genbody(f, name, args, key, world, trace)
    e = Expr(:function)
    e.args = [sig, body]
    e
end
