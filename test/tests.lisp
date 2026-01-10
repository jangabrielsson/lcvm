; Test cases for Continuation-based Lisp
; Format: (test "description" expression expected-result)

; Basic arithmetic
(test "addition" (+ 3 4) 7)
(test "subtraction" (- 10 3) 7)
(test "multiplication" (* 5 6) 30)
(test "division" (/ 20 4) 5)

; Comparisons
(test "less than true" (< 3 5) true)
(test "less than false" (< 5 3) false)
(test "greater than" (> 10 5) true)
(test "equality" (= 7 7) true)

; Variables
(test "setq returns value" (setq x 42) 42)
(test "variable access" (progn (setq y 10) y) 10)

; Conditionals
(test "if true branch" (if true 1 2) 1)
(test "if false branch" (if false 1 2) 2)
(test "if with condition" (if (< 3 5) "yes" "no") "yes")

; Functions
(test "lambda call" ((lambda (x) (+ x 1)) 5) 6)
(test "defun and call" (progn (defun add1 (x) (+ x 1)) (add1 5)) 6)
(test "function with multiple params" (progn (defun add (a b) (+ a b)) (add 3 4)) 7)

; Recursion
(test "factorial 5" 
  (progn 
    (defun factorial (n) 
      (if (< n 2) 
        1 
        (* n (factorial (- n 1)))))
    (factorial 5))
  120)

(test "factorial 10" 
  (progn 
    (defun fact (n) 
      (if (< n 2) 
        1 
        (* n (fact (- n 1)))))
    (fact 10))
  3628800)

; LOOP and BREAK
(test "simple loop with break"
  (progn
    (setq counter 0)
    (loop 
      (setq counter (+ counter 1))
      (if (> counter 5) (break counter))))
  6)

(test "loop with accumulator"
  (progn
    (setq sum 0)
    (setq i 1)
    (loop
      (setq sum (+ sum i))
      (setq i (+ i 1))
      (if (> i 10) (break sum))))
  55)

; RETURN statement
(test "early return negative"
  (progn
    (defun early-exit (x) 
      (if (< x 0) (return "negative")) 
      (+ x 10))
    (early-exit -3))
  "negative")

(test "early return positive"
  (progn
    (defun early-exit2 (x) 
      (if (< x 0) (return "negative")) 
      (+ x 10))
    (early-exit2 5))
  15)

(test "return from loop in function"
  (progn
    (defun find-in-loop (target)
      (setq i 0)
      (loop
        (if (= i target) (return i))
        (setq i (+ i 1))
        (if (> i 10) (break "not-found"))))
    (find-in-loop 7))
  7)

(test "return not-found"
  (progn
    (defun find2 (target)
      (setq i 0)
      (loop
        (if (= i target) (return i))
        (setq i (+ i 1))
        (if (> i 10) (break "not-found"))))
    (find2 20))
  "not-found")

; Nested functions
(test "nested function call"
  (progn
    (defun outer (x) 
      (defun inner (y) (+ y 1))
      (inner x))
    (outer 5))
  6)

; Tail recursion (should not grow memory)
(test "tail recursive counter"
  (progn
    (defun count-down (n acc)
      (if (< n 1)
        acc
        (count-down (- n 1) (+ acc 1))))
    (count-down 100 0))
  100)

; Multiple return values
(test "single return value"
  (progn
    (defun single () 42)
    (single))
  42)

(test "values returns first"
  (values 10 20 30)
  10)

(test "function with values"
  (progn
    (defun multi () (values 1 2 3))
    (multi))
  1)

(test "values with expressions"
  (values (+ 1 2) (* 3 4))
  3)
; LET bindings
(test "let simple binding" 
  (let ((x 10) (y 20)) (+ x y))
  30)

(test "let single binding" 
  (let ((a 5)) (* a a))
  25)

(test "let nested" 
  (let ((x 1)) (let ((y 2)) (+ x y)))
  3)

(test "let with function"
  (let ((double (lambda (x) (* x 2))))
    (double 21))
  42)

; COND multi-way conditional
(test "cond first clause true"
  (cond ((< 5 3) 1) ((> 5 3) 2) (t 3))
  2)

(test "cond multiple expressions"
  (cond ((< 5 10) (setq temp 100) 200))
  200)

(test "cond default clause"
  (cond (nil 1) (nil 2) (t 3))
  3)

(test "cond no match"
  (cond (nil 1) (nil 2))
  false)

; AND logical operator
(test "and all true"
  (and t t t)
  true)

(test "and with false"
  (and t nil t)
  false)

(test "and with expressions"
  (and (< 5 10) (> 10 5))
  true)

(test "and empty"
  (and)
  true)

; OR logical operator  
(test "or finds true"
  (or nil nil t)
  true)

(test "or all false"
  (or nil nil nil)
  false)

(test "or with expressions"
  (or (< 10 5) (> 10 5))
  true)

(test "or returns first truthy"
  (or 42 nil)
  42)

; NOT logical negation
(test "not true"
  (not t)
  false)

(test "not nil"
  (not nil)
  true)

(test "not number"
  (not 42)
  false)

; LIST operations
(test "list creation"
  (progn
    (setq lst (list 1 2 3))
    (car lst))
  1)

(test "car first element"
  (car (list 10 20 30))
  10)

(test "cdr rest of list"
  (progn
    (setq lst2 (cdr (list 10 20 30)))
    (car lst2))
  20)

(test "cons prepend"
  (progn
    (setq clst (cons 1 (list 2 3)))
    (car clst))
  1)

(test "cons with nil"
  (progn
    (setq clst2 (cons 1 nil))
    (car clst2))
  1)

(test "null? with nil"
  (null? nil)
  true)

(test "null? with empty list"
  (null? (list))
  true)

(test "null? with non-empty"
  (null? (list 1))
  false)

; Recursive list sum with COND and list operations
(test "sum-list recursive"
  (progn
    (defun sum-list (lst)
      (cond 
        ((null? lst) 0)
        (t (+ (car lst) (sum-list (cdr lst))))))
    (sum-list (list 1 2 3 4 5)))
  15)

; CATCH/THROW tests
(test "basic catch/throw"
  (catch 'exit
    (throw 'exit 42))
  42)

(test "catch with no throw"
  (catch 'exit
    (+ 1 2))
  3)

(test "catch returns last body value"
  (catch 'exit
    (+ 1 2)
    (* 3 4))
  12)

(test "throw with no value"
  (catch 'exit
    (throw 'exit))
  nil)

(test "nested catches - inner throw"
  (catch 'outer
    (catch 'inner
      (throw 'inner 10)))
  10)

(test "nested catches - outer throw"
  (catch 'outer
    (catch 'inner
      (throw 'outer 20))
    100)
  20)

(test "catch in function"
  (progn
    (defun safe-div (a b)
      (catch 'div-error
        (if (= b 0)
          (throw 'div-error "division by zero")
          (/ a b))))
    (safe-div 10 2))
  5)

(test "catch handles error"
  (progn
    (defun safe-div (a b)
      (catch 'div-error
        (if (= b 0)
          (throw 'div-error 999)
          (/ a b))))
    (safe-div 10 0))
  999)

(test "throw unwinds through function calls"
  (progn
    (defun inner (x)
      (if (< x 0)
        (throw 'negative "negative value")
        x))
    (defun outer (x)
      (+ (inner x) 1))
    (catch 'negative
      (outer -5)))
  "negative value")

(test "catch with multiple body expressions"
  (catch 'exit
    (setq x 10)
    (setq y 20)
    (+ x y))
  30)

(test "throw from nested expression"
  (catch 'exit
    (+ 1 (+ 2 (throw 'exit 100))))
  100)

(test "catch/throw with quote tags"
  (catch 'my-tag
    (progn
      (setq z 5)
      (throw 'my-tag z)))
  5)

(test "multiple catches same tag - innermost wins"
  (catch 'tag
    (+ 1
      (catch 'tag
        (throw 'tag 50))))
  51)

; ERROR handling tests using catch/throw
(test "catch prevents error propagation"
  (progn
    (setq result (catch 'safe
      (if true (throw 'safe 'caught) "normal")))
    result)
  'caught)

; COROUTINE tests - testing multiple return values (status, value)
(test "basic coroutine creation and resume"
  (progn
    (setq co (create-coroutine (lambda () 42)))
    (resume co))
  (list true 42))

(test "coroutine with yield"
  (progn
    (setq co2 (create-coroutine (lambda ()
      (yield 10))))
    (resume co2))
  (list true 10))

(test "coroutine multiple yields"
  (progn
    (setq co3 (create-coroutine (lambda ()
      (progn
        (yield 10)
        (yield 20)
        30))))
    (resume co3)
    (resume co3))
  (list true 20))

(test "coroutine passing values"
  (progn
    (setq co4 (create-coroutine (lambda (x)
      (progn
        (setq y (yield (+ x 1)))
        (+ y 10)))))
    (resume co4 5)
    (resume co4 3))
  (list true 13))

(test "coroutine generator pattern"
  (progn
    (setq counter (create-coroutine (lambda (start)
      (progn
        (setq n start)
        (loop
          (progn
            (yield n)
            (setq n (+ n 1))))))))
    (resume counter 1)
    (resume counter)
    (resume counter))
  (list true 3))