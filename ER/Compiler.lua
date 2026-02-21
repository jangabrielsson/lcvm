ER = ER or { _tools = {} }

local unpack = table.unpack
local EXPR,cast
local compile

local comp = {}

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

local consts = { ['number']=true, ['string']=true, ['literal']=true, ['boolean']=true}
local function keyValue(key)
  if type(key) ~= 'table' then return EXPR.CONST(key) end
  if consts[key.type] then return compile(key) end
  error("Unsupported key type: "..tostring(key.type))
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
      error("Unsupported assignment target type: "..tostring(var.type))
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
  return EXPR.AREF(tab, key)
end

comp['return'] = function(node)
  local exprs = {}
  for _,expr in ipairs(node.exprs) do
    exprs[#exprs+1] = compile(expr)
  end
  return EXPR.RETURN(table.unpack(exprs))
end

local opmap = {
  ['plus'] = '+',
  ['minus'] = '-',
  ['multiply'] = '*',
  ['divide'] = '/',
}

function comp.binop(node)
  local left = compile(node.left)
  local right = compile(node.right)
  local op = opmap[node.op]
  if not op then error("Unknown binary operator: "..tostring(node.op)) end
  return EXPR.BINOP(op, left, right)
end

function comp.unop(node)
  local operand = compile(node.operand)
  local op = opmap[node.op]
  if not op then error("Unknown unary operator: "..tostring(node.op)) end
  return EXPR.UNOP(op, operand)
end

function comp.variable(node)
  return EXPR.VAR(node.name)
end

function comp.call(node)
  local func = compile(node.func)
  local args = {}
  for _,arg in ipairs(node.args) do
    args[#args+1] = compile(arg)
  end
  return EXPR.FUNCALL(func, unpack(args))
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

function compile(ast)
  if comp[ast.type] then 
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