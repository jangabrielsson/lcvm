--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing PROGN with multiple values ===\n")

-- Test 1: PROGN with multiple expressions, last returns multiple values
print("Test 1: PROGN's last expression returns multiple values")
local a, b, c = lisp:eval([[
  (progn 
    (setq x 100)
    (values 1 2 3))
]])
print(string.format("  Result: %s, %s, %s", tostring(a), tostring(b), tostring(c)))

-- Test 2: Multiple expressions at top level (implicit PROGN)
print("\nTest 2: Top-level multiple expressions")
local d, e, f = lisp:eval([[
  (setq y 200)
  (values 4 5 6)
]])
print(string.format("  Result: %s, %s, %s", tostring(d), tostring(e), tostring(f)))

-- Test 3: With RESUME
print("\nTest 3: With RESUME in PROGN")
lisp:eval("(setq co (create-coroutine (lambda () (yield 7 8 9) 100)))")
local g, h, i, j = lisp:eval([[
  (setq dummy 300)
  (resume co)
]])
print(string.format("  Result: %s, %s, %s, %s", tostring(g), tostring(h), tostring(i), tostring(j)))
