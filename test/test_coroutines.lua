--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing Coroutine Primitives ===\n")

-- Test 1: Basic coroutine creation and resume
print("Test 1: Basic coroutine")
local ok, val = lisp:eval([[
  (progn
    (setq co (create-coroutine (lambda () 42)))
    (resume co))
]])
print("  Result:", ok, val, ok == true and val == 42 and "✓" or "✗")

-- Test 2: Simple yield
print("\nTest 2: Simple yield")
lisp:eval([[
  (setq co2 (create-coroutine (lambda ()
    (progn
      (yield 10)
      (yield 20)
      30))))
]])
local ok1, val1 = lisp:eval("(resume co2)")
print("  First resume:", ok1, val1, ok1 == true and val1 == 10 and "✓" or "✗")
local ok2, val2 = lisp:eval("(resume co2)")
print("  Second resume:", ok2, val2, ok2 == true and val2 == 20 and "✓" or "✗")
local ok3, val3 = lisp:eval("(resume co2)")
print("  Third resume:", ok3, val3, ok3 == true and val3 == 30 and "✓" or "✗")

-- Test 3: Passing values through yield/resume
print("\nTest 3: Passing values through yield/resume")
lisp:eval([[
  (setq co3 (create-coroutine (lambda (x)
    (progn
      (setq y (yield (+ x 1)))
      (+ y 10)))))
]])
local r1ok, r1 = lisp:eval("(resume co3 5)")
print("  First resume with 5:", r1ok, r1, r1ok == true and r1 == 6 and "✓" or "✗")
local r2ok, r2 = lisp:eval("(resume co3 3)")
print("  Second resume with 3:", r2ok, r2, r2ok == true and r2 == 13 and "✓" or "✗")

-- Test 4: Coroutine with loop (generator pattern)
print("\nTest 4: Coroutine generator")
lisp:eval([[
  (setq counter (create-coroutine (lambda (start)
    (progn
      (setq n start)
      (loop
        (progn
          (yield n)
          (setq n (+ n 1))))))))
]])
local c1ok, c1 = lisp:eval("(resume counter 1)")
print("  Counter 1:", c1ok, c1, c1ok == true and c1 == 1 and "✓" or "✗")
local c2ok, c2 = lisp:eval("(resume counter)")
print("  Counter 2:", c2ok, c2, c2ok == true and c2 == 2 and "✓" or "✗")
local c3ok, c3 = lisp:eval("(resume counter)")
print("  Counter 3:", c3ok, c3, c3ok == true and c3 == 3 and "✓" or "✗")

-- Test 5: Error - yield outside coroutine
print("\nTest 5: Yield outside coroutine (should error)")
local ok, err = pcall(function() return lisp:eval("(yield 1)") end)
print("  Expected error:", not ok and "✓" or "✗", err)

-- Test 6: Producer-consumer pattern
print("\nTest 6: Producer-consumer")
lisp:eval([[
  (setq producer (create-coroutine (lambda ()
    (progn
      (yield 'apple)
      (yield 'banana)
      (yield 'cherry)
      'done))))
]])
local p1ok, p1 = lisp:eval("(resume producer)")
print("  Produce:", p1ok, p1, p1ok == true and p1 == "apple" and "✓" or "✗")
local p2ok, p2 = lisp:eval("(resume producer)")
print("  Produce:", p2ok, p2, p2ok == true and p2 == "banana" and "✓" or "✗")
local p3ok, p3 = lisp:eval("(resume producer)")
print("  Produce:", p3ok, p3, p3ok == true and p3 == "cherry" and "✓" or "✗")
local p4ok, p4 = lisp:eval("(resume producer)")
print("  Produce:", p4ok, p4, p4ok == true and p4 == "done" and "✓" or "✗")

-- Test 7: Resume dead coroutine
print("\nTest 7: Resume dead coroutine")
lisp:eval("(setq dead-co (create-coroutine (lambda () 123)))")
local ok1, result1 = lisp:eval("(resume dead-co)")
local ok2, result2 = lisp:eval("(resume dead-co)")
print("  Can't resume dead:", not ok2 and "✓" or "✗", result2)

print("\n=== All coroutine tests completed ===")
