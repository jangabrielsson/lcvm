local FUNCTION = "func".."tion"
local function isContinuation(f)
  return (getmetatable(f) or {}).__type == 'continuation'
end

--[[
  Continuation-based Virtual Machine (Domain-Agnostic)
  
  This VM provides core continuation-passing style execution primitives:
  - VAR, CONST: Variable and constant access
  - IF, COND: Conditional control flow
  - AND, OR, NOT: Logical operators with short-circuit evaluation
  - PROGN: Sequential execution
  - FUNC, FUNCALL: Function definition and invocation
  - SETQ, LET: Variable assignment and local bindings
  - LOOP, BREAK: Loop constructs with early exit
  - RETURN: Function early return
  - VALUES: Multiple return values
  - LIST, CONS, CAR, CDR, NULL?: List operations
  
  Language-specific features (arithmetic, string operations, etc.) should be
  implemented in the language layer (e.g., Lisp.lua) using FUNCALL to invoke
  functions registered in the environment.
  
  Error handling is delegated to env.error (a continuation provided by the language).
--]]

-- expr: (cont,env,...) -> next_expr,cont
-- cont: (val,...) -> next_expr,cont
-- Enhanced execute with trampoline pattern to prevent stack overflow
-- Options: maxSteps, debug, onStep
local function execute(expr, cont, env, options, ...)
  options = options or {}
  local maxSteps = options.maxSteps or 100000
  local debug = options.debug or false
  local onStep = options.onStep
  
  local i = 0
  local args = {...}
  
  -- Trampoline: iteratively execute continuations without building stack
  while expr ~= nil do
    i = i + 1
    
    -- Debug output
    if debug then
      print(string.format("STEP %d: %s", i, tostring(expr)))
    end
    
    -- Step callback for instrumentation
    if onStep then
      onStep(i, expr, cont, env)
    end
    
    -- Check iteration limit
    if i > maxSteps then
      local msg = string.format("Execution exceeded %d steps (possible infinite loop)", maxSteps)
      if env.error then env.error(msg) end
      return nil, msg, i
    end
    
    -- Execute continuation with error handling
    local ok, nextExpr, nextCont = pcall(function()
      return expr(cont, env, table.unpack(args))
    end)
    
    if not ok then
      local msg = "Runtime error: " .. tostring(nextExpr)
      if env.error then env.error(msg) end
      return nil, msg, i
    end
    
    expr = nextExpr
    cont = nextCont
    args = {}  -- Clear args after first iteration
  end
  
  return true, "Success", i
end

local function VAR(name)
  return function(cont,env,...)
    return cont(env:getVar(name))
  end
end

local function IF(condExpr,thenExpr,elseExpr)
  return function(cont,env)
    return condExpr(
    function(condVal,envFromCond)
      -- envFromCond may be nil for some expressions, fallback to captured env
      local actualEnv = envFromCond or env
      if condVal then
        return thenExpr(cont,actualEnv)
      else
        return elseExpr(cont,actualEnv)
      end
    end,
    env)
  end
end

local function CONST(v)
  return function(cont,env) return cont(v) end
end

local function EXPR(fun,templ)
  return function(...)
    local str = ""
    local mt = {
      __type = 'continuation',
      __tostring = function() return str end,
    }
    local tfun = setmetatable({},mt)
    local cfun,conf = fun(...)         -- compile expr, return function(cont,env)
    if conf then conf(tfun) end        -- extra configurations
    mt.__call = function(_,...) return cfun(...) end

    local nargs = select('#', ...)
    local args,ordarg = {...},{}
    local templ2 = templ:gsub("%%(%d+)", function(n)
      n = tonumber(n)
      if n < 1 or n > nargs then
        error(string.format("Template index out of range: %d (template='%s', #args=%d)", 
          n, templ, nargs))
      end
      local a
      if args[tonumber(n)] == nil then a = "nil" else a = tostring(args[tonumber(n)]) end
      ordarg[#ordarg+1] = a
      return "%s"
    end)
    str = string.format(templ2, table.unpack(ordarg))
    return tfun
  end
end

local function evalArgs(args,cont) -- returns all values
  local params,i = {},1
  local function c(res,...)
    params[i] = res
    i = i+1
    if i > #args then 
      for _,v in ipairs({...}) do params[i] = v; i = i+1 end
      return cont(table.unpack(params)) 
    else return args[i],c end
  end
  if #args == 0 then return cont() 
  else return args[i],c end
end

local evalExprsCount = 0
local function evalExprs(exprs,cont,env) -- returns last value
  evalExprsCount = evalExprsCount + 1
  local i = 1
  local function c(...)
    i = i+1
    if i > #exprs then 
      return cont(...) 
    else 
      -- Mark tail position for last expression
      if i == #exprs and env then
        env.__inTailPosition = true
      end
      return exprs[i],c 
    end
  end
  if #exprs == 0 then return cont() 
  else 
    -- Mark tail position if only one expression
    if #exprs == 1 and env then
      env.__inTailPosition = true
    end
    return exprs[i],c 
  end
end

local function PROGN(...)
  local exprs = {...}
  return function(cont,env)
    return evalExprs(exprs,cont)
  end
end

local function FUNC(params,...)
  local rest = nil
  if params[#params-1] == '&rest' then
    rest = params[#params]
    params = {table.unpack(params,1,#params-2)}
  end
  local body = {...}
  
  -- Create the function implementation
  local fun = function(cont,env,...)
    local args = {...}
    local locals = {}
    for i=1,#params do
      locals[params[i]] = {args[i]}
    end
    if rest then
      local restArgs = {}
      for i=#params+1,#args do
        restArgs[#restArgs+1] = args[i]
      end
      locals[rest] = {restArgs}
    end
    
    -- Push new frame
    env:pushFrame(locals)
    
    -- Clear tail flag when entering function
    env.__inTailPosition = false
    
    -- Save old function continuation for nested functions
    local oldFuncCont = env.__funcCont
    
    -- Create wrapper continuation that cleans up and exits function
    env.__funcCont = function(...)
      env.__funcCont = oldFuncCont  -- Restore for nested functions
      env:popFrame()  -- Clean up frame
      return cont(...)  -- Exit function with value(s)
    end
    
    -- Execute body - if it completes normally, also clean up
    return evalExprs(body, function(...)
      env.__funcCont = oldFuncCont  -- Restore
      env:popFrame()
      return cont(...)
    end, env)
  end
  
  -- Create the function object with metatable directly
  local funcObj = {}
  local mt = {
    __type = 'continuation',
    __tostring = function() return "function" end,
    __call = function(_, cont, env, ...)
      -- When called as expression, evaluate to self (auto-quote)
      return cont(funcObj)
    end
  }
  funcObj.__fun = fun
  setmetatable(funcObj, mt)
  
  -- Return expression that evaluates to the function object
  return function(cont,env) 
    return cont(funcObj) 
  end
end

local function FUNCALL(funExpr,...)
  local args = {...}
  return function(cont,env)
    return funExpr,function(f)
      if type(f) == FUNCTION then
        return evalArgs(args, function(...)
          local stat = {pcall(f,...)}
          if stat[1] then return cont(table.unpack(stat,2)) 
          else 
            if env.error then env.error("Error in FUNCTION call: "..tostring(stat[2])..""..tostring(funExpr)) end
            return nil
          end
        end)
      elseif isContinuation(f) then
        if f.__ne then -- Non evaluating fun
          return f.__fun(cont,env,table.unpack(args))
        else
          return evalArgs(args, function(...) 
            -- Detect tail call: check if we're in tail position
            local isTail = env.__inTailPosition
            
            if isTail then
              -- Tail call optimization: pop current frame before calling
              env:popFrame()
              -- Clear flag so nested calls don't think they're tail calls
              env.__inTailPosition = false
            end
            
            return f.__fun(cont,env,...)
          end)
        end
      else
        if env.error then env.error("Attempt to call a NON-FUNCTION: "..tostring(f).." "..tostring(funExpr)) end
        return nil
      end
    end
  end
end

local function SETQ(name,valExpr)
  return function(cont,env)
    return valExpr,function(val)
      env:setVar(name, val)
      return cont(val)
    end
  end
end

local function LET(bindings,...)
  -- bindings: { {name1, expr1}, {name2, expr2}, ... }
  local body = {...}
  
  return function(cont,env)
    -- Evaluate all binding expressions in current environment
    local bindExprs = {}
    for i,binding in ipairs(bindings) do
      bindExprs[i] = binding[2]
    end
    
    -- Once all evaluated, create new frame with bindings and execute body
    return evalArgs(bindExprs, function(...)
      local values = {...}
      local locals = {}
      for i,binding in ipairs(bindings) do
        locals[binding[1]] = {values[i]}
      end
      
      env:pushFrame(locals)
      return evalExprs(body, function(...)
        env:popFrame()
        return cont(...)
      end, env)
    end)
  end
end

local function COND(...)
  local clauses = {...}
  
  return function(cont,env)
    local function testClause(i)
      if i > #clauses then
        -- No clause matched, return false (Lisp nil)
        return cont(false)
      end
      
      local clause = clauses[i]
      local test = clause[1]
      local exprs = {table.unpack(clause, 2)}
      
      -- Evaluate test
      return test, function(result)
        if result then
          -- Test passed, execute clause body
          return evalExprs(exprs, cont, env)
        else
          -- Test failed, try next clause
          return testClause(i + 1)
        end
      end
    end
    
    return testClause(1)
  end
end

local function AND2(expr1, expr2)
  return function(cont,env)
    return expr1, function(val1)
      if val1 == false then
        return cont(false)  -- Short-circuit on false
      else
        return expr2, function(val2)
          return cont(val2)  -- Return second value
        end
      end
    end
  end
end

local function ANDN(...)
  local exprs = {...}
  
  return function(cont,env)
    local function evalNext(i, lastVal)
      if i > #exprs then
        return cont(lastVal)  -- Return last value
      end
      
      return exprs[i], function(val)
        if val == false then  -- false is Lisp nil
          return cont(false)  -- Short-circuit on false
        else
          return evalNext(i + 1, val)
        end
      end
    end
    
    return evalNext(1, true)
  end
end

local function AND(...)
  local exprs = {...}
  
  return function(cont,env)
    if #exprs == 0 then
      return cont(true)
    end
    
    local function evalNext(i, lastVal)
      if i > #exprs then
        return cont(lastVal)  -- Return last value
      end
      
      return exprs[i], function(val)
        if val == false then  -- false is Lisp nil
          return cont(false)  -- Short-circuit on false
        else
          return evalNext(i + 1, val)
        end
      end
    end
    
    return evalNext(1, true)
  end
end

local function OR2(expr1, expr2)
  return function(cont,env)
    return expr1, function(val1)
      if val1 ~= false then
        return cont(val1)  -- Short-circuit, return truthy value
      else
        return expr2, function(val2)
          return cont(val2)  -- Return second value
        end
      end
    end
  end
end

local function ORN(...)
  local exprs = {...}
  
  return function(cont,env)
    local function evalNext(i)
      if i > #exprs then
        return cont(false)  -- All false
      end
      
      return exprs[i], function(val)
        if val ~= false then  -- false is Lisp nil
          return cont(val)  -- Short-circuit on non-false, return truthy value
        else
          return evalNext(i + 1)
        end
      end
    end
    
    return evalNext(1)
  end
end

local function OR(...)
  local exprs = {...}
  
  return function(cont,env)
    if #exprs == 0 then
      return cont(false)
    end
    
    local function evalNext(i)
      if i > #exprs then
        return cont(false)  -- All false
      end
      
      return exprs[i], function(val)
        if val ~= false then  -- false is Lisp nil
          return cont(val)  -- Short-circuit on non-false, return truthy value
        else
          return evalNext(i + 1)
        end
      end
    end
    
    return evalNext(1)
  end
end

local function NOT(expr)
  return function(cont,env)
    return expr, function(val)
      return cont(val == false)  -- false is Lisp nil
    end
  end
end

local function LOOP(...)
  local body = {...}
  
  return function(cont, env)
    -- Save old loop continuation for nested loops
    local oldLoopCont = env.__loopCont
    
    -- Create wrapper continuation that restores state and exits loop
    env.__loopCont = function(...)
      env.__loopCont = oldLoopCont  -- Restore for nested loops
      return cont(...)  -- Exit loop with value(s)
    end
    
    -- Create the loop expression that will be reused
    local loopExpr
    loopExpr = function(c, e)
      -- Execute body - when done, restart loop
      return evalExprs(body, function(...)
        -- Continue: restart loop by returning same loopExpr
        return loopExpr, c
      end, e)
    end
    
    -- Start the loop
    return loopExpr(cont, env)
  end
end

local function BREAK0()
  return function(cont, env, ...)
    if not env or type(env) ~= "table" or not env.__loopCont then
      error("BREAK outside of loop")
    end
    return env.__loopCont(nil)
  end
end

local function BREAK1(expr)
  return function(cont, env, ...)
    if not env or type(env) ~= "table" or not env.__loopCont then
      error("BREAK outside of loop")
    end
    return expr, function(val)
      return env.__loopCont(val)
    end
  end
end

local function BREAK(...)
  local exprs = {...}
  return function(cont, env, ...)
    if not env or type(env) ~= "table" or not env.__loopCont then
      error("BREAK outside of loop")
    end
    return evalArgs(exprs, function(...)
      return env.__loopCont(...)
    end)
  end
end

local function RETURN0()
  return function(cont, env, ...)
    if not env or type(env) ~= "table" or not env.__funcCont then
      error("RETURN outside of function")
    end
    return env.__funcCont(nil)
  end
end

local function RETURN1(expr)
  return function(cont, env, ...)
    if not env or type(env) ~= "table" or not env.__funcCont then
      error("RETURN outside of function")
    end
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
    return evalArgs(exprs, function(...)
      return env.__funcCont(...)
    end)
  end
end

local function VALUES0()
  return function(cont, env)
    return cont()
  end
end

local function VALUES1(expr)
  return function(cont, env)
    return expr, function(val)
      return cont(val)
    end
  end
end

local function VALUES(...)
  local exprs = {...}
  return function(cont, env)
    return evalArgs(exprs, function(...)
      return cont(...)
    end)
  end
end

-- Exception handling: CATCH and THROW
local function CATCH(tagExpr, ...)
  local body = {...}
  
  return function(cont, env)
    -- Evaluate the tag expression first
    return tagExpr, function(tag)
      -- Create catch continuation that will be called if a matching throw occurs
      local catchCont = function(value)
        -- Pop this catch handler
        env:popCatch()
        -- Return the thrown value to the catch continuation
        return cont(value)
      end
      
      -- Push catch handler onto catch stack
      env:pushCatch(tag, catchCont)
      
      -- Execute the body
      return evalExprs(body, function(...)
        -- Normal completion - pop catch handler and continue
        env:popCatch()
        return cont(...)
      end, env)
    end
  end
end

local function THROW(tagExpr, valueExpr)
  return function(cont, env)
    -- Evaluate tag expression
    return tagExpr, function(tag)
      -- Evaluate value expression if provided, otherwise throw nil
      local evaluateValue = valueExpr or CONST(false)  -- false is Lisp nil
      
      return evaluateValue, function(value)
        -- Find matching catch handler
        local catchCont = env:findCatch(tag)
        
        if catchCont then
          -- Found a matching catch - invoke its continuation with the value
          return catchCont(value)
        else
          -- No matching catch - unhandled exception
          env.error("Unhandled THROW with tag: " .. tostring(tag) .. ", value: " .. tostring(value))
        end
      end
    end
  end
end

-- Coroutine support: CREATE-COROUTINE, RESUME, YIELD
local function CREATE_COROUTINE(funcExpr)
  return function(cont, env)
    -- First evaluate the function expression to get the actual function
    return funcExpr, function(func)
      -- func should now be the actual function value
      -- Create coroutine object (don't copy env, use reference)
      local co = {
        type = "coroutine",
        status = 'suspended',  -- 'suspended', 'running', 'dead'
        func = func,           -- The coroutine function (already evaluated)
        cont = nil,            -- Continuation for resume
        resumeCont = nil,      -- Continuation to return to resumer
        env = env              -- Use the same environment (don't copy)
      }
      return cont(co)
    end
  end
end

local function YIELD0()
  return function(cont, env, ...)
    local co = env:getCurrentCoroutine()
    if not co then
      env.error("YIELD outside of coroutine")
      return
    end
    co.cont = cont
    co.status = 'suspended'
    return co.resumeCont(true)
  end
end

local function YIELD1(expr)
  return function(cont, env, ...)
    local co = env:getCurrentCoroutine()
    if not co then
      env.error("YIELD outside of coroutine")
      return
    end
    co.cont = cont
    co.status = 'suspended'
    return expr, function(val)
      return co.resumeCont(true, val)
    end
  end
end

local function YIELD(...)
  local exprs = {...}
  return function(cont, env, ...)
    local co = env:getCurrentCoroutine()
    if not co then
      env.error("YIELD outside of coroutine")
      return
    end
    co.cont = cont
    co.status = 'suspended'
    return evalArgs(exprs, function(...)
      return co.resumeCont(true, ...)
    end)
  end
end

local function RESUME(coExpr, ...)
  local valueExprs = {...}
  return function(cont, env)
    return coExpr, function(co)
      -- Check if it's a coroutine
      if type(co) ~= "table" or co.type ~= "coroutine" then
        return cont(false, "bad argument #1 to 'resume' (coroutine expected)")
      end
      
      -- Check if coroutine is dead
      if co.status == 'dead' then
        return cont(false, "cannot resume dead coroutine")
      end
      
      -- Check if already running
      if co.status == 'running' then
        return cont(false, "cannot resume running coroutine")
      end
      
      -- Save old coroutine context
      local oldCo = env:getCurrentCoroutine()
      
      -- Set current coroutine BEFORE creating the wrapper continuation
      env:setCurrentCoroutine(co)
      co.status = 'running'
      
      -- Create wrapper that always restores coroutine context
      local function wrapperCont(...)
        -- Restore old coroutine context before returning to caller
        env:setCurrentCoroutine(oldCo)
        return cont(...)
      end
      
      -- Store the wrapper as resumer's continuation
      co.resumeCont = wrapperCont
      
      -- Evaluate values to pass to coroutine
      local function proceedWithValues(...)
        local values = {...}
        
        if co.cont then
          -- Resume from where it yielded
          local resumeVal = values[1] or false
          local savedCont = co.cont
          co.cont = nil  -- Clear continuation
          
          -- Set up returnHandler for when the function finishes
          co.returnHandler = function(...)
            co.status = 'dead'
            return wrapperCont(true, ...)
          end
          
          return savedCont(resumeVal)
        else
          -- First resume - call the coroutine function
          co.returnHandler = function(...)
            co.status = 'dead'
            return wrapperCont(true, ...)
          end
          
          -- Create a wrapper continuation that checks if we're in a coroutine
          -- and calls returnHandler instead of the normal continuation
          local function coroutineReturn(...)
            if co.returnHandler then
              return co.returnHandler(...)
            else
              -- Fallback - shouldn't happen
              co.status = 'dead'
              return wrapperCont(true, ...)
            end
          end
          
          return co.func.__fun(coroutineReturn, env, table.unpack(values))
        end
      end
      
      if #valueExprs == 0 then
        return proceedWithValues(false)  -- Pass nil (false)
      else
        return evalArgs(valueExprs, proceedWithValues)
      end
    end
  end
end

-- List operations (using Lua tables as cons cells)
local function LIST(...)
  local exprs = {...}
  return function(cont, env)
    if #exprs == 0 then
      return cont(false)  -- Empty list is false (nil in Lisp)
    else
      return evalArgs(exprs, function(...)
        local values = {...}
        return cont(values)  -- Return Lua table as list
      end)
    end
  end
end

local function CONS(carExpr, cdrExpr)
  return function(cont, env)
    return carExpr, function(carVal)
      return cdrExpr, function(cdrVal)
        local cell = {carVal}
        -- If cdr is a list, append it; if false/nil, treat as empty list
        if type(cdrVal) == 'table' then
          for i, v in ipairs(cdrVal) do
            cell[#cell + 1] = v
          end
        elseif cdrVal ~= false then
          -- Non-false, non-table: improper list (dotted pair)
          cell[2] = cdrVal
        end
        -- If cdrVal is false, just return {carVal} (proper list)
        return cont(cell)
      end
    end
  end
end

local function CAR(listExpr)
  return function(cont, env)
    return listExpr, function(list)
      if type(list) == 'table' and #list > 0 then
        return cont(list[1])
      else
        if env.error then env.error("CAR: not a list or empty list") end
        return cont(false)
      end
    end
  end
end

local function CDR(listExpr)
  return function(cont, env)
    return listExpr, function(list)
      if type(list) == 'table' and #list > 0 then
        local rest = {}
        for i = 2, #list do
          rest[#rest + 1] = list[i]
        end
        return cont(#rest > 0 and rest or false)  -- Return false for empty
      else
        if env.error then env.error("CDR: not a list or empty list") end
        return cont(false)
      end
    end
  end
end

local function NULLP(expr)
  return function(cont, env)
    return expr, function(val)
      local isNull = (val == false) or (type(val) == 'table' and #val == 0)
      return cont(isNull)
    end
  end
end

local expr = {}
expr.VAR = EXPR(VAR,"(VAR %1)")
expr.CONST = EXPR(CONST,"(CONST %1)")
expr.QUOTE = expr.CONST
expr.NIL = function () return expr.CONST(false) end  -- Lisp nil is false
expr.TRUE = function () return expr.CONST(true) end
expr.FALSE = function () return expr.CONST(false) end
expr.IF = EXPR(IF,"(IF %1 THEN %2 ELSE %3)")
expr.PROGN = EXPR(PROGN,"(PROGN ...)")
expr.LAMBDA = FUNC  -- Anonymous functions (no EXPR wrapper - self-evaluating)
expr.FUNC = FUNC    -- Backward compatibility alias
expr.FUNCALL = EXPR(FUNCALL,"(%1 ...)")
expr.SETQ = EXPR(SETQ,"(SETQ %1 %2)")
expr.LET = EXPR(LET,"(LET ...)")
expr.COND = EXPR(COND,"(COND ...)")
-- Smart dispatcher for AND - chooses optimal variant based on arg count
expr.AND = function(...)
  local n = select('#', ...)
  if n == 0 then
    return EXPR(AND,"(AND)")()
  elseif n == 2 then
    return EXPR(AND2,"(AND %1 %2)")(...)  
  else
    return EXPR(ANDN,"(AND ...)")(...)  
  end
end
-- Smart dispatcher for OR - chooses optimal variant based on arg count
expr.OR = function(...)
  local n = select('#', ...)
  if n == 0 then
    return EXPR(OR,"(OR)")()
  elseif n == 2 then
    return EXPR(OR2,"(OR %1 %2)")(...)  
  else
    return EXPR(ORN,"(OR ...)")(...)  
  end
end
expr.NOT = EXPR(NOT,"(NOT %1)")
expr.LOOP = EXPR(LOOP,"(LOOP ...)")
-- Smart dispatcher for BREAK - chooses optimal variant based on arg count
expr.BREAK = function(...)
  local n = select('#', ...)
  if n == 0 then
    return EXPR(BREAK0,"(BREAK)")()
  elseif n == 1 then
    return EXPR(BREAK1,"(BREAK %1)")(...)
  else
    return EXPR(BREAK,"(BREAK ...)")(...)  
  end
end
-- Smart dispatcher for RETURN - chooses optimal variant based on arg count
expr.RETURN = function(...)
  local n = select('#', ...)
  if n == 0 then
    return EXPR(RETURN0,"(RETURN)")()
  elseif n == 1 then
    return EXPR(RETURN1,"(RETURN %1)")(...)
  else
    return EXPR(RETURN,"(RETURN ...)")(...)  
  end
end
-- Smart dispatcher for VALUES - chooses optimal variant based on arg count
expr.VALUES = function(...)
  local n = select('#', ...)
  if n == 0 then
    return EXPR(VALUES0,"(VALUES)")()
  elseif n == 1 then
    return EXPR(VALUES1,"(VALUES %1)")(...)
  else
    return EXPR(VALUES,"(VALUES ...)")(...)  
  end
end
expr.CATCH = EXPR(CATCH,"(CATCH %1 ...)")
expr.THROW = EXPR(THROW,"(THROW %1 %2)")
expr.CREATE_COROUTINE = EXPR(CREATE_COROUTINE,"(CREATE-COROUTINE %1)")
expr.RESUME = EXPR(RESUME,"(RESUME %1 ...)")
-- Smart dispatcher for YIELD - chooses optimal variant based on arg count
expr.YIELD = function(...)
  local n = select('#', ...)
  if n == 0 then
    return EXPR(YIELD0,"(YIELD)")()
  elseif n == 1 then
    return EXPR(YIELD1,"(YIELD %1)")(...)
  else
    return EXPR(YIELD,"(YIELD ...)")(...)  
  end
end
expr.LIST = EXPR(LIST,"(LIST ...)")
expr.CONS = EXPR(CONS,"(CONS %1 %2)")
expr.CAR = EXPR(CAR,"(CAR %1)")
expr.CDR = EXPR(CDR,"(CDR %1)")
expr.NULLP = EXPR(NULLP,"(NULL? %1)")

local function createEnvironment(vars,nonVarHandler,sharedTopvars)
  local self = { 
    nonVarHandler = nonVarHandler 
  }
  vars = vars or {}
  -- Use shared topvars if provided, otherwise create new one
  self.topvars = sharedTopvars or vars  -- Store directly in self
  local frameStack = {vars}  -- Track frame stack for tail call optimization
  self.frameStack = frameStack  -- Expose for copy to update
  local catchStack = {}  -- Stack of {tag, cont} pairs for exception handling
  
  -- Error handler that integrates with catch/throw
  self.error = function(msg, tag) 
    tag = tag or 'error'
    -- Try to find a matching catch
    for i = #catchStack, 1, -1 do
      if catchStack[i].tag == tag then
        -- Found a catch, throw to it
        return catchStack[i].cont({
          type = "builtin-error",
          tag = tag,
          message = msg
        })
      end
    end
    -- No matching catch - fatal error (original behavior)
    print("ERROR: " .. msg)
    error(msg, 0) 
  end
  
  function self:getVar(name) 
    local v = vars[name] 
    if v then return v[1] end
    -- If not in frame chain, check topvars (globals)
    v = rawget(self.topvars, name)
    if v then return v[1] end
    -- Finally try nonVarHandler
    if self.nonVarHandler then return self.nonVarHandler(name) end
  end
  function self:setLocal(name,val) rawset(vars,name,{val}) end
  function self:setVar(name,val) 
    local v = vars[name] 
    if v then v[1] = val else rawset(self.topvars,name,{val}) end 
  end
  function self:setGlobal(name,val) 
    local v = rawget(self.topvars,name) 
    if v then v[1] = val else rawset(self.topvars,name,{val}) end
  end
  function self:getGlobal(name) 
    local v = rawget(self.topvars,name) 
    return v and v[1] 
  end
  local fd = 1
  function self:pushFrame(locals)
    if fd > 2000 then 
      self.error("Max stack depth (2000) exceeded")
    end
    vars = setmetatable(locals, { __index = vars })
    fd = fd + 1
    locals.__fd  = fd
    frameStack[#frameStack + 1] = vars
    --print(fd)
  end
  function self:popFrame() 
    if #frameStack > 1 then
      frameStack[#frameStack] = nil
      vars = frameStack[#frameStack]
      fd = vars.__fd or 1
    end
  end
  
  -- Catch/throw support
  function self:pushCatch(tag, cont)
    table.insert(catchStack, {tag = tag, cont = cont})
  end
  
  function self:popCatch()
    table.remove(catchStack)
  end
  
  function self:findCatch(tag)
    -- Search from innermost to outermost
    for i = #catchStack, 1, -1 do
      if catchStack[i].tag == tag then
        return catchStack[i].cont
      end
    end
    return nil  -- No matching catch found
  end
  
  -- Coroutine support - stored in vars so it's accessible across frames
  function self:getCurrentCoroutine()
    -- Look for __coro__ in the vars chain
    local v = rawget(self.topvars, '__coro__')
    return v and v[1]
  end
  
  function self:setCurrentCoroutine(co)
    -- Store in topvars so it's accessible everywhere
    rawset(self.topvars, '__coro__', {co})
  end
  
  function self:getStackPoint() return vars end
  
  function self:copy(v,nvh)
    -- Preserve the same topvars so globals are shared across all copies
    local e = createEnvironment(v or vars, nvh or self.nonVarHandler, self.topvars)
    -- Rebuild frameStack from the vars chain
    local stack = {}
    local current = v or vars
    while current do
      table.insert(stack, 1, current)
      local mt = getmetatable(current)
      current = mt and mt.__index
    end
    e.frameStack = stack
    -- Copy error handler from parent environment
    if self.error then e.error = self.error end
    return e
  end
  return self
end

VM = {}
VM.expr = expr
VM.execute = execute
VM.createEnvironment = createEnvironment
VM.evalExprsCount = function() return evalExprsCount end