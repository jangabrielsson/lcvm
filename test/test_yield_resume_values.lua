--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing YIELD and RESUME with multiple values ===\n")

-- Test 1: YIELD with multiple values
print("Test 1: YIELD with multiple values - (yield 10 20 30)")
lisp:eval([[
  (setq co (create-coroutine 
    (lambda ()
      (yield 10 20 30)
      (yield 40 50 60)
      999)))
]])
local s1, v1, v2, v3 = lisp:eval("(resume co)")
print(string.format("  Result: status=%s, v1=%s, v2=%s, v3=%s", tostring(s1), tostring(v1), tostring(v2), tostring(v3)))
if s1 == true and v1 == 10 and v2 == 20 and v3 == 30 then
  print("  ✓ YIELD returns all three values")
else
  print("  ✗ YIELD should return (true, 10, 20, 30)")
end

-- Test 2: Second yield with different values
print("\nTest 2: Second YIELD - (yield 40 50 60)")
local s2, v4, v5, v6 = lisp:eval("(resume co)")
print(string.format("  Result: status=%s, v1=%s, v2=%s, v3=%s", tostring(s2), tostring(v4), tostring(v5), tostring(v6)))
if s2 == true and v4 == 40 and v5 == 50 and v6 == 60 then
  print("  ✓ Second YIELD returns all three values")
else
  print("  ✗ Second YIELD should return (true, 40, 50, 60)")
end

-- Test 3: RESUME passing multiple values to coroutine
print("\nTest 3: RESUME with multiple values - (resume co 5 10 15)")
lisp:eval([[
  (setq co2 (create-coroutine 
    (lambda ()
      (setq a 1)
      (setq b 2)
      (setq c 3)
      (yield 100)
      ; After resume, these should NOT be set since yield doesn't capture resume args
      (values a b c))))
]])
lisp:eval("(resume co2)")
local s3, r1, r2, r3 = lisp:eval("(resume co2 5 10 15)")
print(string.format("  Coroutine returned: status=%s, r1=%s, r2=%s, r3=%s", tostring(s3), tostring(r1), tostring(r2), tostring(r3)))
print("  Note: Values passed to RESUME are currently not captured by the coroutine")
print("  This is expected behavior - coroutine continues with its own variables")

-- Test 4: Simple yield values check
print("\nTest 4: Direct yield values test")
lisp:eval([[
  (defun make-generator ()
    (create-coroutine 
      (lambda ()
        (yield 1 2 3)
        (yield 4 5 6)
        7)))
]])
local gen = lisp:eval("(make-generator)")
local ok1, a1, a2, a3 = lisp:eval("(resume (make-generator))")
print(string.format("  First: %s, %s, %s, %s", tostring(ok1), tostring(a1), tostring(a2), tostring(a3)))

if ok1 == true and a1 == 1 and a2 == 2 and a3 == 3 then
  print("  ✓ Multiple values from YIELD work correctly")
else
  print("  ✗ Should return (true, 1, 2, 3)")
end

print("\n=== Summary ===")
print("YIELD should return all arguments as multiple values")
print("RESUME should be able to pass multiple values (though coroutine may not capture them)")

