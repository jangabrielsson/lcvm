--%%offline:true 
--%%file:Continuation.lua,cont

local parse
local fmt = string.format
local function skipSpace(str) return 'space',nil,str:match("^[ \t\n]*(.*)") end
local function getNum(str,sign) local n,r = str:match("^(%d+%.?%d*)(.*)") return 'number',tonumber(n)*(sign or 1),r end
local function getAtom(str) return 'atom',str:match("^(.[%w!$%%&*/:<=>%?^_~%+%-]*)(.*)") end
local tokenTab = {}
for c in (" \t\n"):gmatch(".") do tokenTab[c] = skipSpace end
for c in ("0123456789"):gmatch(".") do tokenTab[c] = getNum end
for c in ("!$%&*/:<=>?^_~abcdefghijklmnopqrstuvxyzwABCDEFGHIJKLMNOPQRSTUVXYZW"):gmatch(".") do tokenTab[c] = getAtom end
tokenTab['('] = function(str) return 'lpar','(',str:sub(2) end
tokenTab[')'] = function(str) return 'rpar',')',str:sub(2) end
tokenTab['.'] = function(str) return 'dot','.',str:sub(2) end
tokenTab[','] = function(str) return 'comma','.',str:sub(2) end
tokenTab['"'] = function(str) return 'string',str:match('^"([^"]*)"(.*)') end
tokenTab["'"] = function(str) return 'quote',"'",str:sub(2) end  -- Quote reader macro
for c in ("+"):gmatch(".") do tokenTab[c] = function(str) return 'atom',str:sub(1,1),str:sub(2) end end
tokenTab['-'] = function(str) if str:sub(2,2):match("%d") then return getNum(str:sub(2),-1) else return 'atom','-',str:sub(2) end end
tokenTab[';'] = function(str) return 'space',nil,str:match("^[^%\n]*(.*)") end

local function nextToken(str)
  if str == "" then return 'eof',nil,str end
  local tf = tokenTab[str:sub(1,1)]
  if tf then
    local typ,tkn,str = tf(str)
    if typ=='space' then return nextToken(str) end
    return typ,tkn,str
  end
  error("Unknown token: "..str:sub(1,1))
end

local function createTokenizer(str)
  local function nxt()
    local typ, tkn
    typ, tkn,str = nextToken(str)
    local r = {type=typ, value=tkn}
    setmetatable(r, {__tostring = function() return (r.value or r.type) end})
    return r
  end
  local self,lt = {},nxt()
  function self.peek() return lt end
  function self.isType(t) return lt.type == t end
  function self.next() local v = lt; lt = nxt() return v end
  function self.mustBeType(t) 
    assert(self.isType(t), "Expected '"..t.."', got '"..(lt.value or lt.type).."'")
    self.next()
  end
  return self
end

local listMT = { __tostring = function(self)
  local b = {"("}
  for i=1,#self do
    if i>1 then table.insert(b," ") end
    table.insert(b,tostring(self[i]))
  end
  if self.cdr then
    table.insert(b," . ")
    table.insert(b,tostring(self.cdr))
  end
  table.insert(b,")")
  return table.concat(b)
end }

local quoteMT = { __tostring = function(self)
  return "'"..tostring(self[1])
end }

local stringMT = { __tostring = function(self)
  return '"'..self.value..'"'
end }

function parse(tkns) 
  local t = tkns.next()
  if t.type=='atom' then
    if t.value == 't' then return true
    elseif t.value == 'false' then return false
    elseif t.value == 'nil' then return false  -- Use false for Lisp nil
    else  return t.value end
  elseif t.type=='number' then
    return t.value
  elseif t.type=='string' then
    return setmetatable({value = t.value}, stringMT)
  elseif t.type=='quote' then
    -- 'expr is shorthand for (quote expr)
    local quoted = parse(tkns)
    return setmetatable({'quote', quoted}, quoteMT)
  elseif t.type=='lpar' then
    local lst = {}
    while not (tkns.isType('rpar') or tkns.isType('dot')) do
      local sexpr = parse(tkns)
      table.insert(lst,sexpr)
    end
    if tkns.isType('dot') then
      tkns.next()
      lst.cdr = parse(tkns)
    end
    tkns.mustBeType('rpar')
    return setmetatable(lst, listMT)
  else 
    error("Unexpected token: "..tkns.peek().type)
  end
end

local function parserStream(str) 
  local tkns = createTokenizer(str)
  return function()
    if tkns.isType('eof') then return nil end
    return parse(tkns)
  end
end

local function parser(str) return parse(createTokenizer(str)) end

local function checkArgs(...)
  local args = {...}
  for i=1,#args,2 do
    local val, expectedType = args[i], args[i+1]
    if type(val) ~= expectedType then
      error(string.format("Type error: expected %s, got %s", expectedType, type(val)))
    end
  end
end

local function Lisp(opts)
  local self = { opts = opts or {}, macro = {}, setfs = {}, lastSource = "" }
  self.env = VM.createEnvironment()
  local lisp = self  -- Capture self for closures
  
  -- Enhanced error handler that shows source
  local function errorHandler(msg)
    print("ERROR: " .. msg)
    if lisp.lastSource and lisp.lastSource ~= "" then
      print("  in expression: " .. lisp.lastSource:sub(1,100) .. (lisp.lastSource:len() > 100 and "..." or ""))
    end
    error(msg, 0)
  end
  self.env.error = errorHandler
  self.var = setmetatable({},{
    __index = function(t,k) return self.env:getGlobal(k) end,
    __newindex = function(t,k,v) self.env:setGlobal(k,v) end
  })
  -- Lisp constants
  self.var['t'] = true
  -- Note: 'nil' is handled specially in compilation, not as a variable
  self.var['true'] = true
  self.var['false'] = false
  self.var['not'] = function(a) return not a end
  self.var['+'] = function(a,b) checkArgs(a,'number',b,'number') return a+b end
  self.var['*'] = function(a,b) checkArgs(a,'number',b,'number') return a*b end
  self.var['/'] = function(a,b) checkArgs(a,'number',b,'number') return a/b end
  self.var['-'] = function(a,b) return b==nil and -a or a-b end
  self.var['='] = function(a,b) return a==b end
  self.var['!='] = function(a,b) return a~=b end
  self.var['>'] = function(a,b) return a>b end
  self.var['>='] = function(a,b) return a>=b end
  self.var['<'] = function(a,b) return a<b end
  self.var['<='] = function(a,b) return a<=b end
  self.var['%'] = function(a,b) checkArgs(a,'number',b,'number') return a % b end
  self.var['^'] = function(a,b) checkArgs(a,'number',b,'number') return a ^ b end
  self.var.aref = function(tab,idx) return tab[idx] end
  self.var.print = function(...) 
    local args = {...}
    -- Format all arguments as strings
    local strs = {}
    for i=1,#args do
      strs[#strs+1] = tostring(args[i])
    end
    print(table.concat(strs, " "))  -- Print with spaces between args
    return args[#args]  -- Return last argument (Lisp convention)
  end
  self.var.memory = function() 
    collectgarbage("collect") 
    collectgarbage("collect") -- Run twice to ensure full collection
    return string.format("Memory:%0.0fK Frames:%d evalExprs:%d", 
      collectgarbage("count"), #lisp.env.frameStack, VM.evalExprsCount())
  end
  self.var.pairs = pairs
  self.var.ipairs = ipairs
  self.var.table = function(...)
    local t,args = {},{...}
    for i=1,#args,2 do t[args[i]] = args[i+1] end
    return t
  end
  -- Error handler is set above in Lisp constructor
  for k,v in pairs(macro or {}) do self.macro[k] = v end
  self.setfs.car = function(env, val, obj) obj[1] = val; return val end
  self.setfs.aref = function(env, val, obj, key) obj[key] = val; return val end

  function self:setVar(name,val) self.env:setVar(name,val) end
  function self:getVar(name) return self.env:getVar(name) end

  function self:_compile(expr)
    gopts = self.opts
    if type(expr) == 'string' then
      self.lastSource = expr  -- Store source for error reporting
      expr = parser(expr)
    else
      -- For pre-parsed expressions, use tostring to get source representation
      self.lastSource = tostring(expr)
    end
    local ctx = {lisp = self}
    return compile(expr,ctx)
  end

  function self:_eval(c,vars,...)
    env = self.env:copy()
    local res,printRes = {},false
    local function cont(...) 
      if printRes then print(...) end
      res = {...} 
      env:popFrame()
      return nil
    end
    local function suspend(ref) 
      printRes = true
    end
    env.suspend = suspend
    env:pushFrame(vars or {}) -- create new local environment
    env:setLocal('__frame',{nil,cont,env:getStackPoint()}) 
    VM.execute(c,cont,env,{maxSteps = math.huge, debug = false},...) -- Turn off debug
    return table.unpack(res)
  end

  function self:eval(expr)
    return self:_eval(self:_compile(expr))
  end

  function self:parseStream(str) return parserStream(str) end
  return self
end

local spec = {}
spec['if'] = function(expr,ctx)
  assert(#expr==4 or #expr==3, "if requires 2-3 arguments")
  local cond = compile(expr[2],ctx)
  local thenb = compile(expr[3],ctx)
  local elseb = VM.expr.CONST(false)
  if #expr == 4 then elseb = compile(expr[4],ctx) end
  return VM.expr.IF(cond,thenb,elseb)
end
spec['progn'] = function(expr,ctx)
  local exprs = {}
  for i=2,#expr do
    exprs[#exprs+1] = compile(expr[i],ctx)
  end
  return VM.expr.PROGN(table.unpack(exprs))
end
spec['lambda'] = function(expr,ctx) -- (lambda (a b) . body )
  local params,body = expr[2],{}
  for i=3,#expr do
    body[i-2] = compile(expr[i],ctx)
  end
  return VM.expr.LAMBDA(params,table.unpack(body))
end
spec['func'] = spec['lambda']  -- Backward compatibility alias
spec['defun'] = function(expr,ctx) -- (defun name (params) . body)
  assert(#expr >= 3, "defun requires name, params, and body")
  local name,params,body = expr[2],expr[3],{}
  for i=4,#expr do
    body[#body+1] = compile(expr[i],ctx)
  end
  return VM.expr.SETQ(name, VM.expr.LAMBDA(params, table.unpack(body)))
end
spec['quote'] = function(expr,ctx) -- (quote value)
  -- Return the quoted value directly without compiling it
  return VM.expr.CONST(expr[2])
end
spec['setq'] = function(expr,ctx) -- (setq atom value)
  return VM.expr.SETQ(expr[2],compile(expr[3],ctx))
end
spec['loop'] = function(expr,ctx) -- (loop . body)
  local body = {}
  for i=2,#expr do
    body[#body+1] = compile(expr[i],ctx)
  end
  return VM.expr.LOOP(table.unpack(body))
end
spec['break'] = function(expr,ctx) -- (break [value...])
  local vals = {}
  for i = 2, #expr do
    vals[#vals+1] = compile(expr[i],ctx)
  end
  return VM.expr.BREAK(table.unpack(vals))
end
spec['return'] = function(expr,ctx) -- (return [value...])
  local vals = {}
  for i = 2, #expr do
    vals[#vals+1] = compile(expr[i],ctx)
  end
  return VM.expr.RETURN(table.unpack(vals))
end
spec['values'] = function(expr,ctx) -- (values val1 val2 ...)
  local vals = {}
  for i=2,#expr do
    vals[#vals+1] = compile(expr[i],ctx)
  end
  return VM.expr.VALUES(table.unpack(vals))
end
spec['let'] = function(expr,ctx) -- (let ((var1 val1) (var2 val2)) . body)
  assert(#expr >= 2, "let requires bindings and body")
  local bindingList = expr[2]
  local bindings = {}
  for i,binding in ipairs(bindingList) do
    assert(type(binding) == 'table' and #binding == 2, "let binding must be (name value)")
    bindings[i] = {binding[1], compile(binding[2],ctx)}
  end
  local body = {}
  for i=3,#expr do
    body[#body+1] = compile(expr[i],ctx)
  end
  return VM.expr.LET(bindings, table.unpack(body))
end
spec['cond'] = function(expr,ctx) -- (cond (test1 expr1 ...) (test2 expr2 ...) ...)
  local clauses = {}
  for i=2,#expr do
    local clause = expr[i]
    assert(type(clause) == 'table' and #clause >= 1, "cond clause must have test and expressions")
    local compiled = {}
    for j=1,#clause do
      compiled[j] = compile(clause[j],ctx)
    end
    clauses[#clauses+1] = compiled
  end
  -- Don't unpack - COND expects individual clause tables as separate arguments
  return VM.expr.COND(table.unpack(clauses))
end
spec['and'] = function(expr,ctx) -- (and expr1 expr2 ...)
  local exprs = {}
  for i=2,#expr do
    exprs[#exprs+1] = compile(expr[i],ctx)
  end
  return VM.expr.AND(table.unpack(exprs))
end
spec['or'] = function(expr,ctx) -- (or expr1 expr2 ...)
  local exprs = {}
  for i=2,#expr do
    exprs[#exprs+1] = compile(expr[i],ctx)
  end
  return VM.expr.OR(table.unpack(exprs))
end
spec['not'] = function(expr,ctx) -- (not expr)
  assert(#expr == 2, "not requires exactly one argument")
  return VM.expr.NOT(compile(expr[2],ctx))
end
spec['list'] = function(expr,ctx) -- (list expr1 expr2 ...)
  local exprs = {}
  for i=2,#expr do
    exprs[#exprs+1] = compile(expr[i],ctx)
  end
  return VM.expr.LIST(table.unpack(exprs))
end
spec['cons'] = function(expr,ctx) -- (cons car cdr)
  assert(#expr == 3, "cons requires exactly two arguments")
  return VM.expr.CONS(compile(expr[2],ctx), compile(expr[3],ctx))
end
spec['car'] = function(expr,ctx) -- (car list)
  assert(#expr == 2, "car requires exactly one argument")
  return VM.expr.CAR(compile(expr[2],ctx))
end
spec['cdr'] = function(expr,ctx) -- (cdr list)
  assert(#expr == 2, "cdr requires exactly one argument")
  return VM.expr.CDR(compile(expr[2],ctx))
end
spec['null?'] = function(expr,ctx) -- (null? expr)
  assert(#expr == 2, "null? requires exactly one argument")
  return VM.expr.NULLP(compile(expr[2],ctx))
end
spec['catch'] = function(expr,ctx) -- (catch tag body...)
  assert(#expr >= 3, "catch requires at least tag and one body expression")
  local tag = compile(expr[2],ctx)
  local body = {}
  for i=3,#expr do
    body[#body+1] = compile(expr[i],ctx)
  end
  return VM.expr.CATCH(tag, table.unpack(body))
end
spec['throw'] = function(expr,ctx) -- (throw tag [value])
  assert(#expr >= 2 and #expr <= 3, "throw requires tag and optional value")
  local tag = compile(expr[2],ctx)
  local value = expr[3] and compile(expr[3],ctx) or VM.expr.NIL()
  return VM.expr.THROW(tag, value)
end
spec['create-coroutine'] = function(expr,ctx) -- (create-coroutine func)
  assert(#expr == 2, "create-coroutine requires exactly one argument (function)")
  return VM.expr.CREATE_COROUTINE(compile(expr[2],ctx))
end
spec['resume'] = function(expr,ctx) -- (resume coroutine [value...])
  assert(#expr >= 2, "resume requires at least coroutine argument")
  local co = compile(expr[2],ctx)
  local values = {}
  for i=3,#expr do
    values[#values+1] = compile(expr[i],ctx)
  end
  return VM.expr.RESUME(co, table.unpack(values))
end
spec['yield'] = function(expr,ctx) -- (yield [value...])
  local values = {}
  for i=2,#expr do
    values[#values+1] = compile(expr[i],ctx)
  end
  return VM.expr.YIELD(table.unpack(values))
end

function compile(expr,ctx)
  local typ = type(expr)
  if typ == 'table' then -- Call
    -- Attach source location to context
    local oldLine = ctx.line
    ctx.line = expr.__line or ctx.line
    
    if expr.__var then 
      return expr.VAR(expr)
    end
    -- Check if it's a string literal
    if getmetatable(expr) == stringMT then
      return VM.expr.CONST(expr.value)
    end
    if #expr == 0 then return VM.expr.CONST({}) end
    local op = expr[1]
    if spec[op] then
      return spec[op](expr, ctx) 
    elseif ctx.lisp.macro[op] then
      local expansion = ctx.lisp.macro[op](expr, ctx)
      return compile(expansion,ctx)
    end
    local fop,args = compile(op,ctx),{}
    for i=2,#expr do
      args[#args+1] = compile(expr[i],ctx)
    end
    local result = VM.expr.FUNCALL(fop,table.unpack(args))
    ctx.line = oldLine  -- Restore line
    return result
  elseif typ == 'number' then 
    return VM.expr.CONST(expr)
  elseif typ == 'boolean' then 
    if expr == false then
      return VM.expr.NIL()  -- false means nil in Lisp
    else
      return VM.expr.CONST(expr)  -- true stays true
    end
  elseif typ == 'string' then
    return VM.expr.VAR(expr)
  elseif typ == 'nil' then
    return VM.expr.NIL()
  else
    error("Unknown string expr: "..tostring(expr))
  end
end

-- Export Lisp constructor as global
_G.Lisp = Lisp