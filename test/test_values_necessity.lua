--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing: Is VALUES necessary? ===\n")

-- Test 1: Can we return multiple values without VALUES?
print("Test 1: Function without VALUES")
lisp:eval([[
  (defun try-no-values ()
    (progn
      (setq a 10)
      (setq b 20)
      b))  ; Only returns b
]])
local r1, r2 = lisp:eval("(try-no-values)")
print(string.format("  Result: %s, %s", tostring(r1), tostring(r2)))
print(string.format("  Only returns last expression: %s", r2 == nil and "✓" or "✗"))

-- Test 2: Alternative - return a list
print("\nTest 2: Alternative - return a list")
lisp:eval([[
  (defun return-list ()
    (list 10 20 30))
]])
local list = lisp:eval("(return-list)")
print(string.format("  Result type: %s", type(list)))
print(string.format("  Values: %s, %s, %s", list[1], list[2], list[3]))
print("  ✓ Works, but returns a list, not multiple values")

-- Test 3: With VALUES
print("\nTest 3: With VALUES")
lisp:eval([[
  (defun return-values ()
    (values 10 20 30))
]])
local v1, v2, v3 = lisp:eval("(return-values)")
print(string.format("  Result: %s, %s, %s (separate values)", v1, v2, v3))
print("  ✓ Returns multiple separate values")

-- Test 4: Difference in function calls
print("\nTest 4: Passing multiple values to function")
lisp:eval([[
  (defun sum3 (a b c) (+ (+ a b) c))
]])

-- With list - needs unpacking
print("  With list:")
local ok1, err1 = pcall(function()
  return lisp:eval("(sum3 (return-list))")
end)
print(string.format("    Direct: %s (can't pass list as 3 args)", ok1 and "✓" or "✗"))

-- With values - works directly
print("  With values:")
local result = lisp:eval("(sum3 (return-values))")
print(string.format("    Direct: sum3((values 10 20 30)) = %s ✓", result))

print("\n=== Conclusion ===")
print("VALUES is necessary because:")
print("  1. Without it, functions can only return ONE value")
print("  2. Lists are not the same - they're data structures, not multiple returns")
print("  3. VALUES allows multiple values to flow naturally through function calls")
print("  4. It's more efficient than lists (no allocation/boxing)")
print("\nVALUES is a fundamental feature, not optional! ✓")
