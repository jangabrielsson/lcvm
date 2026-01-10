--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing Multiple Return Values ===\n")

-- Test 1: Basic VALUES
print("Test 1: Basic VALUES")
local v1, v2, v3 = lisp:eval("(values 1 2 3)")
print(string.format("  Result: %s, %s, %s", tostring(v1), tostring(v2), tostring(v3)))
print(string.format("  Expected: 1, 2, 3 - %s", (v1==1 and v2==2 and v3==3) and "✓" or "✗"))

-- Test 2: VALUES in function call - only last arg keeps multiple values
print("\nTest 2: Multiple values in function call")
lisp:eval([[
  (defun sum-all (&rest args)
    (progn
      (setq total 0)
      (loop
        (progn
          (if (null? args) (break total))
          (setq total (+ total (car args)))
          (setq args (cdr args))))))
]])

-- (sum-all (values 1 2) (values 3 4 5))
-- Should discard 2 from first arg, keep all from last arg
-- So: (sum-all 1 3 4 5) = 13
local result = lisp:eval("(sum-all (values 1 2) (values 3 4 5))")
print(string.format("  (sum-all (values 1 2) (values 3 4 5)) = %s", result))
print(string.format("  Expected: 13 (1 from first, 3+4+5 from last) - %s", result==13 and "✓" or "✗"))

-- Test 3: PROGN returns multiple values from last expression
print("\nTest 3: PROGN returns multiple values")
local p1, p2, p3 = lisp:eval("(progn (+ 1 1) (values 10 20 30))")
print(string.format("  Result: %s, %s, %s", tostring(p1), tostring(p2), tostring(p3)))
print(string.format("  Expected: 10, 20, 30 - %s", (p1==10 and p2==20 and p3==30) and "✓" or "✗"))

-- Test 4: Function returning multiple values
print("\nTest 4: Function returning multiple values")
lisp:eval([[
  (defun return-three ()
    (values 100 200 300))
]])
local r1, r2, r3 = lisp:eval("(return-three)")
print(string.format("  Result: %s, %s, %s", tostring(r1), tostring(r2), tostring(r3)))
print(string.format("  Expected: 100, 200, 300 - %s", (r1==100 and r2==200 and r3==300) and "✓" or "✗"))

-- Test 5: Multiple values in middle argument (should be discarded)
print("\nTest 5: Multiple values in middle argument")
local m = lisp:eval("(sum-all 1 (values 2 99 98) 3)")
print(string.format("  (sum-all 1 (values 2 99 98) 3) = %s", m))
print(string.format("  Expected: 6 (1 + 2 + 3, extras discarded) - %s", m==6 and "✓" or "✗"))

-- Test 6: Only last arg in list keeps multiple values
print("\nTest 6: Multiple values as last in list")
local l = lisp:eval("(sum-all 1 2 (values 3 4 5))")
print(string.format("  (sum-all 1 2 (values 3 4 5)) = %s", l))
print(string.format("  Expected: 15 (1+2+3+4+5) - %s", l==15 and "✓" or "✗"))

print("\n=== Multiple values tests completed ===")
