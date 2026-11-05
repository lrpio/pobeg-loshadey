-- Проверка синтаксиса всех .luau файлов проекта (компиляция без запуска)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local bad = 0
local count = 0
local function walk(dir)
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:match("%.luau$") then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				bad += 1
				print("ОШИБКА " .. path .. ": " .. tostring(err))
			end
		end
	end
end
walk("src")
print(("Проверено файлов: %d, с ошибками: %d"):format(count, bad))
if bad > 0 then
	process.exit(1)
end
