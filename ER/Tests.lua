--%%offline:true
--%%file:Continuation.lua,continuation 
--%%file:ER/Tokenizer.lua,tokenizer
--%%file:ER/Parser.lua,parser
--%%file:ER/Compiler.lua,compiler
ER = ER or { _tools = {} }

local test1 = true
local test2 = true
local test3 = true

local parser,compile

local function equal(e1,e2)
  if e1==e2 then return true
  else
    if type(e1) ~= 'table' or type(e2) ~= 'table' then return false
    else
      for k1,v1 in pairs(e1) do if e2[k1] == nil or not equal(v1,e2[k1]) then return false end end
      for k2,_  in pairs(e2) do if e1[k2] == nil then return false end end
      return true
    end
  end
end

function QuickApp:onInit()
  self:debug("Running tests...")
  parser = ER._tools.parser
  compile = ER._tools.compile
  if test1 then self:test1() end
end

local function compute(str)
  local ast = parser(str)
  local code = compile(ast)
  local res = nil
  
  --print(json.encodeFormated(ast))
  -- Create environment
  local env = VM.createEnvironment()
  function env.nonVarHandler(name) return _G[name] end
  -- Execute
  local ok, err, steps = VM.execute(
  code,
  function(...) 
    --print("RES:",...)
    res = {...}
    return nil 
  end,
  env,
  {debug=false}
)
  if not ok then
    error("Execution error: "..tostring(err))
  end
  return res
end

function QuickApp:test1()
  
  function foo(x) return x+1 end
  local tests = {
    {"return 1 + 2", {3}},
    {"return 10 - 4", {6}},
    {"return 5 * 6", {30}},
    {"return 20 / 4", {5}},
    {"return (1 + 2) * 3", {9}},
    {"return 10 / (2 + 3)", {2}},
    {"x = 10; y = 20; return x + y", {30}},
    {"x, y = 10, 20; return x + y", {30}},
    {"x, y = 10, 20; return x * y", {200}},
    {"x, y = 10, 20; return x / y", {0.5}},
    {"x, y = 10, 20; return (x + y) * (x - y)", {-300}},
    {"x, y = 10, 20; return (x * y) / (x + y)", {(10*20)/30}},
    {"x, y = 10, 20; return (x + y) / (x * y)", {(10+20)/(10*20)}},
    {"x, y = 10, 20; return x + y * x - y / x", {10 + (20*10) - (20/10)}},
    {"x, y = 10, 20; return (x + y) * (x - y) / x", {((10+20)*(10-20))/10}},
    {"x, y = 10, 20; return (x * y) / (y - x)", {((10*20)/(20-10))}},
    {"x, y = 10, 20; return (x + -y) / (y + x)", {((10+ -20)/(20+10))}},
    {"return foo(5)", {6}},
    {"return foo(10) + foo(20)", {32}},
    {"return foo(foo(5))", {7}},
    {"return foo(foo(foo(5)))", {8}},
    {"return foo(foo(foo(foo(5))))", {9}},
    {"return 17,42",{17,42}},
    {"return {3}", {{3}}},
    {"return {x=3}", {{x=3}}},
    {"local a = {x=3}; a.x=4; return a.x", {4}},
    {"local a = {3}; a[1]=4; return a[1]", {4}},
    {[[local a = {d=42}; a['d']=4; return a['d']], {4}},
    {'return "abc"', {"abc"}},
    -- Add more complex expressions as needed
  }
  for _,test in ipairs(tests) do
    local code, expected = test[1], test[2]
    local result = compute(code)
    if not equal(result,expected) then
      print("\27[31m[X]\27[0m", code)
      print("Expected:", expected[1], "Got:", table.unpack(result))
    else
      print("\27[32m[✓]\27[0m", code)
    end
  end
end