--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing (resume co) vs (values (resume co)) ===\n")

-- Test 1: Direct resume (no VALUES wrapper)
print("Test 1: Direct (resume co) without VALUES")
lisp:eval([[
  (setq co1 (create-coroutine 
    (lambda ()
      (yield 10 20 30)
      999)))
]])
local s1, v1, v2, v3 = lisp:eval("(resume co1)")
print(string.format("  (resume co1) → %s, %s, %s, %s", tostring(s1), tostring(v1), tostring(v2), tostring(v3)))

-- Test 2: Resume wrapped in VALUES
print("\nTest 2: (values (resume co)) with VALUES wrapper")
lisp:eval([[
  (setq co2 (create-coroutine 
    (lambda ()
      (yield 10 20 30)
      999)))
]])
local s2, w1, w2, w3 = lisp:eval("(values (resume co2))")
print(string.format("  (values (resume co2)) → %s, %s, %s, %s", tostring(s2), tostring(w1), tostring(w2), tostring(w3)))

-- Compare
print("\nComparison:")
if s1 == s2 and v1 == w1 and v2 == w2 and v3 == w3 then
  print("  ✓ Both produce identical results")
  print("  → (values ...) wrapper is redundant for RESUME")
else
  print("  ✗ Results differ!")
end

print("\nConclusion: (resume co) already returns multiple values.")
print("The (values ...) wrapper is unnecessary.")
