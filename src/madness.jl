# traceall(mod) -- trace all functions in a module mod at once

function skipname(mod, name, func)
    if name === :eval || name === :include
        return true
    end
    if name === mod
        return true
    end
    if !(func isa Function)
        return true
    end
    # skip macro
    if startswith(string(name), "@")
        return true
    end
    if length(methods(func)) == 0
        return true
    end
    return false
end

function traceall(mod)
    nm = names(mod, all=true)
    world = Base.get_world_counter()
    @info "Tracing all ($(length(nm))) functions in $mod"
    for n in nm
        f = getproperty(mod, n)
        skipname(Symbol(mod), n, f) && continue
        trace(f, primary_world=world)
    end
    nothing
end

function untraceall(mod)
    nm = names(mod, all=true)
    @info "Un-tracing all ($(length(nm))) functions in $mod"
    for n in nm
        f = getproperty(mod, n)
        skipname(Symbol(mod), n, f) && continue
        untrace(f)
    end
    nothing
end
