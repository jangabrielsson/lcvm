--%%offline:true
--%%file:ER/Tokenizer.lua,tokenizer
ER = ER or { _tools = {} }

--[[
Left-recursion eliminated grammar for Lua

block ::= {stat [';']} [laststat [';'] ]

stat ::= varlist '=' explist | 
         functioncall |
         do block end | 
         while exp do block end | 
         repeat block until exp | 
         if exp then block {elseif exp then block} [else block] end | 
         for Name '=' exp ',' exp [',' exp] do block end | 
         for namelist in explist do block end | 
         function funcname funcbody | 
         local function Name funcbody | 
         local namelist ['=' explist]

laststat ::= return [explist] | break

funcname ::= Name {'.' Name} [':' Name]

varlist ::= var {',' var}

namelist ::= Name {',' Name}

explist ::= exp {',' exp}

-- Expression with eliminated left recursion (handles binary operators)
exp ::= orexp

orexp ::= andexp {'or' andexp}

andexp ::= relexp {'and' relexp}

relexp ::= concatexp {relop concatexp}

relop ::= '<' | '<=' | '>' | '>=' | '==' | '~='

concatexp ::= addexp {'..' addexp}

addexp ::= mulexp {addop mulexp}

addop ::= '+' | '-'

mulexp ::= unaryexp {mulop unaryexp}

mulop ::= '*' | '/' | '%'

unaryexp ::= unop unaryexp | powexp

unop ::= '-' | 'not' | '#'

powexp ::= primaryexp ['^' unaryexp]

primaryexp ::= nil | false | true | Number | String | '...' | 
               function | tableconstructor | prefixexp

-- Prefix expressions with eliminated left recursion
prefixexp ::= primaryprefix {postfix}

primaryprefix ::= Name | '(' exp ')'

postfix ::= '[' exp ']' | '.' Name | args | ':' Name args

-- Variable is a prefixexp that doesn't end with args
var ::= Name {varpostfix}

varpostfix ::= '[' exp ']' | '.' Name

-- Function call is a prefixexp that ends with args
functioncall ::= primaryprefix {callpostfix} args
               | primaryprefix {callpostfix} ':' Name args

callpostfix ::= '[' exp ']' | '.' Name | args | ':' Name args

args ::= '(' [explist] ')' | tableconstructor | String

function ::= function funcbody

funcbody ::= '(' [parlist] ')' block end

parlist ::= namelist [',' '...'] | '...'

tableconstructor ::= '{' [fieldlist] '}'

fieldlist ::= field {fieldsep field} [fieldsep]

field ::= '[' exp ']' '=' exp | Name '=' exp | exp

fieldsep ::= ',' | ';'

--]]

local p_block,p_stat,p_expr,p_functioncall,p_exprlist,p_varlist,p_funcname,p_funcbody
local p_unaryexp, p_tableconstructor, p_prefixexp
local locals = {} -- used for tracking locals in p_block

local function parseError(tkns, msg, token)
  local t = token or tkns.peek()
  local ctx = tkns.ctxHint() or ""
  error(ctx .. msg .. tkns.sourceAt(t), 2)
end

-- args ::= '(' [explist] ')' | tableconstructor | String
local function p_args(tkns)
  local t = tkns.peek()
  if t and t.type == 'lpar' then
    tkns.next()
    local args = {}
    if tkns.peek().type ~= 'rpar' then
      args = p_exprlist(tkns)
    end
    tkns.expect('rpar')
    return args
  elseif t and t.type == 'lbra' then
    return { p_tableconstructor(tkns) }
  elseif t and t.type == 'string' then
    tkns.next()
    return { {type='literal', value=t.value} }
  end
  return nil
end

-- tableconstructor ::= '{' [fieldlist] '}'
-- field ::= '[' exp ']' '=' exp | Name '=' exp | exp
p_tableconstructor = function(tkns)
  tkns.expect('lbra')
  local fields = {}
  while tkns.peek() and tkns.peek().type ~= 'rbra' do
    local t = tkns.peek()
    local field
    if t.type == 'lbra' then  -- '[' exp ']' '=' exp  (lbra = '[')
      tkns.next()
      local key = p_expr(tkns)
      tkns.expect('rbra')
      tkns.expect('assign')
      local val = p_expr(tkns)
      field = {type='field', key=key, value=val}
    elseif t.type == 'identifier' and tkns.peek(2) and tkns.peek(2).type == 'assign' then
      local name = tkns.next().value
      tkns.match('assign')
      local val = p_expr(tkns)
      field = {type='field', key={type='literal',value=name}, value=val}
    else
      local val = p_expr(tkns)
      field = {type='field', value=val}
    end
    table.insert(fields, field)
    if not (tkns.match('comma') or tkns.match('semicolon')) then break end
  end
  tkns.expect('rbra')
  return {type='table', fields=fields}
end

-- primaryprefix ::= Name | '(' exp ')'
-- prefixexp ::= primaryprefix {postfix}
-- postfix ::= '[' exp ']' | '.' Name | args | ':' Name args
p_prefixexp = function(tkns)
  local t = tkns.peek()
  local node
  if t and t.type == 'identifier' then
    tkns.next()
    node = {type='variable', name=t.value, pos=t.pos, len=t.len}
  elseif t and t.type == 'lpar' then
    tkns.next()
    node = p_expr(tkns)
    tkns.expect('rpar')
    --node = {type='paren', expr=node}
  else
    return nil
  end
  -- postfix loop
  while true do
    local pt = tkns.peek()
    if not pt then break end
    if pt.type == 'lsqb' then        -- '[' exp ']'
      tkns.next()
      local idx = p_expr(tkns)
      tkns.expect('rsqb')
      node = {type='tableaccess', table=node, key=idx, pos=node.pos, len=node.len}
    elseif pt.type == 'dot' then     -- '.' Name
      tkns.next()
      local name = tkns.expect('identifier')
      node = {type='tableaccess', table=node, key=name.value, pos=node.pos, len=node.len}
    elseif pt.type == 'colon' then   -- ':' Name args
      tkns.next()
      local method = tkns.expect('identifier').value
      local args = p_args(tkns)
      node = {type='methodcall', object=node, method=method, args=args, pos=pt.pos, len=pt.len}
    else
      local args = p_args(tkns)
      if args then
        node = {type='call', func=node, args=args, pos=pt.pos, len=pt.len}
      else
        break
      end
    end
  end
  return node
end

-- primaryexp ::= nil | false | true | Number | String | '...' |
--                function funcbody | tableconstructor | prefixexp
local function p_primaryexp(tkns)
  local t = tkns.peek()
  if not t then parseError(tkns, "Unexpected end of input in expression") end
  if t.type == 'number' or t.type == 'string' or t.type == 'nil' or
     t.type == 'true' or t.type == 'false' then
    tkns.next()
    return {type=t.type, value=t.value, pos=t.pos, len=t.len}
  elseif t.type == 'vararg' then   -- '...'
    tkns.next()
    return {type='vararg'}
  elseif t.type == 'function' then
    tkns.next()
    return {type='function', body=p_funcbody(tkns)}
  elseif t.type == 'lbra' then
    return p_tableconstructor(tkns)
  else
    local node = p_prefixexp(tkns)
    if node then return node end
    parseError(tkns, "Unexpected token '" .. tkns.lookupTkType(t.type) .. "' in expression", t)
  end
end

-- powexp ::= primaryexp ['^' unaryexp]
local function p_powexp(tkns)
  local base = p_primaryexp(tkns)
  if tkns.peek() and tkns.peek().type == 'op' and tkns.peek().value == 'power' then
    tkns.next()
    local exp = p_unaryexp(tkns)
    return {type='binop', op='^', left=base, right=exp}
  end
  return base
end

-- unaryexp ::= unop unaryexp | powexp
-- unop ::= '-' | 'not' | '#'
p_unaryexp = function(tkns)
  local t = tkns.peek()
  if t and t.type == 'op' and (t.value == 'minus' or t.value == 'not' or t.value == 'len') then
    tkns.next()
    local operand = p_unaryexp(tkns)
    return {type='unop', op=t.value, operand=operand}
  end
  return p_powexp(tkns)
end

-- mulexp ::= unaryexp {mulop unaryexp}
-- mulop ::= '*' | '/' | '%'
local mulops = {multiply=true, divide=true, modulo=true}
local function p_mulexp(tkns)
  local left = p_unaryexp(tkns)
  while tkns.peek() and tkns.peek().type == 'op' and mulops[tkns.peek().value] do
    local op = tkns.next().value
    local right = p_unaryexp(tkns)
    left = {type='binop', op=op, left=left, right=right}
  end
  return left
end

-- addexp ::= mulexp {addop mulexp}
-- addop ::= '+' | '-'
local addops = {plus=true, minus=true}
local function p_addexp(tkns)
  local left = p_mulexp(tkns)
  while tkns.peek() and tkns.peek().type == 'op' and addops[tkns.peek().value] do
    local op = tkns.next().value
    local right = p_mulexp(tkns)
    left = {type='binop', op=op, left=left, right=right}
  end
  return left
end

-- concatexp ::= addexp {'..' addexp}
local function p_concatexp(tkns)
  local left = p_addexp(tkns)
  while tkns.peek() and tkns.peek().type == 'op' and tkns.peek().value == 'concat' do
    tkns.next()
    local right = p_addexp(tkns)
    -- '..' is right-associative, but simple left-fold is fine for AST building
    left = {type='binop', op='..', left=left, right=right}
  end
  return left
end

-- relexp ::= concatexp {relop concatexp}
-- relop ::= '<' | '<=' | '>' | '>=' | '==' | '~='
local relops = {less_than=true, less_equal=true, greater_than=true, greater_equal=true, equal=true, not_equal=true}
local function p_relexp(tkns)
  local left = p_concatexp(tkns)
  while tkns.peek() and tkns.peek().type == 'op' and relops[tkns.peek().value] do
    local op = tkns.next().value
    local right = p_concatexp(tkns)
    left = {type='binop', op=op, left=left, right=right}
  end
  return left
end

-- andexp ::= relexp {'and' relexp}
local function p_andexp(tkns)
  local left = p_relexp(tkns)
  while tkns.peek() and tkns.peek().type == 'op' and tkns.peek().value == 'and' do
    tkns.next()
    local right = p_relexp(tkns)
    left = {type='and', left=left, right=right}
  end
  return left
end

-- orexp ::= andexp {'or' andexp}
-- exp   ::= orexp
function p_expr(tkns)
  local left = p_andexp(tkns)
  while tkns.peek() and tkns.peek().type == 'op' and tkns.peek().value == 'or' do
    tkns.next()
    local right = p_andexp(tkns)
    left = {type='or', left=left, right=right}
  end
  return left
end

-- funcname ::= Name {'.' Name} [':' Name]
function p_funcname(tkns)
  local names = {}
  table.insert(names, tkns.expect('identifier').value)
  while tkns.match('dot') do
    table.insert(names, tkns.expect('identifier').value)
  end
  local methodName = nil
  if tkns.match('colon') then
    methodName = tkns.expect('identifier').value
  end
  return {type='funcname', names = names, method = methodName}
end

-- funcbody ::= '(' [parlist] ')' block end
-- parlist  ::= namelist [',' '...'] | '...'
function p_funcbody(tkns)
  tkns.pushCtx("function body")
  tkns.expect('lpar')
  local params = {}
  local hasVararg = false
  if tkns.peek() and tkns.peek().type ~= 'rpar' then
    if tkns.peek().type == 'vararg' then
      tkns.next()
      hasVararg = true
    else
      -- namelist
      params[#params+1] = tkns.expect('identifier').value
      while tkns.match('comma') do
        if tkns.peek().type == 'vararg' then
          tkns.next()
          hasVararg = true
          break
        end
        params[#params+1] = tkns.expect('identifier').value
      end
    end
  end
  tkns.expect('rpar')
  local body = p_block(tkns)
  tkns.expect('end')
  tkns.popCtx()
  return {type='funcbody', params=params, hasVararg=hasVararg, body=body}
end

function p_varlist(tkns)
  local vars = {}
  repeat
    local var = tkns.expect('identifier')
    table.insert(vars, var.value)
  until not tkns.match('comma')
  return vars
end

-- functioncall ::= primaryprefix {callpostfix} args
--                 | primaryprefix {callpostfix} ':' Name args
-- Since p_prefixexp already handles the full postfix chain (including calls),
-- we just parse a prefixexp and verify it ends with a call or methodcall.
p_functioncall = function(tkns)
  local node = p_prefixexp(tkns)
  if node == nil then
    error("Expected function call")
  end
  if node.type ~= 'call' and node.type ~= 'methodcall' then
    error("Expected function call, got: " .. tostring(node.type))
  end
  return node
end

function p_exprlist(tkns)
  local exprs = {}
  repeat
    local expr = p_expr(tkns)
    table.insert(exprs, expr)
  until not tkns.match('comma')
  return exprs
end

--[[ stat ::= varlist '=' explist | 
         functioncall |
         do block end | 
         while exp do block end | 
         repeat block until exp | 
         if exp then block {elseif exp then block} [else block] end | 
         for Name '=' exp ',' exp [',' exp] do block end | 
         for namelist in explist do block end | 
         function funcname funcbody | 
         local function Name funcbody | 
         local namelist ['=' explist]
--]]
function p_stat(tkns)
  local t = tkns.peek()
  if t.type == 'do' then
    tkns.pushCtx("do block")
    tkns.next()
    local block = p_block(tkns)
    tkns.expect('end')
    tkns.popCtx()
    return {type='do', body=block}
  elseif t.type == 'loop' then
    tkns.pushCtx("loop")
    tkns.next()
    local block = p_block(tkns)
    tkns.expect('end')
    tkns.popCtx()
    return {type='loop', body=block}
  elseif t.type == 'while' then
    tkns.pushCtx("while loop")
    tkns.next()
    local test = p_expr(tkns)
    tkns.expect('do')
    local body = p_block(tkns)
    tkns.expect('end')
    tkns.popCtx()
    return {type='while', test=test, body=body}
  elseif t.type == 'repeat' then
    tkns.pushCtx("repeat/until")
    tkns.next()
    local body = p_block(tkns)
    tkns.expect('until')
    local test = p_expr(tkns)
    tkns.popCtx()
    return {type='repeat', test=test, body=body}
  elseif t.type == 'if' then
    tkns.pushCtx("if statement")
    tkns.next()
    local test = p_expr(tkns)
    tkns.expect('then')
    local body = p_block(tkns)
    local elseifs = {}
    local elsebody = nil
    while tkns.peek() and tkns.peek().type == 'elseif' do
      tkns.next()
      local etest = p_expr(tkns)
      tkns.expect('then')
      local ebody = p_block(tkns)
      table.insert(elseifs, {test=etest, body=ebody})
    end
    if tkns.match('else') then
      elsebody = p_block(tkns)
    end
    tkns.expect('end')
    tkns.popCtx()
    return {type='if', test=test, body=body, elseifs=elseifs, else_body=elsebody}
  elseif t.type == 'for' then
    tkns.pushCtx("for loop")
    tkns.next()
    local firstName = tkns.expect('identifier').value
    if tkns.match('assign') then
      -- Numeric for: for Name '=' exp ',' exp [',' exp] do block end
      local start = p_expr(tkns)
      tkns.expect('comma')
      local limit = p_expr(tkns)
      local step = nil
      if tkns.match('comma') then
        step = p_expr(tkns)
      end
      tkns.expect('do')
      local body = p_block(tkns)
      tkns.expect('end')
      tkns.popCtx()
      return {type='for_numeric', var=firstName, start=start, limit=limit, step=step, body=body}
    else
      -- Generic for: for namelist in explist do block end
      local names = {firstName}
      while tkns.match('comma') do
        names[#names+1] = tkns.expect('identifier').value
      end
      tkns.expect('in')
      local explist = p_exprlist(tkns)
      tkns.expect('do')
      local body = p_block(tkns)
      tkns.expect('end')
      tkns.popCtx()
      return {type='for_generic', names=names, explist=explist, body=body}
    end
  elseif t.type == 'function' then
    tkns.pushCtx("function definition")
    tkns.next()
    local funcname = p_funcname(tkns)
    local funcbody = p_funcbody(tkns)
    tkns.popCtx()
    return {type='functiondef', name=funcname, body=funcbody}
  elseif t.type == 'local' then
    tkns.next()
    if tkns.peek().type == 'function' then
      -- local function Name funcbody
      tkns.pushCtx("local function")
      tkns.next()
      local name = tkns.expect('identifier').value
      local body = p_funcbody(tkns)
      table.insert(locals, name)
      tkns.popCtx()
      return {type='localfunc', name=name, body=body}
    else
      tkns.pushCtx("local declaration")
      local varlist = p_varlist(tkns)
      for _,var in ipairs(varlist) do
        table.insert(locals, var)
      end
      local explist = {}
      if tkns.match('assign') then
        explist = p_exprlist(tkns)
      end
      tkns.popCtx()
      return {type='assign', vars=varlist, exprs=explist}
    end
  elseif t.type == 'identifier' then
    -- Parse first expression as a prefixexp to handle a, a.b, a[i], a(args) etc.
    local first = p_prefixexp(tkns)
    local nt = tkns.peek()
    if nt and (nt.type == 'comma' or nt.type == 'assign') then
      -- varlist '=' explist  (LHS can be var, field index, array index)
      tkns.pushCtx("assignment")
      local lvalues = {first}
      while tkns.match('comma') do
        local lv = p_prefixexp(tkns)
        if lv.type == 'call' or lv.type == 'methodcall' then
          parseError(tkns, "Invalid assignment target", nt)
        end
        table.insert(lvalues, lv)
      end
      tkns.expect('assign')
      local explist = p_exprlist(tkns)
      tkns.popCtx()
      return {type='assign', vars=lvalues, exprs=explist}
    else
      -- functioncall: must end with a call or methodcall
      if first.type ~= 'call' and first.type ~= 'methodcall' then
        parseError(tkns, "Expected function call or assignment, got '" .. tostring(first.type) .. "'", nt)
      end
      return first
    end
  end
  parseError(tkns, "Unexpected token '" .. tkns.lookupTkType(t.type) .. "' in statement", t)
end


-- block ::= {stat [';']} [laststat [';'] ]

local blockStop = {['end']=true, ['else']=true, ['elseif']=true, ['until']=true, ['return']=true}

function p_block(tkns)
  local stats = {}
  oldLocals = locals
  locals = {}
  while tkns.peek() and not blockStop[tkns.peek().type] do
    local pt = tkns.peek()
    local stat = p_stat(tkns)
    if stat then table.insert(stats, stat)
    else parseError(tkns, "Unexpected token '" .. tostring(pt and tkns.lookupTkType(pt.type) or "<unknown>") .. "' in block", pt) end
    tkns.match('semicolon')
  end
  if tkns.match('return') then
    local t = tkns.peek()
    local exprlist = {}
    if t and not blockStop[t.type] and t.type ~= 'semicolon' then
      exprlist = p_exprlist(tkns)
    end
    table.insert(stats, {type='return', exprs=exprlist})
    tkns.match('semicolon')
  end
  local nlocals = locals
  locals = oldLocals
  return {type='statements',locals = nlocals, statements=stats}
end

local function parser(str)
  local tokenizer = ER._tools.tokenStream
  local tkns = tokenizer(str)
  return p_block(tkns)
end

ER._tools.parser = parser