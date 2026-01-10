# Continuation VM Primitives

This document describes the core primitives provided by the Continuation-based Virtual Machine. These primitives form a domain-agnostic foundation for implementing higher-level languages.

## Core Concepts

- **Continuation-Passing Style (CPS)**: All operations pass their result to a continuation function
- **Expressions**: Functions of the form `(cont, env, ...) -> next_expr, cont`
- **Continuations**: Functions of the form `(val, ...) -> next_expr, cont`
- **Trampoline Execution**: Iterative execution prevents stack overflow

## Variable Operations

### VAR(name)

Retrieves the value of a variable from the environment.

**Syntax:**
```lua
expr.VAR(name)
```

**Parameters:**
- `name` (string): Variable name

**Returns:** The value bound to the variable

**Example:**
```lisp
(setq x 42)
x  ; => 42
```

---

### CONST(value)

Creates a constant expression that evaluates to the given value.

**Syntax:**
```lua
expr.CONST(value)
```

**Parameters:**
- `value` (any): The constant value

**Returns:** The constant value

**Example:**
```lisp
42     ; => 42
"hello" ; => "hello"
true   ; => true
```

---

### SETQ(name, valExpr)

Assigns a value to a variable. Creates the variable if it doesn't exist in the current scope, otherwise updates the existing binding.

**Syntax:**
```lua
expr.SETQ(name, valExpr)
```

**Parameters:**
- `name` (string): Variable name
- `valExpr` (expression): Expression to evaluate for the value

**Returns:** The assigned value

**Example:**
```lisp
(setq x 42)      ; => 42
(setq y (+ x 8)) ; => 50
```

---

### LET(bindings, ...body)

Creates local variable bindings for the execution of a body of expressions. All binding expressions are evaluated in the current environment before the new scope is created.

**Syntax:**
```lua
expr.LET(bindings, ...body)
```

**Parameters:**
- `bindings` (array): Array of `{name, expr}` pairs
- `...body` (expressions): Body expressions to execute with bindings

**Returns:** The value of the last body expression

**Example:**
```lisp
(let ((x 10) (y 20))
  (+ x y))  ; => 30

(let ((a 5))
  (* a a))  ; => 25
```

**Notes:**
- Bindings are evaluated in parallel (not sequentially)
- Use nested `let` for sequential dependencies

---

## Control Flow

### IF(condExpr, thenExpr, elseExpr)

Conditional branching based on a test expression.

**Syntax:**
```lua
expr.IF(condExpr, thenExpr, elseExpr)
```

**Parameters:**
- `condExpr` (expression): Test expression
- `thenExpr` (expression): Expression to evaluate if test is truthy
- `elseExpr` (expression): Expression to evaluate if test is falsy

**Returns:** Value from the executed branch

**Example:**
```lisp
(if (< 3 5) "yes" "no")  ; => "yes"
(if false 1 2)           ; => 2
```

**Notes:**
- In Lisp layer: only `false` (nil) is falsy, everything else is truthy
- Only the selected branch is evaluated

---

### COND(...clauses)

Multi-way conditional. Tests clauses in order and executes the first matching one.

**Syntax:**
```lua
expr.COND(...clauses)
```

**Parameters:**
- `...clauses` (arrays): Each clause is `{test, ...exprs}`

**Returns:** Value of the last expression in the matched clause, or `false` if no match

**Example:**
```lisp
(cond
  ((< x 0) "negative")
  ((= x 0) "zero")
  ((> x 0) "positive"))

(cond
  ((< 5 3) 1)
  ((> 5 3) 2)
  (t 3))  ; => 2
```

**Notes:**
- Clauses are tested sequentially
- Use `t` (true) for a default/catch-all clause
- Returns `false` if no clause matches

---

### PROGN(...exprs)

Sequential execution of expressions, returning the value of the last one.

**Syntax:**
```lua
expr.PROGN(...exprs)
```

**Parameters:**
- `...exprs` (expressions): Expressions to execute in order

**Returns:** Value of the last expression

**Example:**
```lisp
(progn
  (setq x 10)
  (setq y 20)
  (+ x y))  ; => 30
```

---

## Logical Operations

### AND(...exprs)

Logical AND with short-circuit evaluation. Returns the last truthy value or `false` on first falsy value.

**Syntax:**
```lua
expr.AND(...exprs)
```

**Parameters:**
- `...exprs` (expressions): Expressions to evaluate

**Returns:** Last value if all truthy, otherwise `false`

**Example:**
```lisp
(and t t t)           ; => true
(and t nil t)         ; => false (short-circuits at nil)
(and (< 5 10) (> 10 5)) ; => true
(and)                 ; => true
```

**Notes:**
- Only `false` (Lisp nil) is falsy
- Short-circuits on first `false` value
- Empty AND returns `true`

---

### OR(...exprs)

Logical OR with short-circuit evaluation. Returns the first truthy value or `false` if all falsy.

**Syntax:**
```lua
expr.OR(...exprs)
```

**Parameters:**
- `...exprs` (expressions): Expressions to evaluate

**Returns:** First truthy value, or `false` if all falsy

**Example:**
```lisp
(or nil nil t)        ; => true
(or nil nil nil)      ; => false
(or 42 nil)          ; => 42 (returns first truthy)
(or)                 ; => false
```

**Notes:**
- Short-circuits on first truthy value
- Returns the actual truthy value (not just `true`)
- Empty OR returns `false`

---

### NOT(expr)

Logical negation.

**Syntax:**
```lua
expr.NOT(expr)
```

**Parameters:**
- `expr` (expression): Expression to negate

**Returns:** `true` if expr is `false`, otherwise `false`

**Example:**
```lisp
(not t)    ; => false
(not nil)  ; => true
(not 42)   ; => false
```

**Notes:**
- Only `false` (Lisp nil) is considered falsy

---

## Functions

### FUNC(params, ...body)

Creates a function with parameters and body expressions.

**Syntax:**
```lua
expr.FUNC(params, ...body)
-- or with rest args:
expr.FUNC({...params, '&rest', restName}, ...body)
```

**Parameters:**
- `params` (array): Parameter names (strings)
- `...body` (expressions): Function body expressions

**Returns:** A function object

**Example:**
```lisp
(lambda (x) (* x 2))          ; double function
(lambda (a b) (+ a b))        ; add function
(lambda (x &rest xs) ...)     ; variadic function
```

**Notes:**
- Functions create a new scope
- Parameters shadow outer variables
- Last expression value is returned
- Supports `&rest` for variadic parameters

---

### FUNCALL(funExpr, ...args)

Calls a function with arguments.

**Syntax:**
```lua
expr.FUNCALL(funExpr, ...args)
```

**Parameters:**
- `funExpr` (expression): Expression evaluating to a function
- `...args` (expressions): Argument expressions

**Returns:** Function return value

**Example:**
```lisp
((lambda (x) (* x 2)) 21)     ; => 42
(progn
  (defun add (a b) (+ a b))
  (add 3 4))                  ; => 7
```

**Notes:**
- Supports Lua functions and continuation functions
- Arguments are evaluated left to right
- Supports tail call optimization in tail position

---

## Loop Constructs

### LOOP(...body)

Infinite loop executing body expressions repeatedly.

**Syntax:**
```lua
expr.LOOP(...body)
```

**Parameters:**
- `...body` (expressions): Body expressions

**Returns:** Value from `break` statement

**Example:**
```lisp
(progn
  (setq i 0)
  (loop
    (setq i (+ i 1))
    (if (> i 5) (break i))))  ; => 6
```

**Notes:**
- Use `break` to exit the loop
- Returns value passed to `break`

---

### BREAK(...exprs)

Exits from the innermost loop with an optional value.

**Syntax:**
```lua
expr.BREAK(...exprs)
```

**Parameters:**
- `...exprs` (optional expressions): Value expressions

**Returns:** N/A (transfers control)

**Example:**
```lisp
(loop
  (if condition (break result)))
```

**Notes:**
- Must be used inside a `loop`
- Can only break from innermost loop
- If no expressions given, returns `nil`

---

## Exception Handling

### CATCH(tag, ...body)

Establishes a catch point for non-local exits. Executes body and catches any `throw` with matching tag.

**Syntax:**
```lua
expr.CATCH(tag, ...body)
```

**Parameters:**
- `tag` (symbol): Tag to identify this catch point
- `...body` (expressions): Body expressions to execute

**Returns:** Value of body expressions, or value thrown to this catch

**Example:**
```lisp
(catch 'exit
  (progn
    (print "start")
    (throw 'exit 42)
    (print "never reached")))  ; => 42

(catch 'error
  (if (< x 0)
    (throw 'error "negative value")
    (* x 2)))
```

**Notes:**
- Tag must be a symbol (quoted)
- `throw` transfers control to matching `catch`
- Unwinds stack to catch point
- Can nest catches with different tags

---

### THROW(tag, ...exprs)

Non-local exit to a catch point with matching tag.

**Syntax:**
```lua
expr.THROW(tag, ...exprs)
```

**Parameters:**
- `tag` (symbol): Tag identifying the target catch
- `...exprs` (optional expressions): Value expressions to return

**Returns:** N/A (transfers control)

**Example:**
```lisp
(catch 'done
  (loop
    (if (> counter 100)
      (throw 'done counter))))  ; Exit loop and catch

(defun validate (x)
  (if (null? x)
    (throw 'error "nil value")))

(catch 'error
  (validate data))
```

**Notes:**
- Must have matching `catch` in dynamic scope
- Error if no matching catch found
- Unwinds through function calls and loops
- Returns last expression value (or `false` if none)

---

## Coroutines

### CREATE-COROUTINE(func)

Creates a new coroutine from a function. The coroutine captures the current environment and can be resumed later.

**Syntax:**
```lua
expr.CREATE_COROUTINE(func)
```

**Parameters:**
- `func` (expression): Function to run as coroutine (typically lambda)

**Returns:** A coroutine object

**Example:**
```lisp
(setq co (create-coroutine
  (lambda ()
    (yield 10)
    (yield 20)
    30)))

(defun make-generator (start end)
  (create-coroutine
    (lambda (n)
      (loop
        (if (> n end) (break))
        (yield n)
        (setq n (+ n 1))))))
```

**Notes:**
- Function runs when first resumed
- Captures environment at creation time
- Can pass values through resume/yield
- Coroutine is reusable until it completes

---

### RESUME(coroExpr, ...args)

Resumes a coroutine, optionally passing values to it.

**Syntax:**
```lua
expr.RESUME(coroExpr, ...args)
```

**Parameters:**
- `coroExpr` (expression): Expression evaluating to a coroutine
- `...args` (expressions): Values to pass to the coroutine

**Returns:** Values yielded by the coroutine, or final return value

**Example:**
```lisp
(setq co (create-coroutine
  (lambda ()
    (yield 1)
    (yield 2)
    3)))

(resume co)   ; => true, 1 (first yield)
(resume co)   ; => true, 2 (second yield)
(resume co)   ; => true, 3 (returns and dies)
(resume co)   ; => Error: can't resume dead coroutine

; Passing values:
(setq co2 (create-coroutine
  (lambda (x)
    (setq result (yield (* x 2)))
    (+ result 10))))

(resume co2 5)   ; => true, 10 (yields x*2)
(resume co2 3)   ; => true, 13 (returns 3+10)
```

**Notes:**
- First resume starts coroutine and passes args to function
- Subsequent resumes continue from yield point
- Returns `(true, value)` on success
- Returns `(false, error)` on error
- Error if coroutine is dead (already completed)

---

### YIELD(...exprs)

Suspends the current coroutine and returns control to the resumer.

**Syntax:**
```lua
expr.YIELD(...exprs)
```

**Parameters:**
- `...exprs` (expressions): Values to return to resumer

**Returns:** Values passed by next resume

**Example:**
```lisp
(defun producer ()
  (create-coroutine
    (lambda ()
      (yield "first")
      (yield "second")
      (yield "third")
      "done")))

(setq p (producer))
(resume p)  ; => true, "first"
(resume p)  ; => true, "second"
(resume p)  ; => true, "third"
(resume p)  ; => true, "done"

; Generator pattern:
(setq counter (create-coroutine
  (lambda (n)
    (loop
      (yield n)
      (setq n (+ n 1))))))

(resume counter 1)  ; => true, 1
(resume counter)    ; => true, 2
(resume counter)    ; => true, 3
```

**Notes:**
- Must be called inside a coroutine
- Error if called outside coroutine context
- Saves continuation and returns to resumer
- Next resume continues from after yield
- Can pass values back and forth with resumer

---

## Coroutine Patterns

### Generator Pattern
```lisp
(defun range (start end)
  (create-coroutine
    (lambda (n)
      (loop
        (if (> n end) (break))
        (yield n)
        (setq n (+ n 1))))))

(setq gen (range 1 5))
(resume gen 1)  ; Start with 1
(resume gen)    ; Get 2
(resume gen)    ; Get 3
```

### Producer-Consumer
```lisp
(setq producer (create-coroutine
  (lambda ()
    (yield "item1")
    (yield "item2")
    (yield "item3"))))

(setq item1 (resume producer))
(process item1)
(setq item2 (resume producer))
(process item2)
```

### Cooperative Multitasking
```lisp
(setq task1 (create-coroutine
  (lambda ()
    (print "task1-step1")
    (yield)
    (print "task1-step2")
    (yield)
    (print "task1-done"))))

(setq task2 (create-coroutine
  (lambda ()
    (print "task2-step1")
    (yield)
    (print "task2-step2"))))

; Scheduler:
(loop
  (if (not (resume task1)) (break))
  (if (not (resume task2)) (break)))
```

---

### RETURN(...exprs)

Early return from a function with an optional value.

**Syntax:**
```lua
expr.RETURN(...exprs)
```

**Parameters:**
- `...exprs` (optional expressions): Value expressions

**Returns:** N/A (transfers control)

**Example:**
```lisp
(defun check-sign (x)
  (if (< x 0) (return "negative"))
  "positive")
```

**Notes:**
- Must be used inside a function
- Can return from within loops inside functions
- If no expressions given, returns `nil`

---

## Multiple Values

### VALUES(...exprs)

Returns multiple values from an expression.

**Syntax:**
```lua
expr.VALUES(...exprs)
```

**Parameters:**
- `...exprs` (expressions): Value expressions

**Returns:** Multiple values

**Example:**
```lisp
(values 1 2 3)        ; Returns three values
(defun multi () (values 10 20 30))
```

**Notes:**
- Only the first value is typically captured
- Used for multiple return values from functions
- Empty `values` returns no value

---

## List Operations

### LIST(...exprs)

Creates a list from evaluated expressions.

**Syntax:**
```lua
expr.LIST(...exprs)
```

**Parameters:**
- `...exprs` (expressions): Elements to put in list

**Returns:** A list (Lua table array), or `false` for empty list

**Example:**
```lisp
(list 1 2 3)     ; => {1, 2, 3}
(list)           ; => false (empty list is nil)
(list (+ 1 2) (* 3 4))  ; => {3, 12}
```

**Notes:**
- Empty list is represented as `false` (Lisp nil)
- Lists are represented as Lua tables

---

### CONS(carExpr, cdrExpr)

Constructs a list by prepending an element to a list.

**Syntax:**
```lua
expr.CONS(carExpr, cdrExpr)
```

**Parameters:**
- `carExpr` (expression): Element to prepend
- `cdrExpr` (expression): List (or value for improper list)

**Returns:** New list with element prepended

**Example:**
```lisp
(cons 1 (list 2 3))   ; => {1, 2, 3}
(cons 1 nil)          ; => {1}
(cons 1 (cons 2 nil)) ; => {1, 2}
```

**Notes:**
- If cdr is `false` (nil), creates single-element list
- If cdr is a list, creates proper list
- If cdr is non-list/non-nil, creates improper list (dotted pair)

---

### CAR(listExpr)

Returns the first element of a list.

**Syntax:**
```lua
expr.CAR(listExpr)
```

**Parameters:**
- `listExpr` (expression): List expression

**Returns:** First element of the list

**Example:**
```lisp
(car (list 10 20 30))  ; => 10
(setq lst (list 1 2 3))
(car lst)              ; => 1
```

**Notes:**
- Error if list is empty or not a list
- Returns `false` on error

---

### CDR(listExpr)

Returns all but the first element of a list (the "rest").

**Syntax:**
```lua
expr.CDR(listExpr)
```

**Parameters:**
- `listExpr` (expression): List expression

**Returns:** Rest of the list, or `false` if only one element

**Example:**
```lisp
(cdr (list 10 20 30))  ; => {20, 30}
(cdr (list 1))         ; => false (empty rest)
```

**Notes:**
- Returns `false` (nil) for empty rest
- Error if list is empty or not a list

---

### NULLP(expr)

Tests if a value is `false` (Lisp nil) or an empty list.

**Syntax:**
```lua
expr.NULLP(expr)
```

**Parameters:**
- `expr` (expression): Expression to test

**Returns:** `true` if null, otherwise `false`

**Example:**
```lisp
(null? nil)        ; => true
(null? (list))     ; => true
(null? (list 1))   ; => false
(null? 0)          ; => false
```

**Notes:**
- `false` (Lisp nil) is considered null
- Empty lists `{}` are considered null
- All other values (including 0) are not null

---

## Special Constants

### NIL()

Returns the Lisp nil value (represented as `false` in Lua).

**Example:**
```lisp
nil  ; => false
```

---

### TRUE()

Returns the boolean true value.

**Example:**
```lisp
t    ; => true
true ; => true
```

---

### FALSE()

Returns the Lisp nil/false value.

**Example:**
```lisp
false ; => false
nil   ; => false
```

---

## Environment Operations

The environment provides variable scoping and frame management:

### Environment Methods

- `env:getVar(name)` - Get variable value
- `env:setVar(name, val)` - Set variable value
- `env:setLocal(name, val)` - Set local variable
- `env:setGlobal(name, val)` - Set global variable
- `env:getGlobal(name)` - Get global variable
- `env:pushFrame(locals)` - Push new scope frame
- `env:popFrame()` - Pop scope frame
- `env:copy()` - Copy environment

### Frame Stack

The environment maintains a frame stack for lexical scoping:
- Global variables persist across frames
- Local variables are frame-scoped
- `let` and function calls push new frames
- Frames are automatically popped on exit

---

## Implementation Notes

### Truthiness

In the Lisp layer:
- `false` (nil) is the only falsy value
- Everything else is truthy (including `0`, `""`, empty tables)

### Tail Call Optimization

Functions in tail position are optimized:
- Current frame is popped before the call
- Enables unbounded recursion without stack growth

### Error Handling

Errors are handled via `env.error`:
- Continuation function for error reporting
- Can be customized by language layer
- Default implementation prints and raises error

### Execution Model

The VM uses a trampoline pattern:
- Iterative execution (no recursion)
- Prevents stack overflow
- Configurable step limit (default: 100,000 steps)

---

## Usage Example

```lua
local VM = require("Continuation")

-- Create environment
local env = VM.createEnvironment()

-- Add Lua function
env:setVar("add", function(a, b) return a + b end)

-- Build expression
local expr = VM.expr.FUNCALL(
  VM.expr.VAR("add"),
  VM.expr.CONST(3),
  VM.expr.CONST(4)
)

-- Execute
local ok, err, steps = VM.execute(
  expr,
  function(result) 
    print("Result:", result)  -- Prints: Result: 7
    return nil 
  end,
  env
)
```

---

## See Also

- `Lisp.lua` - Lisp language implementation using these primitives
- `tests.lisp` - Comprehensive test suite demonstrating usage
