
"""
    @trace f

Registers function `f` for tracing.
"""
macro trace(expr)
    :(trace($(esc(expr))))
end

"""
    @untrace f

Removes the tracing of function `f`.
"""
macro untrace(expr)
    :(untrace($(esc(expr))))
end
