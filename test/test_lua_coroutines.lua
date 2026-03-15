--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

-- Stub for json.encode used in continuation __tostring (not available in plain Lua)
json = json or { encode = function(v) return type(v) == 'string' and v or '<object>' end }

-- Tests for VM.luaCoroutine: resume/yield accessible from plain Lua,
-- without using Lua's built-in coroutines.

local lisp = Lisp()

-- Helper: compile code and wrap in a Lua coroutine that shares the lisp
-- environment (so standard functions like + * are accessible).
local function mkco(code)
  return VM.luaCoroutine(lisp:_compile(code), lisp.env:copy())
end

local pass, fail = 0, 0
local function check(desc, got, expected)
  if got == expected then
    print(string.format("  PASS  %s  (got %s)", desc, tostring(got)))
    pass = pass + 1
  else
    print(string.format("  FAIL  %s  expected=%s  got=%s", desc, tostring(expected), tostring(got)))
    fail = fail + 1
  end
end

print("=== VM.luaCoroutine tests ===\n")

-- ── Test 1: function that returns immediately (no yield) ──────────────────
print("Test 1: no yield – returns 42")
do
  local co = mkco("(lambda () 42)")
  local ok, v = co.resume()
  check("ok",     ok, true)
  check("value",  v,  42)
  check("status", co.status, 'dead')
  -- resuming a dead coroutine
  local ok2, err = co.resume()
  check("dead resume ok==false", ok2, false)
end

-- ── Test 2: single yield ──────────────────────────────────────────────────
print("\nTest 2: single yield")
do
  local co = mkco("(lambda () (progn (yield 10) 20))")

  local ok1, v1 = co.resume()
  check("first resume ok",    ok1, true)
  check("first resume value", v1,  10)
  check("status suspended",   co.status, 'suspended')

  local ok2, v2 = co.resume()
  check("second resume ok",    ok2, true)
  check("second resume value", v2,  20)
  check("status dead",         co.status, 'dead')
end

-- ── Test 3: first-resume args passed to lambda ───────────────────────────
print("\nTest 3: args passed on first resume")
do
  local co = mkco("(lambda (x) (+ x 1))")
  local ok, v = co.resume(99)
  check("ok",    ok, true)
  check("value", v,  100)
end

-- ── Test 4: resume value becomes yield's return ───────────────────────────
print("\nTest 4: value passed to resume becomes yield's return value")
do
  -- (lambda (x)
  --   (let ((y (yield (+ x 1))))
  --     (* y 3)))
  local co = mkco("(lambda (x) (let ((y (yield (+ x 1)))) (* y 3)))")

  local ok1, v1 = co.resume(4)    -- yield → (+ 4 1) = 5
  check("first yield value", v1, 5)

  local ok2, v2 = co.resume(7)    -- y = 7, return (* 7 3) = 21
  check("return value", v2, 21)
end

-- ── Test 5: multiple yields (generator pattern) ───────────────────────────
print("\nTest 5: multiple yields")
do
  local co = mkco([[
    (lambda (n)
      (progn
        (yield n)
        (yield (+ n 1))
        (yield (+ n 2))
        (+ n 3)))
  ]])

  local _, v1 = co.resume(10)
  local _, v2 = co.resume()
  local _, v3 = co.resume()
  local _, v4 = co.resume()
  check("yield 1", v1, 10)
  check("yield 2", v2, 11)
  check("yield 3", v3, 12)
  check("return",  v4, 13)
  check("dead",    co.status, 'dead')
end

-- ── Test 6: yield inside a loop (infinite generator) ─────────────────────
print("\nTest 6: loop-based generator")
do
  local co = mkco([[
    (lambda (start)
      (progn
        (setq n start)
        (loop
          (progn
            (yield n)
            (setq n (+ n 1))))))
  ]])
  local _, a = co.resume(5)
  local _, b = co.resume()
  local _, c = co.resume()
  check("gen 1", a, 5)
  check("gen 2", b, 6)
  check("gen 3", c, 7)
  check("still suspended", co.status, 'suspended')
end

-- ── Test 7: error in the coroutine body ───────────────────────────────────
print("\nTest 7: error inside coroutine")
do
  -- (car 5) triggers env.error directly without touching json.encode
  local co = mkco("(lambda () (car 5))")
  local ok, err = co.resume()
  check("error returns false", ok, false)
  check("coroutine is dead",   co.status, 'dead')
  print(string.format("  (error message: %s)", tostring(err)))
end

-- ── Test 8: independent coroutines don't interfere ────────────────────────
print("\nTest 8: two independent coroutines")
do
  -- Each gets its own env copy so their local frames are independent
  local c1 = mkco("(lambda (s) (progn (yield s) (+ s 100)))")
  local c2 = mkco("(lambda (s) (progn (yield s) (+ s 100)))")

  local _, a1 = c1.resume(1)
  local _, b1 = c2.resume(2)
  local _, a2 = c1.resume()
  local _, b2 = c2.resume()
  check("c1 yield", a1, 1)
  check("c2 yield", b1, 2)
  check("c1 ret",   a2, 101)
  check("c2 ret",   b2, 102)
end

-- ── Test 9: existing Lisp-level coroutines still work ─────────────────────
print("\nTest 9: existing Lisp-level coroutines unaffected")
do
  lisp:eval([[
    (setq lco (create-coroutine (lambda ()
      (progn (yield 7) 8))))
  ]])
  local ok1, v1 = lisp:eval("(resume lco)")
  local ok2, v2 = lisp:eval("(resume lco)")
  check("lisp yield",  v1, 7)
  check("lisp return", v2, 8)
end

print(string.format("\n=== Results: %d passed, %d failed ===", pass, fail))
