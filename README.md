# TraceIt.jl

The goal is to trace functions with minimal overhead and no modifications to the source code.

The package is a *prototype for demonstration purposes*, use at your own risk *(e.g., attempting to trace `Base.:+` will likely crash Julia).*

### Example

```julia
using TraceIt

@trace Base.sum; @trace Base.log

reduce(log, map(sum, [[1, 2, 3], [4, 5], [6]]))

# mostly compile time on the first run:
printtrace()
Func. ╲ Stat. │ called  mem, b  gctime, s    time, s  time, %
──────────────┼──────────────────────────────────────────────
sum           │      3   12272        0.0  0.0102889  54.94 %
log           │      2  138281        0.0  0.0084373  45.06 %
──────────────┼──────────────────────────────────────────────
Σ             │      5  150553        0.0  0.0187262  100.0 %
```

### The implementation

The tracing is implemented with the use of `Base.invoke_in_world`, in the following way. 

Say, there is function `foo` to be traced in `Foo`:

```julia
module Foo
    foo(x) = x
end
```

Tracing is done by *(somewhere inside `@trace Foo.foo`)*:

```julia
primary_world = Base.get_world_counter()
@eval Foo function foo(x)
    #=  record some statistics globally  =#
    @info "foo is now traced!"
    return Base.invoke_in_world($primary_world, foo, x)
end
```

Un-tracing *(somewhere inside `@untrace Foo.foo`)*:

```julia
@eval Foo function foo(x)
    return Base.invoke_in_world($primary_world, foo, x)
end
```
