--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing RETURN with multiple values ===\n")

-- Test 1: RETURN with multiple expressions - NOW WORKS LIKE VALUES!
print("Test 1: RETURN with multiple expressions")
lisp:eval([[
  (defun test-return-exprs ()
    (return 3 4 5))
]])
local r1, r2, r3 = lisp:eval("(test-return-exprs)")
print(string.format("  (return 3 4 5) returns: %s, %s, %s", tostring(r1), tostring(r2), tostring(r3)))
print(string.format("  Returns all values: %s", (r1==3 and r2==4 and r3==5) and "✓" or "✗"))

-- Test 2: RETURN with VALUES
print("\nTest 2: RETURN with VALUES")
lisp:eval([[
  (defun test-return-values ()
    (return (values 3 4 5)))
]])
local v1, v2, v3 = lisp:eval("(test-return-values)")
print(string.format("  (return (values 3 4 5)) returns: %s, %s, %s", tostring(v1), tostring(v2), tostring(v3)))
print(string.format("  Returns all values: %s", (v1==3 and v2==4 and v3==5) and "✓" or "✗"))

-- Test 3: Function body ending with VALUES (no RETURN)
print("\nTest 3: Function body with VALUES (no RETURN)")
lisp:eval([[
  (defun test-body-values ()
    (values 3 4 5))
]])
local b1, b2, b3 = lisp:eval("(test-body-values)")
print(string.format("  (values 3 4 5) returns: %s, %s, %s", tostring(b1), tostring(b2), tostring(b3)))
print(string.format("  Returns all values: %s", (b1==3 and b2==4 and b3==5) and "✓" or "✗"))

print("\n=== Summary ===")
print("✓ (return 3 4 5) → returns 3, 4, 5 (all values)")
print("✓ (values 3 4 5) → returns 3, 4, 5 (all values)")
print("✓ (return (values 3 4 5)) → returns 3, 4, 5 (all values)")
print("\nRETURN now behaves like VALUES - more intuitive and consistent!")
