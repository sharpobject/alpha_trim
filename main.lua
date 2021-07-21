local json = require"dkjson"

function mkdir(dirname)
  os.execute("mkdir \"" .. dirname.."\"")
end

function recursive_enumerate(folder, cb)
  local lfs = love.filesystem
  local filesTable = lfs.getDirectoryItems(folder)
  mkdir("out_"..folder)
  for i,v in ipairs(filesTable) do
    local file = folder.."/"..v
    if lfs.getInfo(file).type == "file" then
      cb(file)
    elseif lfs.getInfo(file).type == "directory" then
      fileTree = recursive_enumerate(file, cb)
    end
  end
end

trim_data = {}

HUGE = 1e99
TINY = -HUGE

function trim(img, filename)
  local w,h = img:getDimensions()
  local min_x, min_y, max_x, max_y = nil, nil, nil, nil
  local r,g,b,a
  -- find min_x
  for x=0,w-1 do
    for y=0,h-1 do
      r,g,b,a = img:getPixel(x,y)
      if a > 0 then
        min_x = x
        goto brk1
      end
    end
  end
  ::brk1::
  if min_x then
    -- find max_x
    for x=w-1,min_x,-1 do
      for y=0,h-1 do
        r,g,b,a = img:getPixel(x,y)
        if a > 0 then
          max_x = x
          goto brk2
        end
      end
    end
    ::brk2::
    -- find min_y
    for y=0,h do
      for x=min_x,max_x do
        r,g,b,a = img:getPixel(x,y)
        if a > 0 then
          min_y = y
          goto brk3
        end
      end
    end
    ::brk3::
    -- find max_y
    for y=h-1,min_y,-1 do
      for x=min_x,max_x do
        r,g,b,a = img:getPixel(x,y)
        if a > 0 then
          max_y = y
          goto brk4
        end
      end
    end
    ::brk4::
  else
    min_x, max_x, min_y, max_y = 0,0,0,0
  end--]]
  --[[min_x, min_y, max_x, max_y = HUGE, HUGE, TINY, TINY
  img:mapPixel(function(x,y,r,g,b,a)
    if a > 0 then
      if x < min_x then
        min_x = x
      end
      if y < min_y then
        min_y = y
      end
      if x > max_x then
        max_x = x
      end
      if y > max_y then
        max_y = y
      end
    end
    return r,g,b,a
  end)
  if min_y == HUGE then
    min_x, max_x, min_y, max_y = 0,0,0,0
  end--]]
  local out_w, out_h = max_x-min_x+1, max_y-min_y+1
  local ret = love.image.newImageData(out_w, out_h)
  ret:paste(img, 0, 0, min_x, min_y, out_w, out_h)
  trim_data[filename:sub(#"selfbirb"+2)] = {min_x, min_y, w, h}
  return ret
end

function copy_or_trim(filename)
  local ok, img = pcall(function() return love.image.newImageData(filename) end)
  if ok then
    img = trim(img, filename)
    imagedata_to_file(img, "out_"..filename)
  else
    file_to_file(filename, "out_"..filename)
  end
end

function love.load(arg)
  recursive_enumerate("selfbirb", copy_or_trim)
  set_file("out_selfbirb/trim.json", json.encode(trim_data))
  love.graphics.setCanvas()
  love.event.quit()
end

function set_file(filename, contents)
  local file = io.open(filename, "w")
  file:write(contents)
  file:close()
end

function file_to_file(in_name, out_name)
  local s = love.filesystem.read(in_name)
  set_file(out_name, s)
end

function imagedata_to_file(imagedata, filename)
  local data = imagedata:encode("png")
  local file = io.open(filename, "w")
  local sofar = 0
  local chunk_sz = 64*1024
  while sofar < data:getSize() do
    collectgarbage("collect")
    local chunk = chunk_sz
    local upper_bound = sofar + chunk
    if upper_bound > data:getSize() then
      chunk = data:getSize() - sofar
    end
    local view = love.data.newDataView(data, sofar, chunk)
    file:write(view:getString())
    sofar = sofar + chunk
  end
  --file:write(data:getString())
  file:close()
end
