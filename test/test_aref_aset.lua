--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing AREF and ASET ===\n")

-- Test 1: Create a table and set values
lisp:eval("(setq tbl (list 1 2 3))")
print("Test 1: Create table (list 1 2 3)")

-- Test 2: AREF to get values by index
local v1 = lisp:eval("(aref tbl 1)")
local v2 = lisp:eval("(aref tbl 2)")
local v3 = lisp:eval("(aref tbl 3)")
print("Test 2: (aref tbl 1) = " .. tostring(v1) .. " (expected 1)")
print("        (aref tbl 2) = " .. tostring(v2) .. " (expected 2)")
print("        (aref tbl 3) = " .. tostring(v3) .. " (expected 3)")
assert(v1 == 1 and v2 == 2 and v3 == 3, "AREF read values")
print("✓ AREF works for numeric indices\n")

-- Test 3: ASET to modify values
lisp:eval("(aset tbl 2 99)")
local v2_new = lisp:eval("(aref tbl 2)")
print("Test 3: (aset tbl 2 99)")
print("        (aref tbl 2) = " .. tostring(v2_new) .. " (expected 99)")
assert(v2_new == 99, "ASET modified value")
print("✓ ASET works for numeric indices\n")

-- Test 4: ASET returns the value that was set
local ret = lisp:eval("(aset tbl 3 77)")
print("Test 4: (aset tbl 3 77) returns " .. tostring(ret) .. " (expected 77)")
assert(ret == 77, "ASET returns value")
print("✓ ASET returns the value that was set\n")

-- Test 5: String keys (associative array)
lisp:eval("(setq dict (make-table))")  -- Empty table
lisp:eval('(aset dict "name" "Alice")')
lisp:eval('(aset dict "age" 30)')
local name = lisp:eval('(aref dict "name")')
local age = lisp:eval('(aref dict "age")')
print("Test 5: Using string keys")
print('        (aref dict "name") = ' .. tostring(name) .. ' (expected "Alice")')
print('        (aref dict "age") = ' .. tostring(age) .. " (expected 30)")
assert(name == "Alice" and age == 30, "String keys work")
print("✓ AREF/ASET work with string keys\n")

-- Test 6: Accessing non-existent key returns nil (false in Lisp)
local missing = lisp:eval('(aref dict "missing")')
print('Test 6: (aref dict "missing") = ' .. tostring(missing) .. " (expected false)")
print("        type(missing) = " .. type(missing))
print("        missing == false:", missing == false)
print("        missing == nil:", missing == nil)
assert(missing == false or missing == nil, "Missing key returns false or nil")
print("✓ Missing keys return false/nil\n")

-- Test 7: Nested access
lisp:eval("(setq nested (make-table))")
lisp:eval('(aset nested "inner" (list 10 20 30))')
local inner = lisp:eval('(aref nested "inner")')
local inner_val = lisp:eval('(aref (aref nested "inner") 2)')
print("Test 7: Nested table access")
print('        (aref (aref nested "inner") 2) = ' .. tostring(inner_val) .. " (expected 20)")
assert(inner_val == 20, "Nested access works")
print("✓ Nested AREF works\n")

-- Test 8: Use in function
lisp:eval([[
  (defun get-prop (obj key)
    (aref obj key))
]])
lisp:eval("(setq obj (make-table))")
lisp:eval('(aset obj "color" "blue")')
local color = lisp:eval('(get-prop obj "color")')
print("Test 8: AREF in function")
print('        (get-prop obj "color") = ' .. tostring(color) .. ' (expected "blue")')
assert(color == "blue", "AREF works in function")
print("✓ AREF works in user-defined functions\n")

-- Test 9: Use in loop
lisp:eval([[
  (defun sum-table (tbl)
    (setq i 1)
    (setq sum 0)
    (loop
      (if (> i 3) (break sum))
      (setq sum (+ sum (aref tbl i)))
      (setq i (+ i 1))))
]])
lisp:eval("(setq nums (list 5 10 15))")
local sum = lisp:eval("(sum-table nums)")
print("Test 9: AREF in loop")
print("        (sum-table nums) = " .. tostring(sum) .. " (expected 30)")
assert(sum == 30, "AREF works in loop")
print("✓ AREF works in loops\n")

-- Test 10: ASET with expression as value
lisp:eval("(setq arr (list 1 2 3))")
lisp:eval("(aset arr 1 (+ 10 20))")
local val = lisp:eval("(aref arr 1)")
print("Test 10: ASET with expression")
print("        (aset arr 1 (+ 10 20)) then (aref arr 1) = " .. tostring(val) .. " (expected 30)")
assert(val == 30, "ASET evaluates value expression")
print("✓ ASET evaluates value expressions\n")

print("✓ All AREF/ASET tests passed!")
