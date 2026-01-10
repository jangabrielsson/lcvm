--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("Testing BREAK with multiple values\n")

lisp:eval([[
  (defun test ()
    (loop (break 10 20 30)))
]])

local a, b, c = lisp:eval("(test)")
print(string.format("(break 10 20 30) returned: %s, %s, %s", tostring(a), tostring(b), tostring(c)))

if a == 10 and b == 20 and c == 30 then
  print("✓ BREAK returns all three values!")
else
  print("✗ Expected (10, 20, 30)")
end
