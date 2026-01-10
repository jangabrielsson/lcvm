--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local lisp = Lisp()

print("=== Testing AND/OR Optimizations ===\n")

-- AND2 tests (2 arguments)
assert(lisp:eval("(and 1 2)") == 2, "AND2 both true")
print("AND2 both true: (and 1 2) = 2 ✓")

assert(lisp:eval("(and false 2)") == false, "AND2 first false")
print("AND2 first false: (and false 2) = false ✓")

assert(lisp:eval("(and 1 false)") == false, "AND2 second false")
print("AND2 second false: (and 1 false) = false ✓")

assert(lisp:eval("(and false false)") == false, "AND2 both false")
print("AND2 both false: (and false false) = false ✓")

-- ANDN tests (3+ arguments)
assert(lisp:eval("(and 1 2 3)") == 3, "AND3 all true")
print("AND3 all true: (and 1 2 3) = 3 ✓")

assert(lisp:eval("(and false 2 3)") == false, "AND3 first false")
print("AND3 first false: (and false 2 3) = false ✓")

assert(lisp:eval("(and 1 false 3)") == false, "AND3 middle false")
print("AND3 middle false: (and 1 false 3) = false ✓")

assert(lisp:eval("(and 1 2 false)") == false, "AND3 last false")
print("AND3 last false: (and 1 2 false) = false ✓")

assert(lisp:eval("(and 1 2 3 4)") == 4, "AND4 all true")
print("AND4 all true: (and 1 2 3 4) = 4 ✓")

assert(lisp:eval("(and 1 2 false 4 5)") == false, "AND5 middle false")
print("AND5 middle false: (and 1 2 false 4 5) = false ✓")

-- AND edge cases
assert(lisp:eval("(and)") == true, "AND0 no args")
print("AND0 no args: (and) = true ✓")

assert(lisp:eval("(and 42)") == 42, "AND1 single true")
print("AND1 single true: (and 42) = 42 ✓")

assert(lisp:eval("(and false)") == false, "AND1 single false")
print("AND1 single false: (and false) = false ✓")

-- OR2 tests (2 arguments)
assert(lisp:eval("(or false false)") == false, "OR2 both false")
print("OR2 both false: (or false false) = false ✓")

assert(lisp:eval("(or 1 false)") == 1, "OR2 first true")
print("OR2 first true: (or 1 false) = 1 ✓")

assert(lisp:eval("(or false 2)") == 2, "OR2 second true")
print("OR2 second true: (or false 2) = 2 ✓")

assert(lisp:eval("(or 1 2)") == 1, "OR2 both true")
print("OR2 both true: (or 1 2) = 1 ✓")

-- ORN tests (3+ arguments)
assert(lisp:eval("(or false false false)") == false, "OR3 all false")
print("OR3 all false: (or false false false) = false ✓")

assert(lisp:eval("(or 1 false false)") == 1, "OR3 first true")
print("OR3 first true: (or 1 false false) = 1 ✓")

assert(lisp:eval("(or false 2 false)") == 2, "OR3 middle true")
print("OR3 middle true: (or false 2 false) = 2 ✓")

assert(lisp:eval("(or false false 3)") == 3, "OR3 last true")
print("OR3 last true: (or false false 3) = 3 ✓")

assert(lisp:eval("(or false 2 false 4)") == 2, "OR4 middle true")
print("OR4 middle true: (or false 2 false 4) = 2 ✓")

assert(lisp:eval("(or false false false false 5)") == 5, "OR5 last true")
print("OR5 last true: (or false false false false 5) = 5 ✓")

-- OR edge cases
assert(lisp:eval("(or)") == false, "OR0 no args")
print("OR0 no args: (or) = false ✓")

assert(lisp:eval("(or false)") == false, "OR1 single false")
print("OR1 single false: (or false) = false ✓")

assert(lisp:eval("(or 42)") == 42, "OR1 single true")
print("OR1 single true: (or 42) = 42 ✓")

-- Short-circuit evaluation tests
print("\n--- Short-circuit evaluation ---")

lisp:eval("(setq se-count 0)")
lisp:eval("(defun se () (setq se-count (+ se-count 1)) 1)")

-- AND should stop at first false
lisp:eval("(setq se-count 0)")
lisp:eval("(and false (se))")
assert(lisp:eval("se-count") == 0, "AND2 didn't short-circuit")
print("AND2 short-circuit: ✓")

lisp:eval("(setq se-count 0)")
lisp:eval("(and false (se) (se))")
assert(lisp:eval("se-count") == 0, "ANDN didn't short-circuit")
print("ANDN short-circuit: ✓")

-- OR should stop at first true
lisp:eval("(setq se-count 0)")
lisp:eval("(or 1 (se))")
assert(lisp:eval("se-count") == 0, "OR2 didn't short-circuit")
print("OR2 short-circuit: ✓")

lisp:eval("(setq se-count 0)")
lisp:eval("(or 1 (se) (se))")
assert(lisp:eval("se-count") == 0, "ORN didn't short-circuit")
print("ORN short-circuit: ✓")

print("\n✓ All AND/OR optimization tests passed!")
