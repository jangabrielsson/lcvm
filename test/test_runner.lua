--%%offline:true 
--%%file:Continuation.lua,cont
--%%file:Lisp.lua,Lisp

local function readFile(filename)
  local file = io.open(filename, "r")
  if not file then
    error("Could not open file: " .. filename)
  end
  local content = file:read("*all")
  file:close()
  return content
end

local function runTests(testFile, options)
  options = options or {}
  local verbose = options.verbose or false
  
  print("\n" .. string.rep("=", 70))
  print("Running Lisp Test Suite")
  print(string.rep("=", 70) .. "\n")
  
  local content = readFile(testFile)
  local lisp = Lisp()
  
  -- Parse all s-expressions from the file
  local stream = lisp:parseStream(content)
  
  local passed = 0
  local failed = 0
  local totalTime = 0
  local results = {}
  
  for sexpr in stream do
    -- Each test should be: (test "description" expr expected)
    if type(sexpr) == 'table' and sexpr[1] == 'test' then
      local desc = sexpr[2]
      local expr = sexpr[3]
      local expected = sexpr[4]
      
      if not desc or not expr or expected == nil then
        print("  ✗ FAIL  Malformed test: " .. tostring(sexpr))
        failed = failed + 1
      else
        -- Create fresh environment for this test
        local testLisp = Lisp()
        
        -- Evaluate expected value
        local expectedResult = testLisp:eval(expected)
        
        -- Check if expected is a list (for multiple return values)
        local expectMultiple = type(expectedResult) == "table" and expectedResult[1] ~= nil
        
        -- Run test
        local startTime = os.clock()
        local success, actualResults
        if expectMultiple then
          -- Capture multiple return values
          success, actualResults = pcall(function()
            return {testLisp:eval(expr)}
          end)
        else
          -- Single return value
          success, actualResults = pcall(function()
            return testLisp:eval(expr)
          end)
        end
        local endTime = os.clock()
        local duration = (endTime - startTime) * 1000 -- Convert to ms
        totalTime = totalTime + duration
        
        local testPassed = false
        local errorMsg = nil
        
        if success then
          if expectMultiple then
            -- Compare multiple values
            local match = true
            if type(actualResults) ~= "table" or type(expectedResult) ~= "table" then
              match = false
            elseif #actualResults ~= #expectedResult then
              match = false
            else
              for i = 1, #expectedResult do
                local a, e = actualResults[i], expectedResult[i]
                if type(a) ~= type(e) then
                  match = false
                  break
                elseif type(a) == "table" then
                  -- Compare table contents (shallow)
                  if #a ~= #e then
                    match = false
                    break
                  end
                  for j = 1, #a do
                    if a[j] ~= e[j] then
                      match = false
                      break
                    end
                  end
                elseif a ~= e then
                  match = false
                  break
                end
              end
            end
            
            if match then
              testPassed = true
              passed = passed + 1
            else
              failed = failed + 1
              local function formatList(t)
                if type(t) ~= "table" then return tostring(t) end
                local parts = {}
                for i, v in ipairs(t) do
                  parts[i] = tostring(v)
                end
                return "(" .. table.concat(parts, " ") .. ")"
              end
              errorMsg = string.format("Expected %s, got %s", 
                formatList(expectedResult), formatList(actualResults))
            end
          else
            -- Single value comparison
            if actualResults == expectedResult then
              testPassed = true
              passed = passed + 1
            else
              failed = failed + 1
              errorMsg = string.format("Expected %s, got %s", 
                tostring(expectedResult), tostring(actualResults))
            end
          end
        else
          failed = failed + 1
          errorMsg = "Error: " .. tostring(actualResults)
        end
        
        table.insert(results, {
          description = desc,
          passed = testPassed,
          error = errorMsg,
          duration = duration
        })
        
        -- Print result
        local status = testPassed and "✓ PASS" or "✗ FAIL"
        print(string.format("  %s  %s (%.2fms)", status, desc, duration))
        if verbose then
          print(string.format("         Expression: %s", tostring(expr)))
          print(string.format("         Expected: %s", tostring(expectedResult)))
          if not testPassed then
            print(string.format("         Got: %s", tostring(actualResults)))
          end
        elseif not testPassed and errorMsg then
          print(string.format("         %s", errorMsg))
        end
      end
    end
  end
  
  -- Print summary
  print("\n" .. string.rep("=", 70))
  print(string.format("Test Summary: %d passed, %d failed, %d total", 
    passed, failed, passed + failed))
  print(string.format("Total time: %.2fms", totalTime))
  print(string.rep("=", 70) .. "\n")
  
  return passed, failed, results
end

-- Run tests
local testFile = "test/tests.lisp"

-- Check for --verbose flag in environment variable
local verbose = os.getenv("VERBOSE") == "1" or os.getenv("VERBOSE") == "true"

local passed, failed, results = runTests(testFile, {verbose = verbose})

-- Exit with appropriate code
os.exit(failed == 0 and 0 or 1)
