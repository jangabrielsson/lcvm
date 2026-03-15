ER = ER or { _tools = {} }

local unpack = table.unpack
local EXPR,cast
local compile

local comp = {}

-- LOCATE: pure-CPS wrapper that sets env.__loc before evaluating inner.
-- Completely decoupled from the VM -- just another continuation function.
local function LOCATE(pos, len, inner)
  if not pos then return inner end
  return function(cont, env, ...)
    local prev = env.__loc
    env.__loc = {pos=pos, len=len}
    return inner(function(...)
      env.__loc = prev
      return cont(...)
    end, env, ...)
  end
end

function comp.statements(node)
  local statements = {}
  for _,stat in ipairs(node.statements) do
    statements[#statements+1] = compile(stat)
  end
  if node.locals and next(node.locals) then
    local locals = {}
    for _,localVar in ipairs(node.locals) do
      locals[#locals+1] = localVar
    end
    return EXPR.LETV(locals, table.unpack(statements))
  end
  return EXPR.PROGN(table.unpack(statements))
end

function comp.number(node)
  return EXPR.CONST(node.value)
end

function comp.string(node)
  return EXPR.CONST(node.value)
end

function comp.literal(node)
  return EXPR.CONST(node.value)
end

comp['true'] = function(node)
  return EXPR.CONST(true)
end

comp['false'] = function(node)
  return EXPR.CONST(false)
end

comp['nil'] = function(node)
  return EXPR.CONST(false)  -- Lisp nil is false
end

local consts = { ['number']=true, ['string']=true, ['literal']=true, ['boolean']=true}
local function keyValue(key)
  if type(key) ~= 'table' then return EXPR.CONST(key) end
  return compile(key)
  --error("Unsupported key type: "..tostring(key.type))
end

function comp.assign(node)
  local exprs,vars,tabs = {},{},{}
  for i,var in ipairs(node.vars) do
    if var.type == 'tableaccess' then 
      local tab = compile(var.table)
      local key = keyValue(var.key)
      local value = compile(node.exprs[i])
      table.remove(node.exprs, i)
      tabs[#tabs+1] = EXPR.ASET(tab, key, value)
    elseif var.type == 'variable' then
      vars[#vars+1] = var.name
    elseif type(var)=='string' then
      vars[#vars+1] = var
    else      
      vars[#vars+1] = compile(var)
      --error("Unsupported assignment target type: "..tostring(var.type))
    end
  end
  for _,expr in ipairs(node.exprs) do
    exprs[#exprs+1] = compile(expr)
  end
  if next(tabs) then
    if next(vars) then
      return EXPR.PROGN(
        EXPR.SETQ(vars, exprs),
        table.unpack(tabs)
      )
    else
      return EXPR.PROGN(table.unpack(tabs))
    end
  end
  return EXPR.SETQ(vars, exprs)
end

comp.tableaccess = function(node)
  local tab = compile(node.table)
  local key = keyValue(node.key)
  return LOCATE(node.pos, node.len, EXPR.AREF(tab, key))
end

comp['return'] = function(node)
  local exprs = {}
  for _,expr in ipairs(node.exprs) do
    exprs[#exprs+1] = compile(expr)
  end
  return EXPR.RETURN(table.unpack(exprs))
end

comp['if'] = function(node) 
  -- {type='if', test=test, body=body, elseifs=elseifs, else_body=elsebody}
  local test = compile(node.test)
  local thenExpr = EXPR.PROGN(compile(node.body))
  local elseExpr
  if not node.elseifs or #node.elseifs == 0 then
    elseExpr = node.else_body and EXPR.PROGN(compile(node.else_body)) or EXPR.CONST(false)
  else
    local firstIf = node.elseifs[1]
    local elseIfs = {select(2,table.unpack(node.elseifs))}
    elseExpr = compile({type='if', test=firstIf.test, body=firstIf.body, elseifs=elseIfs, else_body=node.else_body})
  end
  return EXPR.IF(test,thenExpr,elseExpr)
end

local opmap = {
  ['not'] = 'not',
  ['and'] = 'and',
  ['or'] = 'or',  
  ['plus'] = '+',
  ['minus'] = '-',
  ['multiply'] = '*',
  ['divide'] = '/',  
  ['equal'] = '==',  
  ['not_equal'] = '~=',
  ['greater_than'] = '>',
  ['less_than'] = '<',
  ['greater_equal'] = '>=',
  ['less_equal'] = '<=',
}
local ERopMap = {
  ['betw'] = function(a,b) return fibaro.utils.between(a,b) end,
  ['conc'] = function(a,b) return tostring(a)..tostring(b) end,
  ['match'] = function(a,b) return tostring(a):match(tostring(b)) ~= nil end,
  ['nilco'] = function(a,b) 
    if a ~= nil then return a else return b end 
  end,
  ['today'] = 'today',
  ['nexttime'] = 'nexttime',
  ['plustime'] = 'plustime',
  ['gv'] = function(name) return fibaro.getGlobalVariable(name) end,
  ['qv'] = function(name) return quickApp:getVariable(name) end,
  ['pv'] = 'pv',
}

function comp.binop(node)
  local left = compile(node.left)
  local right = compile(node.right)
  local op = opmap[node.op] or ERopMap[node.op]
  if op then return EXPR.BINOP(op, left, right) end
  op = ERopMap[node.op]
  --if op then return EXPR.BINOP(op, left, right) end
  if not op then error("Unknown binary operator: "..tostring(node.op)) end
end

function comp.unop(node)
  local operand = compile(node.operand)
  local op = opmap[node.op] or ERopMap[node.op]
  if not op then error("Unknown unary operator: "..tostring(node.op)) end
  return EXPR.UNOP(op, operand)
end

comp['and'] = function(node)
  local left = compile(node.left)
  local right = compile(node.right)
  return EXPR.AND(left, right)
end

comp['or'] = function(node)
  local left = compile(node.left)
  local right = compile(node.right)
  return EXPR.OR(left, right)
end

function comp.variable(node)
  return LOCATE(node.pos, node.len, EXPR.VAR(node.name))
end

function comp.call(node)
  local func = compile(node.func)
  local args = {}
  for _,arg in ipairs(node.args) do
    args[#args+1] = compile(arg)
  end
  return LOCATE(node.pos, node.len, EXPR.FUNCALL(func, unpack(args)))
end

comp.methodcall = function(node)
  -- obj:method(args)  ->  FUNCALL(AREF(obj, 'method'), obj, args)
  local objExpr = compile(node.object)
  local methodExpr = EXPR.AREF(objExpr, EXPR.CONST(node.method))
  local allArgs = {objExpr}
  for _,arg in ipairs(node.args) do
    allArgs[#allArgs+1] = compile(arg)
  end
  return LOCATE(node.pos, node.len, EXPR.FUNCALL(methodExpr, unpack(allArgs)))
end

function comp.table(node)
  local entries = {}
  local idx = 1
  for _,entry in ipairs(node.fields) do
    local value = compile(entry.value)
    local key = nil
    if entry.key == nil then
      key = EXPR.CONST(idx); idx = idx+1
    else
      key = EXPR.CONST(entry.key.value)
    end
    entries[#entries+1] = key;
    entries[#entries+1] = value;
  end
  return EXPR.MAKE_TABLE(unpack(entries))
end

comp['do'] = function(node)
  return compile(node.body)
end

comp['loop'] = function(node)
  local body = node.body
  return EXPR.LOOP(compile(body))
end

comp['repeat'] = function(node)
  local body = node.body
  local check = {type='if',test=node.test, body={type='break'}}
  table.insert(body.statements,check)
  return EXPR.LOOP(compile(body))
end

comp['while'] = function(node)
  local body = node.body
  local test = {type='unop', op='not', operand=node.test}
  local check = {type='if',test=test, body={type='break'}}
  table.insert(body.statements,1,check)
  return EXPR.LOOP(compile(body))
end

comp['for_numeric'] = function(node)
  -- for var = start, limit [, step] do body end
  -- Desugars to:
  --   letv(var, __lim, __stp)
  --   setq var=start, __lim=limit, __stp=step
  --   loop
  --     if __stp*var > __stp*__lim then break end
  --     body
  --     var = var + __stp
  --   end
  local var = node.var
  local lim = '__for_lim__'
  local stp = '__for_stp__'
  local startExpr = compile(node.start)
  local limitExpr = compile(node.limit)
  local stepExpr  = node.step and compile(node.step) or EXPR.CONST(1)
  local bodyExpr  = compile(node.body)
  local breakCond = EXPR.BINOP('>',
    EXPR.BINOP('*', EXPR.VAR(stp), EXPR.VAR(var)),
    EXPR.BINOP('*', EXPR.VAR(stp), EXPR.VAR(lim))
  )
  return EXPR.LETV({var, lim, stp},
    EXPR.SETQ(var,  startExpr),
    EXPR.SETQ(lim,  limitExpr),
    EXPR.SETQ(stp,  stepExpr),
    EXPR.LOOP(
      EXPR.IF(breakCond,
        EXPR.BREAK(),
        EXPR.PROGN(
          bodyExpr,
          EXPR.SETQ(var, EXPR.BINOP('+', EXPR.VAR(var), EXPR.VAR(stp)))
        )
      )
    )
  )
end

comp['for_generic'] = function(node)
  -- for v1,v2,... in explist do body end
  -- Desugars to:
  --   letv(__iter, __state, __ctrl, v1, v2, ...)
  --   setq {__iter,__state,__ctrl} = explist  (up to 3 values from iterator factory)
  --   loop
  --     setq {v1,v2,...} = __iter(__state, __ctrl)
  --     if v1 == nil then break end
  --     __ctrl = v1
  --     body
  --   end
  local names   = node.names
  local iterVar = '__for_iter__'
  local stateVar= '__for_state__'
  local ctrlVar = '__for_ctrl__'
  local allLocals = {iterVar, stateVar, ctrlVar}
  for _,n in ipairs(names) do allLocals[#allLocals+1] = n end
  -- compile init explist (may be 1..3 expressions: iter [, state [, init]])
  local initExprs = {}
  for _,e in ipairs(node.explist) do initExprs[#initExprs+1] = compile(e) end
  local bodyExpr = compile(node.body)
  -- call iter each iteration and destructure into names
  local iterCall = EXPR.FUNCALL(EXPR.VAR(iterVar), EXPR.VAR(stateVar), EXPR.VAR(ctrlVar))
  return EXPR.LETV(allLocals,
    EXPR.SETQ({iterVar, stateVar, ctrlVar}, initExprs),
    EXPR.LOOP(
      EXPR.PROGN(
        EXPR.SETQ(names, {iterCall}),
        EXPR.IF(
          EXPR.NULLP(EXPR.VAR(names[1])),
          EXPR.BREAK(),
          EXPR.PROGN(
            EXPR.SETQ(ctrlVar, EXPR.VAR(names[1])),
            bodyExpr
          )
        )
      )
    )
  )
end

comp['break'] = function(node)
  local a = node
  return EXPR.BREAK()
end

local function compFuncbody(node)
  -- node = {type='funcbody', params={...}, hasVararg=bool, body=...}
  local params = node.params or {}
  if node.hasVararg then
    params = {table.unpack(params)}
    params[#params+1] = '&rest'
    params[#params+1] = '__vararg__'
  end
  return EXPR.LAMBDA(params, compile(node.body))
end

comp['function'] = function(node)
  return compFuncbody(node.body)
end

comp['functiondef'] = function(node)
  -- function a.b.c() end  -> a.b.c = function() end
  local funcname = node.name
  local lambda = compFuncbody(node.body)
  if #funcname.names == 1 and not funcname.method then
    return EXPR.SETQ(funcname.names[1], lambda)
  else
    -- a.b.c  -> ASET(AREF(VAR('a'),'b'), 'c', lambda)
    local obj = EXPR.VAR(funcname.names[1])
    for i = 2, #funcname.names - 1 do
      obj = EXPR.AREF(obj, EXPR.CONST(funcname.names[i]))
    end
    local lastName = funcname.method or funcname.names[#funcname.names]
    if funcname.method then
      -- method: insert 'self' as first param
      local p = {'self', table.unpack(node.body.params or {})}
      local mb = {type='funcbody', params=p, hasVararg=node.body.hasVararg, body=node.body.body}
      lambda = compFuncbody(mb)
      obj = EXPR.AREF(obj, EXPR.CONST(funcname.names[#funcname.names]))
    end
    return EXPR.ASET(obj, EXPR.CONST(lastName), lambda)
  end
end

comp['localfunc'] = function(node)
  return EXPR.SETQ(node.name, compFuncbody(node.body))
end

function compile(ast)
  if ast and comp[ast.type] then 
    return comp[ast.type](ast)
  else
    print(json.encodeFormated(cast))
    error("No compiler for AST node type: "..ast.type)
  end
end

function ER._tools.compile(ast)
  EXPR = VM.expr
  cast = ast
  return compile(ast)
end