----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- LEX
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function lex(data)
	local i = 1

	-- display elaborate error message with exact location of the error
	local function lnerror(msg,lvl)
		-- find start of line
		local a = i
		while true do
			a = a - 1
			if a == 0 or data:sub(a,a) == '\n' or data:sub(a-1,a) == '\r\n' then
				a = a + 1
				break
			end
		end

		-- find end of line
		local b = i
		while true do
			if data:sub(b-1,b) == '\r\n' then
				b = b - 2
				break
			end
			if b == #data+1
			or data:sub(b,b+1) == '\r\n'
			or data:sub(b,b) == '\n'then
				b = b - 1
				break
			end
			b = b + 1
		end

		-- find line number (row)
		local r = 1 do
			local n = i
			while true do
				n = n - 1
				if data:sub(n,n) == '\n' then
					r = r + 1
					local q = n - 1
					if data:sub(q,q) == '\r' then
						n = q
					end
				end
				if n <= 0 then
					break
				end
			end
		end

		-- get line and convert tabs to spaces
		local ln = data:sub(a,b):gsub('\t'," ")
		-- column
		local c = i - a + 1
		-- display exact character where error occurred
		local pt = string.rep(" ",c - 1) .. "^"
		error(msg .. ":" .. r .. ":" .. c .. ":\n" .. ln .. "\n" .. pt,(lvl or 1) + 1)
	end

	local function lnassert(c,msg,lvl)
		if not c then
			lnerror(msg,lvl+1)
		end
		return c
	end

	-- compares the current position with `s`
	local function is(s)
		return data:sub(i,i+#s-1) == s
	end

	-- expect `s` at the current location; errors if it isn't
	local function expect(s,lvl)
		local c = data:sub(i,i+#s-1) == s
		if not c then
			lnerror("`" .. s .. "` expected",lvl+1)
		end
		i = i + #s
	end

	-- skips over whitespace (excluding lines)
	local whiteChars = {[' ']=true,['\t']=true}
	local function white()
		while whiteChars[data:sub(i,i)] do i = i + 1 end
	end

	-- a Word may contain letters, numbers and underscores
	local lexWord do
		local wordChars = {
			['0']=true,['1']=true,['2']=true,['3']=true,['4']=true,['5']=true;
			['6']=true,['7']=true,['8']=true,['9']=true,['a']=true,['b']=true;
			['c']=true,['d']=true,['e']=true,['f']=true,['g']=true,['h']=true;
			['i']=true,['j']=true,['k']=true,['l']=true,['m']=true,['n']=true;
			['o']=true,['p']=true,['q']=true,['r']=true,['s']=true,['t']=true;
			['u']=true,['v']=true,['w']=true,['x']=true,['y']=true,['z']=true;
			['A']=true,['B']=true,['C']=true,['D']=true,['E']=true,['F']=true;
			['G']=true,['H']=true,['I']=true,['J']=true,['K']=true,['L']=true;
			['M']=true,['N']=true,['O']=true,['P']=true,['Q']=true,['R']=true;
			['S']=true,['T']=true,['U']=true,['V']=true,['W']=true,['X']=true;
			['Y']=true,['Z']=true,['_']=true;
		}
		function lexWord()
			local s = i
			while wordChars[data:sub(i,i)] do
				i = i + 1
			end
			if i > s then
				return data:sub(s,i-1)
			else
				return nil
			end
		end
	end

	-- an Int may contain digits 0-9
	local lexInt do
		local digitChars = {
			['0']=true,['1']=true,['2']=true,['3']=true,['4']=true;
			['5']=true,['6']=true,['7']=true,['8']=true,['9']=true;
		}
		function lexInt()
			local s = i
			while digitChars[data:sub(i,i)] do
				i = i + 1
			end
			if i > s then
				return data:sub(s,i-1)
			else
				return nil
			end
		end
	end

	-- Class and member names appear to be unrestricted with the characters
	-- they may contain. So, in order to remain flexible, we'll try to match
	-- the largest feasible occurrence.
	--
	-- Names may contain spaces, but it is not likely they will appear at the
	-- beginning or end of the name, so we'll also trim any trailing
	-- whitespace. Leading whitespace has already been eaten.
	local lexName do
		local char = {['[']=true,['(']=true,[':']=true,['.']=true,['\n']=true,['\r']=true}
		function lexName()
			local s = i
			local n = i
			while not char[data:sub(i,i)] do
				if not whiteChars[data:sub(i,i)] then
					n = i
				end
				i = i + 1
			end
			if i > s then
				return data:sub(s,n)
			else
				return nil
			end
		end
	end

	-- So far, type names appear to be more tame when it comes to characters,
	-- so we'll just treat them as words.
	local function lexType()
		return lexWord()
	end

	-- The exact formatting of default values appears to be undefined, so
	-- we'll try to find as much as possible.
	local function lexDefault()
		local s = i
		while not is',' and not is')' do
			i = i + 1
		end
		-- should not return nil; if blank, the value is probably an empty
		-- string
		return data:sub(s,i-1)
	end

	-- A single argument consists of a type, a name, and a default value,
	-- optionally.
	local function parseArgument(hasDefault)
		local argument = {}
		argument.Type = lnassert(lexType(),"argument type expected",6)
		white()
		argument.Name = lnassert(lexWord(),"argument name expected",6)
		if hasDefault then
			white()
			if is'=' then
				i = i + 1
				white()
				argument.Default = lexDefault()
			end
		end
		return argument
	end

	-- A list of arguments consists of 0 or more comma-separated arguments
	-- enclosed in parentheses.
	local function parseArguments(hasDefault)
		expect('(',5)
		local arguments = {}
		if is')' then
			i = i + 1
		else
			white()
			arguments[#arguments+1] = parseArgument(hasDefault)
			while is',' do
				i = i + 1
				white()
				arguments[#arguments+1] = parseArgument(hasDefault)
			end
			expect(')',5)
		end
		return arguments
	end

	-- Tags are 0 or more bracket-delimited strings that appear after an item.
	local function parseTags()
		local tags = {}
		local s = i
		local depth = 0
		while not is'\n' and not is'\r\n' do
			if is'[' then
				depth = depth + 1
				i = i + 1
				if depth == 1 then
					s = i
				end
			elseif is']' then
				depth = depth - 1
				lnassert(depth >= 0,"unexpected tag closer",4)
				if depth == 0 then
					tags[data:sub(s,i-1)] = true
				end
				i = i + 1
				white()
			elseif i > #data then
				break
			elseif depth == 0 then
				lnerror("unexpected character between tags",4)
			else
				i = i + 1
			end
		end
		if depth ~= 0 then
			lnerror("tag closer expected",4)
		end
		return tags
	end

	local itemTypes = {
		['Class'] = function()
			local item = {}
			item.Name = lnassert(lexName(),"class name expected",4)
			if is':' then
				i = i + 1
				white()
				item.Superclass = lnassert(lexName(),"superclass name expected",4)
			end
			return item
		end;
		['Property'] = function()
			local item = {}
			item.ValueType = lnassert(lexType(),"type expected",4)
			white()
			item.Class = lnassert(lexName(),"class name expected",4)
			expect('.',4)
			item.Name = lnassert(lexName(),"property name expected",4)
			return item
		end;
		['Function'] = function()
			local item = {}
			item.ReturnType = lnassert(lexType(),"type expected",4)
			white()
			item.Class = lnassert(lexName(),"class name expected",4)
			expect(':',4)
			item.Name = lnassert(lexName(),"function name expected",4)
			item.Arguments = parseArguments(true)
			return item
		end;
		['YieldFunction'] = function()
			local item = {}
			item.ReturnType = lnassert(lexType(),"type expected",4)
			white()
			item.Class = lnassert(lexName(),"class name expected",4)
			expect(':',4)
			item.Name = lnassert(lexName(),"yieldfunction name expected",4)
			item.Arguments = parseArguments(true)
			return item
		end;
		['Event'] = function()
			local item = {}
			item.Class = lnassert(lexName(),"class name expected",4)
			expect('.',4)
			item.Name = lnassert(lexName(),"event name expected",4)
			item.Arguments = parseArguments(false)
			return item
		end;
		['Callback'] = function()
			local item = {}
			item.ReturnType = lnassert(lexType(),"type expected",4)
			white()
			item.Class = lnassert(lexName(),"class name expected",4)
			expect('.',4)
			item.Name = lnassert(lexName(),"callback name expected",4)
			item.Arguments = parseArguments(false)
			return item
		end;
		['Enum'] = function()
			local item = {}
			item.Name = lnassert(lexName(),"enum name expected",4)
			return item
		end;
		['EnumItem'] = function()
			local item = {}
			item.Enum = lnassert(lexName(),"enum name expected",4)
			expect('.',4)
			item.Name = lnassert(lexName(),"enum item name expected",4)
			expect(':',4)
			white()
			item.Value = lnassert(tonumber(lexInt()),"enum value (int) expected",4)
			return item
		end;
	}

	-- An item consists of one line of API data. The contents and formatting
	-- of the item depend on the item's type.
	local function parseItem()
		local type = lnassert(lexWord(),"item type expected",3)
		white()
		lnassert(itemTypes[type],"unknown item type `" .. type .. "`",3)
		local item = itemTypes[type]()
		white()
		item.type = type
		item.tags = parseTags(item)

		-- skip over any lines
		while true do
			if is'\n' then
				i = i + 1
			elseif is'\r\n' then
				i = i + 2
			else
				break
			end
		end

		white()
		return item
	end

	-- Items is a list of all of the items parsed from the whole API dump
	-- string.
	local items = {}
	white()
	items[#items+1] = parseItem()
	while i <= #data do
		white()
		items[#items+1] = parseItem()
	end
	if i <= #data then
		lnerror("unexpected character",2)
	end
	return items
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- DIFF
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function argDiff(a,b)
	local equal = true
	if #a ~= #b then
		equal = false
	else
		for i = 1,#a do
			if a[i].Name ~= b[i].Name or a[i].Type ~= b[i].Type or a[i].Default ~= b[i].Default then
				equal = false
				break
			end
		end
	end

	if not equal then
		local copy = {}
		for i = 1,#b do
			local arg = b[i]
			copy[i] = {Type=arg.Type, Name=arg.Name, Default=arg.Default}
		end
		return copy
	else
		return nil
	end
end

-- Returns an immutable identifer for the given item.
local function itemName(item)
	if item.Class then
		return item.Class .. '.' .. item.Name
	elseif item.type == 'EnumItem' then
		return item.Enum .. '.' .. item.Name
	else
		return item.Name
	end
end

-- Return hash table of dump list, so that items are easily comparable.
local function getRef(dump)
	local ref = {}

	for i = 1,#dump do
		local item = dump[i]
		ref[item.type .. ' ' .. itemName(item)] = item
	end

	return ref
end

local function diff(a,b)
	local diffs = {}

	-- compare mutable fields of two items for changes, per item type
	local compare = {}

	function compare.Class(a,b)
		if b.Superclass ~= a.Superclass then
			diffs[#diffs+1] = {0,'Superclass',a,b.Superclass}
		end
	end

	function compare.Property(a,b)
		if b.ValueType ~= a.ValueType then
			diffs[#diffs+1] = {0,'ValueType',a,b.ValueType}
		end
	end

	function compare.Function(a,b)
		if b.ReturnType ~= a.ReturnType then
			diffs[#diffs+1] = {0,'ReturnType',a,b.ReturnType}
		end
		local d = argDiff(a.Arguments,b.Arguments)
		if d then
			diffs[#diffs+1] = {0,'Arguments',a,d}
		end
	end

	compare.YieldFunction = compare.Function

	compare.Callback = compare.Function

	function compare.Event(a,b)
		local d = argDiff(a.Arguments,b.Arguments)
		if d then
			diffs[#diffs+1] = {0,'Arguments',a,d}
		end
	end

	function compare.Enum(a,b)

	end

	function compare.EnumItem(a,b)
		if a.Value ~= b.Value then
			diffs[#diffs+1] = {0,'Value',a,b.Value}
		end
	end

	local aref = getRef(a)
	local bref = getRef(b)

	-- Do initial search through table, looking for added/removed classes and
	-- enums. This will be used later to exclude their members/enumitems from
	-- the top-level diff list, which would also be added/removed.
	local addClass = {}
	local delClass = {}

	local addEnum = {}
	local delEnum = {}

	for name,item in pairs(bref) do
		if not aref[name] then
			if item.type == 'Class' then
				local list = {}
				addClass[item.Name] = list
				-- Add the difference right now. Since the member list is
				-- referenced, it will be populated later.
				diffs[#diffs+1] = {1,'Class',item,list}
			elseif item.type == 'Enum' then
				local list = {}
				addEnum[item.Name] = list
				diffs[#diffs+1] = {1,'Enum',item,list}
			end
		end
	end
	for name,item in pairs(aref) do
		if not bref[name] then
			if item.type == 'Class' then
				local list = {}
				delClass[item.Name] = list
				diffs[#diffs+1] = {-1,'Class',item,list}
			elseif item.type == 'Enum' then
				local list = {}
				delEnum[item.Name] = list
				diffs[#diffs+1] = {-1,'Enum',item,list}
			end
		end
	end

	local secTag = {
		['LocalUserSecurity'] = true;
		['RobloxSecurity'] = true;
		['RobloxPlaceSecurity'] = true;
		['RobloxScriptSecurity'] = true;
		['WritePlayerSecurity'] = true;
	}

	for name,item in pairs(bref) do
		local aitem = aref[name]
		if aitem then
			-- item exists in both `a` and `b`, so compare them for changes
			compare[item.type](aitem,item)

			-- Security tags are (hopefully) mutually exclusive, so we'll
			-- detect them as a change in security level, instead of the
			-- removal of one tag, and the addition of another.
			local secAdd,secRem
			for tag in pairs(item.tags) do
				if not aitem.tags[tag] then
					if secTag[tag] then
						secAdd = tag
					else
						diffs[#diffs+1] = {1,'Tag',aitem,tag}
					end
				end
			end
			for tag in pairs(aitem.tags) do
				if not item.tags[tag] then
					if secTag[tag] then
						secRem = tag
					else
						diffs[#diffs+1] = {-1,'Tag',aitem,tag}
					end
				end
			end
			if secAdd or secRem then
				-- secAdd or secRem may be nil, which can be interpreted as no
				-- security
				diffs[#diffs+1] = {0,'Security',aitem,secRem,secAdd}
			end
		else
			-- Item does not exist in `a`, which means it was added.
			if item.Class then
				-- If the item is a member, check to see if it was added
				-- because its class was added.
				local list = addClass[item.Class]
				if list then
					-- If so, then add it do that class's member list, which
					-- will be included with the class's diff struct.
					list[#list+1] = item
				else
					-- If not, then the member is an addition to an existing
					-- class.
					diffs[#diffs+1] = {1,'Item',item}
				end
			elseif item.type == 'EnumItem' then
				-- Same thing as members, but for enumitems.
				local list = addEnum[item.Enum]
				if list then
					list[#list+1] = item
				else
					diffs[#diffs+1] = {1,'Item',item}
				end
			elseif item.type ~= 'Class' and item.type ~= 'Enum' then
				-- Classes and Enum were already added to the diff list.
				diffs[#diffs+1] = {1,'Item',item}
			end
		end
	end
	-- detect removals
	for name,item in pairs(aref) do
		if not bref[name] then
			if item.Class then
				local list = delClass[item.Class]
				if list then
					list[#list+1] = item
				else
					diffs[#diffs+1] = {-1,'Item',item}
				end
			elseif item.type == 'EnumItem' then
				local list = delEnum[item.Enum]
				if list then
					list[#list+1] = item
				else
					diffs[#diffs+1] = {-1,'Item',item}
				end
			elseif item.type ~= 'Class' and item.type ~= 'Enum' then
				diffs[#diffs+1] = {-1,'Item',item}
			end
		end
	end

	local typeSort = {
		Class = 1;
		Property = 2;
		Function = 3;
		YieldFunction = 4;
		Event = 5;
		Callback = 6;
		Enum = 7;
		EnumItem = 8;
	}

	-- Diffs will probably be sorted in some way by the user, but it's nice to
	-- have a consistent order to begin with. Because these are generated from
	-- hash tables, they may not be the same every time. Sorts by diff type,
	-- then item type, then item name.
	table.sort(diffs,function(a,b)
		if a[1] == b[1] then
			if a[3].type == b[3].type then
				return itemName(a[3]) < itemName(b[3])
			else
				return typeSort[a[3].type] < typeSort[b[3].type]
			end
		else
			return a[1] > b[1]
		end
	end)

	-- Also sort the member and enumitem lists.
	local function sort(a,b)
		if a.type == b.type then
			return a.Name < b.Name
		else
			return typeSort[a.type] < typeSort[b.type]
		end
	end
	for _,list in pairs(addClass) do
		table.sort(list,sort)
	end
	for _,list in pairs(delClass) do
		table.sort(list,sort)
	end

	local function sort(a,b)
		return a.Value < b.Value
	end
	for _,list in pairs(addEnum) do
		table.sort(list,sort)
	end
	for _,list in pairs(delEnum) do
		table.sort(list,sort)
	end

	return diffs
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- PARSE
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

oldlex = lex( PRODUCTION_API_DUMP )
newlex = lex(  GAMETEST_API_DUMP  )

compare = diff(oldlex,newlex)
FINAL_RESULT = ""

function print(s)
	if #FINAL_RESULT > 0 then
		FINAL_RESULT = FINAL_RESULT .. "\n"
	end
	FINAL_RESULT = FINAL_RESULT .. tostring(s)
end

local function handleItem(apiItem,diffTag)
	local diffTag = (diffTag and diffTag.." " or "")
	if apiItem.type == "Class" or apiItem.type == "Enum" then
		return diffTag..apiItem.type.." "..apiItem.Name
	elseif apiItem.type == "EnumItem" then
		return diffTag.."EnumItem "..apiItem.Enum.."."..apiItem.Name
	else
		return diffTag..apiItem.type.." "..apiItem.Class.."."..apiItem.Name
	end	
end

for _,change in pairs(compare) do
	local count = 0
	for _,v in pairs(change) do
		count = count + 1
	end
	local diffType,subType,api_item = unpack(change)
	if diffType ~= 0 then
		local diffTag = diffType == 1 and "Added" or "Removed"
		local itemStr = handleItem(api_item,diffTag)
		if subType == "Item" then
			print(itemStr)
		elseif subType == "Class" or subType == "Enum" then
			for i = 4,count do
				print(itemStr)
				local items = change[i]
				for _,item in pairs(items) do
					print("\t"..handleItem(item,diffTag))
				end
			end
		elseif subType == "Tag" then
			local tag = change[4]
			print(diffTag.." '"..tag.."' tag "..(diffType == 1 and "to " or "from ")..handleItem(api_item))
		end
	else
		if subType == "Arguments" then
			local before = ""
			local after = ""
			for _,v in pairs(api_item.Arguments) do
				before = before .. (before == "" and "" or ", ") .. v.Type .. " " .. v.Name.. (v.Default and " = "..v.Default or "")
			end
			for _,v in pairs(change[4]) do
				after = after .. (after == "" and "" or ",") .. v.Type .. " " .. v.Name.. (v.Default and " = "..v.Default or "")
			end
			print(handleItem(api_item,"Changed the arguments of").."\n\t from  ( "..before.." )\n\t to  ( "..after.." )")
		else
			local str1,str2 = change[4],change[5]
			local endTag do
				if str1 == nil and str2 then
					str1 = "None"
				end
				if subType == "Security" and (str1 and str2 == nil) then
					str2 = "None"
				end
				if str1 and str2 then
					endTag = " from "..str1.." to "..str2
				else
					endTag = " to "..str1
				end
			end
			print(handleItem(api_item,"Changed the "..subType.." of")..endTag)
		end
	end
end
