-- Optimization comparison: RETURN variants

-- Current approach: Single RETURN with runtime dispatch
local function RETURN_CURRENT(...)
  local exprs = {...}
  return function(cont, env, ...)
    if not env or type(env) ~= "table" or not env.__funcCont then
      error("RETURN outside of function")
    end
    
    local exitCont = env.__funcCont
    
    if #exprs == 0 then
      -- Runtime check: 0 args
      return exitCont(nil)
    else
      -- Runtime dispatch to evalArgs for 1+ args
      return evalArgs(exprs, function(...)
        return exitCont(...)
      end)
    end
  end
end

-- Optimized approach: Three specialized variants

local function RETURN0()
  return function(cont, env, ...)
    if not env or type(env) ~= "table" or not env.__funcCont then
      error("RETURN outside of function")
    end
    -- Direct return, no evaluation needed
    return env.__funcCont(nil)
  end
end

local function RETURN1(expr)
  return function(cont, env, ...)
    if not env or type(env) ~= "table" or not env.__funcCont then
      error("RETURN outside of function")
    end
    -- Evaluate single expression directly, no evalArgs overhead
    return expr, function(val)
      return env.__funcCont(val)
    end
  end
end

local function RETURN(...)
  local exprs = {...}
  return function(cont, env, ...)
    if not env or type(env) ~= "table" or not env.__funcCont then
      error("RETURN outside of function")
    end
    -- Use evalArgs for multiple values
    return evalArgs(exprs, function(...)
      return env.__funcCont(...)
    end)
  end
end

--[[
Optimization benefits:

1. RETURN0: 
   - Eliminates table creation {...}
   - Eliminates #exprs check
   - Direct call to exitCont
   
2. RETURN1:
   - Eliminates table creation
   - Eliminates #exprs check
   - Avoids evalArgs machinery (no iteration, no intermediate table)
   - Single direct evaluation + continuation
   
3. RETURN (variadic):
   - Only used when actually needed (2+ args)
   - No runtime checks needed

Compiler changes needed:
spec['return'] = function(expr,ctx)
  if #expr == 1 then
    return VM.expr.RETURN0()
  elseif #expr == 2 then
    return VM.expr.RETURN1(compile(expr[2],ctx))
  else
    local vals = {}
    for i = 2, #expr do
      vals[#vals+1] = compile(expr[i],ctx)
    end
    return VM.expr.RETURN(table.unpack(vals))
  end
end

Same pattern applies to:
- VALUES (VALUES0, VALUES1, VALUES)
- YIELD (YIELD0, YIELD1, YIELD)
- BREAK (BREAK0, BREAK1, BREAK)
- PROGN (PROGN0, PROGN1, PROGN - though PROGN has different semantics)

Trade-offs:
+ Performance: Eliminates runtime checks and overhead
+ Cleaner generated code
- More code to maintain
- Slightly larger API surface
- Only beneficial if 1-arg case is common (which it likely is)
--]]
