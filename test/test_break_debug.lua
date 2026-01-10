--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("Debug BREAK compilation\n")

-- First, let's see what gets compiled
lisp:eval([[
  (defun test ()
    (loop (break 10 20 30)))
]])

-- Now test VALUES for comparison
lisp:eval([[
  (defun test-values ()
    (values 10 20 30))
]])

print("Testing VALUES (should work):")
local v1, v2, v3 = lisp:eval("(test-values)")
print(string.format("  values: %s, %s, %s", tostring(v1), tostring(v2), tostring(v3)))

print("\nTesting BREAK:")
local a, b, c = lisp:eval("(test)")
print(string.format("  break: %s, %s, %s", tostring(a), tostring(b), tostring(c)))

-- Let's also check RETURN
lisp:eval([[
  (defun test-return ()
    (return 10 20 30))
]])

print("\nTesting RETURN (should work):")
local r1, r2, r3 = lisp:eval("(test-return)")
print(string.format("  return: %s, %s, %s", tostring(r1), tostring(r2), tostring(r3)))
