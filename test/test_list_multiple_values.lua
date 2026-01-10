--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing LIST with Multiple Values ===\n")

-- Test function that returns multiple values
lisp:eval("(defun multi () (values 1 2 3))")

-- Test 1: Does (list (multi)) capture all three values?
local result = lisp:eval("(list (multi))")
print("Test 1: (list (multi)) where multi returns (values 1 2 3)")
print("Result type:", type(result))
if type(result) == "table" then
  print("Result length:", #result)
  print("Result contents:", table.concat(result, ", "))
  assert(#result == 3, "Expected 3 values in list")
  assert(result[1] == 1 and result[2] == 2 and result[3] == 3, "Expected [1, 2, 3]")
  print("✓ All three values captured!\n")
else
  print("✗ Result is not a table\n")
end

-- Test 2: Multiple expressions - only LAST captures multiple values
lisp:eval("(defun duo () (values 10 20))")
local result2 = lisp:eval("(list (duo) (multi))")
print("Test 2: (list (duo) (multi)) where duo returns 10,20 and multi returns 1,2,3")
if type(result2) == "table" then
  print("Result length:", #result2)
  print("Result contents:", table.concat(result2, ", "))
  -- evalArgs captures only first value from each arg except the last
  -- So: 10 (first from duo), 1, 2, 3 (all from multi - it's last)
  assert(#result2 == 4, "Expected 4 values: 10 from duo, then 1,2,3 from multi")
  assert(result2[1] == 10, "First should be 10 from duo")
  assert(result2[2] == 1 and result2[3] == 2 and result2[4] == 3, "Rest from multi")
  print("✓ Captures first value from duo, all values from multi (last arg)\n")
end

-- Test 3: Nested scenario
lisp:eval("(defun get-coords () (values 100 200))")
local result3 = lisp:eval("(car (list (get-coords)))")
print("Test 3: (car (list (get-coords))) where get-coords returns 100,200")
print("Result:", result3)
assert(result3 == 100, "Expected first value (100)")
print("✓ First value extracted correctly!\n")

-- Test 4: Compare with explicit values
local result4 = lisp:eval("(list 1 2 3)")
local result5 = lisp:eval("(list (values 1 2 3))")
print("Test 4: Comparing (list 1 2 3) vs (list (values 1 2 3))")
print("(list 1 2 3):", table.concat(result4, ", "))
print("(list (values 1 2 3)):", table.concat(result5, ", "))
assert(#result4 == #result5, "Lengths should match")
print("✓ Both produce same result!\n")

print("✓ All tests passed! (list (fopp)) DOES capture multiple values into a list!")
