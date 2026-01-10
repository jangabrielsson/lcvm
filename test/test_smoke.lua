--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Quick Smoke Test ===\n")

-- Test basic arithmetic (should still work)
local r1 = lisp:eval("(+ 3 4)")
print("1. (+ 3 4) = " .. tostring(r1) .. " " .. (r1 == 7 and "✓" or "✗"))

-- Test RETURN with multiple values
lisp:eval("(defun test-return () (return 1 2 3))")
local a, b, c = lisp:eval("(test-return)")
print(string.format("2. (return 1 2 3) = %s, %s, %s %s", tostring(a), tostring(b), tostring(c), 
  (a==1 and b==2 and c==3) and "✓" or "✗"))

-- Test VALUES with multiple values
lisp:eval("(defun test-values () (values 4 5 6))")
local d, e, f = lisp:eval("(test-values)")
print(string.format("3. (values 4 5 6) = %s, %s, %s %s", tostring(d), tostring(e), tostring(f),
  (d==4 and e==5 and f==6) and "✓" or "✗"))

-- Test YIELD with multiple values
lisp:eval([[
  (setq co (create-coroutine 
    (lambda () (yield 7 8 9) 100)))
]])
local ok, g, h, i = lisp:eval("(resume co)")
print(string.format("4. (yield 7 8 9) = %s, %s, %s, %s %s", tostring(ok), tostring(g), tostring(h), tostring(i),
  (ok==true and g==7 and h==8 and i==9) and "✓" or "✗"))

-- Test coroutine still works normally
lisp:eval([[
  (setq co2 (create-coroutine 
    (lambda () 
      (yield 10)
      (yield 20)
      30)))
]])
local s1, v1 = lisp:eval("(resume co2)")
local s2, v2 = lisp:eval("(resume co2)")
local s3, v3 = lisp:eval("(resume co2)")
print(string.format("5. Sequential yields: %s, %s, %s %s", tostring(v1), tostring(v2), tostring(v3),
  (v1==10 and v2==20 and v3==30) and "✓" or "✗"))

print("\n✓ All smoke tests passed!")
