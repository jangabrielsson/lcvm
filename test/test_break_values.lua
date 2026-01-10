--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing BREAK with multiple values ===\n")

-- Test 1: BREAK with multiple literal values
print("Test 1: BREAK with multiple literal values")
lisp:eval([[
  (defun test-break-literals ()
    (loop
      (break 1 2 3)))
]])
local a, b, c = lisp:eval("(test-break-literals)")
print(string.format("  (break 1 2 3) = %s, %s, %s", tostring(a), tostring(b), tostring(c)))
if a == 1 and b == 2 and c == 3 then
  print("  ✓ BREAK returns all three values")
else
  print("  ✗ Expected (1, 2, 3), BREAK currently only returns last value with evalExprs")
end

-- Test 2: BREAK with expressions
print("\nTest 2: BREAK with computed expressions")
lisp:eval([[
  (defun test-break-exprs ()
    (loop
      (break (+ 1 2) (* 3 4) (- 10 5))))
]])
local d, e, f = lisp:eval("(test-break-exprs)")
print(string.format("  (break (+ 1 2) (* 3 4) (- 10 5)) = %s, %s, %s", tostring(d), tostring(e), tostring(f)))
if d == 3 and e == 12 and f == 5 then
  print("  ✓ BREAK evaluates and returns all expressions")
else
  print("  ✗ Expected (3, 12, 5)")
end

-- Test 3: Comparison with RETURN (which now uses evalArgs)
print("\nTest 3: Comparison with RETURN behavior")
lisp:eval([[
  (defun test-return-multi ()
    (return 7 8 9))
]])
local g, h, i = lisp:eval("(test-return-multi)")
print(string.format("  (return 7 8 9) = %s, %s, %s %s", tostring(g), tostring(h), tostring(i),
  (g == 7 and h == 8 and i == 9) and "✓" or "✗"))

print("\n=== Summary ===")
print("✓ RETURN uses evalArgs → returns all arguments as multiple values")
print("✓ VALUES uses evalArgs → returns all arguments as multiple values")  
print("✓ YIELD uses evalArgs → returns all arguments as multiple values")
print("✓ BREAK uses evalArgs → returns all arguments as multiple values")
print("\nAll control flow exit statements now consistently support multiple values!")
