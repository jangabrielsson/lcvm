# CATCH/THROW Exception Handling Design

## Overview

This document explores how to add exception handling (catch/throw) to the Continuation VM, including integration with the existing `env.error` mechanism.

## Design Goals

1. **Non-local exits**: Ability to unwind the stack to a catch point
2. **Tagged catches**: Support multiple catch blocks with different tags (like Common Lisp)
3. **Any value throwable**: Allow throwing any value (strings, numbers, objects)
4. **Integration with env.error**: Built-in errors should be catchable
5. **Nested catches**: Inner catches should shadow outer ones

## Core Primitives

### CATCH(tagExpr, ...body)

Sets up an exception handler for a specific tag.

**Behavior:**
- Evaluates `tagExpr` to get the catch tag
- Executes body expressions
- If THROW is called with matching tag, catches the value and returns it
- Otherwise, returns the normal result of the body

**Example:**
```lisp
(catch 'my-error
  (progn
    (if bad-condition (throw 'my-error "Something went wrong"))
    "normal result"))
```

### THROW(tagExpr, [valueExpr])

Throws an exception to the nearest matching catch block.

**Behavior:**
- Evaluates `tagExpr` to get the tag
- Evaluates `valueExpr` (if provided) to get the thrown value
- Searches up the stack for a matching CATCH
- Transfers control to the CATCH, returning the thrown value
- If no matching CATCH found, raises an unhandled exception

**Example:**
```lisp
(throw 'error "File not found")
(throw 'retry-needed)
```

## Implementation Strategy

### Environment Extensions

The environment needs to maintain a catch stack:

```lua
-- In createEnvironment():
self.__catchStack = {}  -- Stack of {tag, cont} pairs

function self:pushCatch(tag, cont)
  table.insert(self.__catchStack, {tag = tag, cont = cont})
end

function self:popCatch()
  table.remove(self.__catchStack)
end

function self:findCatch(tag)
  -- Search from innermost to outermost
  for i = #self.__catchStack, 1, -1 do
    if self.__catchStack[i].tag == tag then
      return self.__catchStack[i].cont
    end
  end
  return nil  -- No matching catch found
end
```

### CATCH Implementation

```lua
local function CATCH(tagExpr, ...)
  local body = {...}
  
  return function(cont, env)
    -- First evaluate the tag
    return tagExpr, function(tag)
      -- Set up catch continuation
      local catchCont = function(value)
        -- Pop this catch and return the thrown value
        env:popCatch()
        return cont(value)
      end
      
      -- Push catch onto stack
      env:pushCatch(tag, catchCont)
      
      -- Execute body
      return evalExprs(body, function(...)
        -- Normal completion: pop catch and continue
        env:popCatch()
        return cont(...)
      end, env)
    end
  end
end

expr.CATCH = EXPR(CATCH, "(CATCH %1 ...)")
```

### THROW Implementation

```lua
local function THROW(tagExpr, valueExpr)
  return function(cont, env)
    return tagExpr, function(tag)
      -- Find matching catch
      local catchCont = env:findCatch(tag)
      
      if not catchCont then
        -- No matching catch - unhandled exception
        local msg = string.format("Uncaught throw: %s", tostring(tag))
        if env.error then env.error(msg) end
        error(msg, 0)
      end
      
      -- If no value expression, throw nil
      if not valueExpr then
        return catchCont(nil)
      end
      
      -- Evaluate value expression and throw it
      return valueExpr, function(value)
        return catchCont(value)
      end
    end
  end
end

expr.THROW = EXPR(THROW, "(THROW %1 [%2])")
```

## Error Representation Options

### Option 1: Simple Values (Recommended for initial implementation)

**Approach:** Allow throwing any Lua value (strings, numbers, tables, etc.)

**Pros:**
- Simple and flexible
- No special error types needed
- Easy to implement

**Cons:**
- No standard error structure
- Harder to distinguish error types programmatically

**Example:**
```lisp
(throw 'error "File not found")
(throw 'error 404)
(throw 'error {type: "io", message: "File not found"})
```

### Option 2: Structured Error Objects

**Approach:** Define a standard error structure

**Structure:**
```lua
{
  type = "error",
  tag = "io-error",
  message = "File not found",
  data = {...}  -- Additional context
}
```

**Pros:**
- Consistent error handling
- Can add stack traces, error codes, etc.
- Better tooling support

**Cons:**
- More complex
- Users might still want to throw simple values

**Example:**
```lisp
(throw 'error (make-error "io-error" "File not found" {file: path}))
```

### Option 3: Hybrid Approach (Recommended)

**Approach:** Allow any value, but provide helpers for structured errors

```lua
-- Helper function
function makeError(tag, message, data)
  return {
    type = "error",
    tag = tag,
    message = message,
    data = data or {}
  }
end

-- Users can throw anything:
(throw 'error "simple string")
(throw 'error (make-error "io" "File not found" {file: path}))
```

## env.error Integration

### Current Behavior

Currently, `env.error` is called by built-in functions (CAR, CDR, etc.) when they encounter errors:

```lua
if not list then
  if env.error then env.error("CAR: not a list") end
  return cont(false)
end
```

### Integration Options

#### Option A: Make env.error throw (Recommended)

**Approach:** Convert `env.error` calls into throws with a special error tag

```lua
-- In createEnvironment():
self.error = function(msg)
  local errorCont = self:findCatch('error)
  if errorCont then
    -- There's a catch for errors, throw to it
    return errorCont({
      type = "builtin-error",
      message = msg
    })
  else
    -- No catch, fatal error
    print("ERROR: " .. msg)
    error(msg, 0)
  end
end
```

**Usage:**
```lisp
; Catch built-in errors
(catch 'error
  (car nil)  ; Throws error that gets caught
  )

; Without catch, errors are fatal (current behavior)
(car nil)  ; Fatal error
```

**Pros:**
- Consistent with catch/throw
- Built-in errors become catchable
- Backward compatible (uncaught errors still fatal)

**Cons:**
- Changes execution model slightly
- Need to ensure error continuation is properly restored

#### Option B: Separate error tag

**Approach:** Use a different tag for built-in errors

```lua
self.error = function(msg)
  local errorCont = self:findCatch('builtin-error)
  if errorCont then
    return errorCont(msg)
  else
    print("ERROR: " .. msg)
    error(msg, 0)
  end
end
```

**Usage:**
```lisp
(catch 'builtin-error
  (car nil))

(catch 'my-error
  (throw 'my-error "user error"))
```

**Pros:**
- Clear distinction between built-in and user errors
- Can catch them separately

**Cons:**
- Users need to know two different tags
- More verbose

#### Option C: Keep env.error separate (Not recommended)

**Approach:** Don't integrate `env.error` with catch/throw

**Pros:**
- Simpler implementation
- Clear separation of concerns

**Cons:**
- Inconsistent error handling
- Can't catch built-in errors
- Less useful overall

### Recommended: Option A with convenience

Provide both a general 'error tag and specific tags:

```lua
self.error = function(msg, tag)
  tag = tag or 'error
  local errorCont = self:findCatch(tag)
  if errorCont then
    return errorCont({
      type = "builtin-error",
      tag = tag,
      message = msg
    })
  else
    print("ERROR: " .. msg)
    error(msg, 0)
  end
end
```

This allows:
```lisp
; Catch all errors
(catch 'error ...)

; Catch specific error types
(catch 'io-error ...)
```

## Stack Unwinding

When THROW unwinds the stack, we need to clean up:

### Resources to Clean

1. **Catch blocks**: Remove from catch stack
2. **Environment frames**: Pop frames created by LET and FUNC
3. **Loop continuations**: Clear loop contexts
4. **Function continuations**: Clear function contexts

### Implementation

```lua
local function THROW(tagExpr, valueExpr)
  return function(cont, env)
    return tagExpr, function(tag)
      local catchCont = env:findCatch(tag)
      
      if not catchCont then
        error("Uncaught throw: " .. tostring(tag))
      end
      
      -- Clean up: Pop catch entries up to and including the matched one
      -- The findCatch already gives us the continuation
      -- The cleanup happens automatically as we unwind
      
      if not valueExpr then
        return catchCont(nil)
      end
      
      return valueExpr, function(value)
        return catchCont(value)
      end
    end
  end
end
```

**Note:** Because we're using CPS, the stack unwinding happens naturally. When we invoke `catchCont`, we're abandoning the current continuation chain and jumping to the catch continuation. All intermediate continuations are simply not called, allowing Lua's GC to clean them up.

## Usage Examples

### Basic Catch/Throw

```lisp
(defun safe-divide (a b)
  (catch 'division-error
    (if (= b 0)
      (throw 'division-error "Division by zero")
      (/ a b))))

(safe-divide 10 2)  ; => 5
(safe-divide 10 0)  ; => "Division by zero"
```

### Nested Catches

```lisp
(catch 'outer
  (catch 'inner
    (if condition-1 (throw 'inner "inner error"))
    (if condition-2 (throw 'outer "outer error"))
    "normal result"))
```

### Error Recovery

```lisp
(defun read-file-safe (path)
  (catch 'io-error
    (read-file path)))  ; May throw 'io-error

(setq content (read-file-safe "data.txt"))
(if (is-error? content)
  (print "Using default data")
  (process content))
```

### Retry Logic

```lisp
(defun retry (n f)
  (catch 'retry
    (loop
      (catch 'error
        (return (f)))  ; Try the function
      ; If we get here, there was an error
      (setq n (- n 1))
      (if (<= n 0)
        (throw 'retry "Max retries exceeded")
        (print "Retrying...")))))

(retry 3 (lambda () (fetch-data)))
```

## Lisp Layer Integration

### Compilation

```lua
-- In Lisp.lua spec table:
spec['catch'] = function(expr, ctx)
  assert(#expr >= 3, "catch requires tag and body")
  local tag = compile(expr[2], ctx)
  local body = {}
  for i = 3, #expr do
    body[#body+1] = compile(expr[i], ctx)
  end
  return VM.expr.CATCH(tag, table.unpack(body))
end

spec['throw'] = function(expr, ctx)
  assert(#expr >= 2, "throw requires tag")
  local tag = compile(expr[2], ctx)
  local value = expr[3] and compile(expr[3], ctx) or nil
  if value then
    return VM.expr.THROW(tag, value)
  else
    return VM.expr.THROW(tag)
  end
end
```

## Testing Strategy

### Test Cases Needed

1. **Basic catch/throw**
   - Throw and catch simple values
   - Throw without value
   
2. **Nested catches**
   - Inner catch shadows outer
   - Throw to outer catch from inner block
   
3. **Unhandled throws**
   - Verify error when no matching catch
   
4. **Stack unwinding**
   - Verify cleanup of frames
   - Verify loop/function contexts cleared
   
5. **Built-in error catching**
   - Catch errors from CAR, CDR, etc.
   
6. **Integration with other features**
   - Catch/throw in functions
   - Catch/throw in loops
   - Catch/throw with multiple values

### Example Tests

```lisp
(test "basic catch/throw"
  (catch 'err (throw 'err 42))
  42)

(test "nested catch"
  (catch 'outer
    (catch 'inner
      (throw 'outer "outer"))
    "inner")
  "outer")

(test "catch built-in error"
  (catch 'error
    (car nil))
  {type: "builtin-error", message: "CAR: not a list or empty list"})
```

## Implementation Checklist

- [ ] Add catch stack to environment (`__catchStack`)
- [ ] Implement `pushCatch`, `popCatch`, `findCatch` methods
- [ ] Implement CATCH primitive
- [ ] Implement THROW primitive
- [ ] Update env.error to integrate with catch/throw
- [ ] Add EXPR wrappers for CATCH and THROW
- [ ] Add Lisp compilation specs for catch and throw
- [ ] Write comprehensive tests
- [ ] Update documentation
- [ ] Consider unwind-protect for cleanup (future enhancement)

## Future Enhancements

### UNWIND-PROTECT

For guaranteed cleanup, similar to try/finally:

```lisp
(unwind-protect
  (progn
    (open-file "data.txt")
    (process-data))
  ; Cleanup form - always executed
  (close-file))
```

This would require tracking protected sections and ensuring cleanup forms run even during stack unwinding.

### Condition System

More sophisticated error handling like Common Lisp conditions:
- Conditions (structured error objects)
- Restarts (recovery options)
- Handler-bind (catch without unwinding)

## Conclusion

The recommended implementation is:

1. **Use tagged catch/throw** for flexibility
2. **Allow any value to be thrown** for simplicity
3. **Integrate env.error with 'error tag** for consistency
4. **Natural stack unwinding** via CPS model

This provides a clean, powerful exception handling mechanism that integrates well with the existing VM architecture.
