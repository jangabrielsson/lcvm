local function main(er)
end


function QuickApp:onInit()
  self:debug("ER6 version",fibaro.ER.version)
  fibaro.ER.run(main)
end