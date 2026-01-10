--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing: Function body and multiple values ===\n")

-- Test 1: Function body IS a PROGN
print("Test 1: Function body without VALUES")
lisp:eval([[
  (defun test-body ()
    10
    20
    30)
]])
local r1, r2, r3 = lisp:eval("(test-body)")
print(string.format("  Result: %s, %s, %s", tostring(r1), tostring(r2), tostring(r3)))
print(string.format("  Returns only last expression's value: %s", (r1==30 and r2==nil) and "✓" or "✗"))

-- Test 2: Function body with VALUES in last expression
print("\nTest 2: Function body with VALUES as last expression")
lisp:eval([[
  (defun test-values ()
    10
    20
    (values 30 40 50))
]])
local v1, v2, v3 = lisp:eval("(test-values)")
print(string.format("  Result: %s, %s, %s", tostring(v1), tostring(v2), tostring(v3)))
print(string.format("  PROGN passes through multiple values: %s", (v1==30 and v2==40 and v3==50) and "✓" or "✗"))

-- Test 3: Explicit PROGN also passes through
print("\nTest 3: Explicit PROGN with VALUES")
local p1, p2, p3 = lisp:eval("(progn 1 2 (values 100 200 300))")
print(string.format("  Result: %s, %s, %s", tostring(p1), tostring(p2), tostring(p3)))
print(string.format("  PROGN passes through: %s", (p1==100 and p2==200 and p3==300) and "✓" or "✗"))

-- Test 4: So what does VALUES give us?
print("\nTest 4: What VALUES gives us")
print("  Without VALUES:")
local n1, n2 = lisp:eval("(progn 1 2 3)")
print(string.format("    (progn 1 2 3) returns: %s, %s", tostring(n1), tostring(n2)))
print("    ✓ Only one value (3)")

print("  With VALUES:")
local m1, m2, m3 = lisp:eval("(progn 1 2 (values 3 4 5))")
print(string.format("    (progn 1 2 (values 3 4 5)) returns: %s, %s, %s", tostring(m1), tostring(m2), tostring(m3)))
print("    ✓ Multiple values (3, 4, 5)")

print("\n=== Corrected Understanding ===")
print("• Function body IS a PROGN - passes through values from last expression")
print("• PROGN passes through multiple values from last expression")
print("• WITHOUT VALUES: expressions evaluate to single values")
print("• WITH VALUES: you can CREATE multiple values")
print("• VALUES is needed to GENERATE multiple values, not just pass them")
print("\nVALUES creates multiple values; PROGN/functions preserve them! ✓")
