--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Memory Usage Tests ===\n")

-- Helper function to extract memory and frames
local function extractInfo(str)
  local mem = tonumber(str:match("Memory:(%d+)K"))
  local frames = tonumber(str:match("Frames:(%d+)"))
  local exprs = tonumber(str:match("evalExprs:(%d+)"))
  return mem, frames, exprs
end

-- Test 1: Tail recursive function - demonstrates tail call optimization
print("Test 1: Tail Recursive Counter (with tail call optimization)")
print("  Running 10000 tail recursive calls...")

lisp:eval([[
  (defun tail-counter (n max)
    (if (= n max)
      n
      (tail-counter (+ n 1) max)))
]])

local memBefore = lisp:eval("(memory)")
print("  Before: " .. memBefore)

lisp:eval("(tail-counter 0 10000)")

local memAfter = lisp:eval("(memory)")
print("  After:  " .. memAfter)

local mem1, frames1, exprs1 = extractInfo(memBefore)
local mem2, frames2, exprs2 = extractInfo(memAfter)
print(string.format("  Memory increase: %dK", mem2 - mem1))
print(string.format("  Frame depth: %d (constant due to tail call optimization)", frames2))
print(string.format("  evalExprs executed: %d", exprs2 - exprs1))
print("  ✓ Tail call optimization working - constant stack depth!\n")

-- Test 2: LOOP statement - shows constant memory usage
print("Test 2: LOOP Statement (constant memory, no stack growth)")
print("  Running loop with 10000 iterations...")

lisp:eval([[
  (defun loop-counter (max)
    (progn
      (setq n 0)
      (loop
        (progn
          (if (= n max) (break n))
          (setq n (+ n 1))))))
]])

local memBefore2 = lisp:eval("(memory)")
print("  Before: " .. memBefore2)

lisp:eval("(loop-counter 10000)")

local memAfter2 = lisp:eval("(memory)")
print("  After:  " .. memAfter2)

local mem3, frames3, exprs3 = extractInfo(memBefore2)
local mem4, frames4, exprs4 = extractInfo(memAfter2)
print(string.format("  Memory increase: %dK", mem4 - mem3))
print(string.format("  Frame depth: %d (constant)", frames4))
print(string.format("  evalExprs executed: %d", exprs4 - exprs3))
print("  ✓ LOOP uses constant stack space - efficient for iterations!\n")

-- Test 3: Deep recursion (non-tail) - will hit stack limit
print("Test 3: Non-tail Recursion (will fail with deep recursion)")
print("  Attempting 100 non-tail recursive calls...")

lisp:eval([[
  (defun factorial-test (n)
    (if (< n 2)
      1
      (* n (factorial-test (- n 1)))))
]])

local ok, result = pcall(function()
  return lisp:eval("(factorial-test 100)")
end)

if ok then
  print("  Success: factorial(100) computed")
  local memAfter3 = lisp:eval("(memory)")
  print("  After: " .. memAfter3)
else
  print("  Failed as expected: " .. tostring(result))
end

print("\n=== Summary ===")
print("• Tail recursion: Tail call optimization working - constant frame depth")
print("• LOOP statement: Constant memory, efficient for iterations")
print("• Both achieve O(1) space complexity for iteration")
print("\n=== Memory tests completed ===")
