-- Test LETV (LET with multiple Values)
--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

print("\n=== Testing LETV ===\n")

local function test(name, code, expected)
  local lisp = Lisp()
  local result = lisp:eval(code)
  local success = result == expected
  if success then
    print("✓ " .. name)
  else
    print("✗ " .. name)
    print("  Expected: " .. tostring(expected))
    print("  Got:      " .. tostring(result))
  end
  return success
end

local function testMultiple(name, code, ...)
  local expected = {...}
  local lisp = Lisp()
  local results = {lisp:eval(code)}
  local success = #results == #expected
  if success then
    for i = 1, #expected do
      if results[i] ~= expected[i] then
        success = false
        break
      end
    end
  end
  if success then
    print("✓ " .. name)
  else
    print("✗ " .. name)
    print("  Expected: " .. table.concat(expected, ", "))
    print("  Got:      " .. table.concat(results, ", "))
  end
  return success
end

-- Test 1: Basic usage with multiple return values
test("Test 1: Basic letv with values",
  "(letv (a b) ((values 10 20)) (+ a b))",
  30)

-- Test 2: More variables than values (should bind false/nil to extras)
test("Test 2: More variables than values",
  "(letv (a b c) ((values 10 20)) (if (null? c) (+ a b) 999))",
  30)

-- Test 3: Multiple expressions, last returns multiple values
test("Test 3: Multiple expressions",
  "(letv (a b c) (5 (values 10 20)) (+ a (+ b c)))",
  35)  -- a=5, b=10, c=20 -> 5 + 10 + 20

-- Test 4: Single expression returning single value
test("Test 4: Single value",
  "(letv (a) ((+ 5 5)) (* a 2))",
  20)

-- Test 5: Function call returning multiple values
test("Test 5: Function call with multiple values",
  [[
    (progn
      (defun multi-return (x y) (values (* x 2) (* y 3)))
      (letv (a b) ((multi-return 5 10)) (+ a b)))
  ]],
  40)  -- a=10, b=30 -> 40

-- Test 6: Nested letv
test("Test 6: Nested letv",
  [[
    (letv (a b) ((values 1 2))
      (letv (c d) ((values 3 4))
        (+ a (+ b (+ c d)))))
  ]],
  10)  -- 1 + 2 + 3 + 4

-- Test 7: Empty expression list (all vars get nil/false)
test("Test 7: Empty expression list",
  "(letv (a b) () (if (and (null? a) (null? b)) 42 999))",
  42)

-- Test 8: Using letv with resume (coroutine returning multiple values)
test("Test 8: Letv with coroutine",
  [[
    (progn
      (defun coro-func () (yield 100 200))
      (setq co (create-coroutine coro-func))
      (letv (success a b) ((resume co)) 
        (if success (+ a b) 0)))
  ]],
  300)

-- Test 9: More complex example - capturing 3 values
test("Test 9: Three values",
  "(letv (x y z) ((values 1 2 3)) (+ x (+ y z)))",
  6)

-- Test 10: letv with side effects in expressions - verify correct values
test("Test 10: Side effects in expressions",
  [[
    (progn
      (setq counter 0)
      (defun inc () (setq counter (+ counter 1)) counter)
      (letv (a b c) ((inc) (values (inc) (inc)))
        counter))
  ]],
  3)  -- counter should be 3 after all calls

print("\n=== LETV Tests Complete ===")
