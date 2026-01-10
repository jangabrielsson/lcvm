--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing MAKE-TABLE with Initial Values ===\n")

-- Test 1: Empty table (original behavior)
local empty = lisp:eval("(make-table)")
print("Test 1: (make-table) creates empty table")
assert(type(empty) == "table", "Should create a table")
local count = 0
for _ in pairs(empty) do count = count + 1 end
assert(count == 0, "Should be empty")
print("✓ Empty table works\n")

-- Test 2: Table with string key-value pairs
lisp:eval('(setq dict (make-table "name" "Bob" "age" 25))')
local name = lisp:eval('(aref dict "name")')
local age = lisp:eval('(aref dict "age")')
print("Test 2: (make-table \"name\" \"Bob\" \"age\" 25)")
print("        (aref dict \"name\") = " .. tostring(name) .. ' (expected "Bob")')
print("        (aref dict \"age\") = " .. tostring(age) .. " (expected 25)")
assert(name == "Bob" and age == 25, "String keys should work")
print("✓ String key-value pairs work\n")

-- Test 3: Table with numeric keys
lisp:eval("(setq arr (make-table 1 100 2 200 3 300))")
local v1 = lisp:eval("(aref arr 1)")
local v2 = lisp:eval("(aref arr 2)")
local v3 = lisp:eval("(aref arr 3)")
print("Test 3: (make-table 1 100 2 200 3 300)")
print("        Values: " .. v1 .. ", " .. v2 .. ", " .. v3)
assert(v1 == 100 and v2 == 200 and v3 == 300, "Numeric keys should work")
print("✓ Numeric key-value pairs work\n")

-- Test 4: Mixed key types
lisp:eval('(setq mixed (make-table "id" 42 1 "first" 2 "second"))')
local id = lisp:eval('(aref mixed "id")')
local first = lisp:eval("(aref mixed 1)")
local second = lisp:eval("(aref mixed 2)")
print("Test 4: Mixed string and numeric keys")
print("        id=" .. tostring(id) .. ", 1=" .. tostring(first) .. ", 2=" .. tostring(second))
assert(id == 42 and first == "first" and second == "second", "Mixed keys should work")
print("✓ Mixed key types work\n")

-- Test 5: Keys and values from expressions
lisp:eval("(setq key-expr (make-table (+ 1 2) (* 10 5) (+ 2 2) (* 3 3)))")
local val3 = lisp:eval("(aref key-expr 3)")
local val4 = lisp:eval("(aref key-expr 4)")
print("Test 5: Keys and values from expressions")
print("        (aref key-expr 3) = " .. tostring(val3) .. " (expected 50)")
print("        (aref key-expr 4) = " .. tostring(val4) .. " (expected 9)")
assert(val3 == 50 and val4 == 9, "Expression evaluation should work")
print("✓ Expression keys and values work\n")

-- Test 6: Use in function
lisp:eval([[
  (defun make-person (name age)
    (make-table "name" name "age" age))
]])
lisp:eval('(setq person (make-person "Alice" 30))')
local pname = lisp:eval('(aref person "name")')
local page = lisp:eval('(aref person "age")')
print("Test 6: make-table in function")
print("        person.name = " .. tostring(pname) .. ", person.age = " .. tostring(page))
assert(pname == "Alice" and page == 30, "Should work in function")
print("✓ Works in user-defined functions\n")

-- Test 7: Modify after creation
lisp:eval('(setq obj (make-table "x" 10 "y" 20))')
lisp:eval('(aset obj "z" 30)')
local x = lisp:eval('(aref obj "x")')
local y = lisp:eval('(aref obj "y")')
local z = lisp:eval('(aref obj "z")')
print("Test 7: Modify table after creation")
print("        x=" .. x .. ", y=" .. y .. ", z=" .. z)
assert(x == 10 and y == 20 and z == 30, "Should be modifiable")
print("✓ Table is modifiable after creation\n")

-- Test 8: Single key-value pair
lisp:eval('(setq single (make-table "solo" "value"))')
local solo = lisp:eval('(aref single "solo")')
print("Test 8: Single key-value pair")
print("        solo = " .. tostring(solo))
assert(solo == "value", "Single pair should work")
print("✓ Single key-value pair works\n")

print("✓ All MAKE-TABLE enhancement tests passed!")
