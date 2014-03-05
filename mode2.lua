local curFile = "mode2.lua"

-- AI-states
-- 0 Default, wenn nicht in Mode2 aktiv
-- 1 warte am startpunkt auf arbeit
-- 2 fahre hinter drescher
-- 3 fahre zur pipe / abtanken
-- 4 fahre ans heck des dreschers
-- 5 wegpunkte abfahren
-- 7 warte auf die Pipe 
-- 6 fahre hinter traktor
-- 8 alle trailer voll
-- 81 alle trailer voll, schlepper wendet von maschine weg
-- 99 wenden
-- 10 seite wechseln

function courseplay:handle_mode2(self, dt)
	local frontTractor;
	--[[
	if self.cp.tipperFillLevelPct >= self.cp.followAtFillLevel then --TODO: shouldn't this be the "tractor that following me"'s followAtFillLevel ?
		self.cp.allowFollowing = true
	else
		self.cp.allowFollowing = false
	end
	]]

	if self.cp.modeState == 0 then
		self.cp.modeState = 1
		-- print(('%s [%s(%d)]: modeState=0 -> set modeState to 1'):format(nameNum(self), curFile, debug.getinfo(1).currentline)); -- DEBUG140301
	end


	if self.cp.modeState == 1 and self.cp.activeCombine ~= nil then
		courseplay:unregister_at_combine(self, self.cp.activeCombine)
	end

	-- trailer full
	if self.cp.modeState == 8 then
		-- print(('%s [%s(%d)]: modeState=8 -> set recordnumber to 2, modeState to 0, isLoaded to true'):format(nameNum(self), curFile, debug.getinfo(1).currentline)); -- DEBUG140301
		self.recordnumber = 2
		courseplay:unregister_at_combine(self, self.cp.activeCombine)
		self.cp.modeState = 0
		self.cp.isLoaded = true
		return false
	end

	-- support multiple tippers
	if self.cp.currentTrailerToFill == nil then
		self.cp.currentTrailerToFill = 1
	end

	local current_tipper = self.tippers[self.cp.currentTrailerToFill]

	if current_tipper == nil then
		self.cp.toolsDirty = true
		return false
	end


	-- switch side
	if self.cp.activeCombine ~= nil and (self.cp.modeState == 10 or self.cp.activeCombine.turnAP ~= nil and self.cp.activeCombine.turnAP == true) then
		if self.cp.combineOffset > 0 then
			self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.activeCombine.rootNode, 25, 0, 0)
		else
			self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.cp.activeCombine.rootNode, -25, 0, 0)
		end
		self.cp.modeState = 5
		self.cp.mode2nextState = 2
	end

	if (current_tipper.fillLevel == current_tipper.capacity) or self.cp.isLoaded or (self.cp.tipperFillLevelPct >= self.cp.driveOnAtFillLevel and self.cp.modeState == 1) then
		if #(self.tippers) > self.cp.currentTrailerToFill then
			self.cp.currentTrailerToFill = self.cp.currentTrailerToFill + 1
		else
			self.cp.currentTrailerToFill = nil
			--courseplay:unregister_at_combine(self, self.cp.activeCombine)  
			if self.cp.modeState ~= 5 then
				cx2, cz2 = self.Waypoints[1].cx, self.Waypoints[1].cz
				local lx2, lz2 = AIVehicleUtil.getDriveDirection(self.rootNode, cx2, cty2, cz2);
				if lz2 > 0 or (self.cp.activeCombine ~= nil and self.cp.activeCombine.cp.isChopper) then
					if self.cp.combineOffset > 0 then
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, self.cp.turnRadius, 0, self.cp.turnRadius)
					else
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, -self.cp.turnRadius, 0, self.cp.turnRadius)
					end
				elseif self.cp.activeCombine ~= nil and not self.cp.activeCombine.cp.isChopper then
					if self.cp.combineOffset > 0 then
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, 3, 0, -self.cp.turnRadius)
					else
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, -3, 0, -self.cp.turnRadius)
					end
				end
				self.cp.modeState = 5
				self.cp.mode2nextState = 81
			end
		end
	end


	if self.cp.activeCombine ~= nil then
		if self.cp.positionWithCombine == 1 then
			-- is there a trailer to fill, or at least a waypoint to go to?
			if self.cp.currentTrailerToFill or self.cp.modeState == 5 then
				if self.cp.modeState == 6 then
					-- drive behind combine: self.cp.modeState = 2
					-- drive next to combine:
					self.cp.modeState = 3
				end
				courseplay:unload_combine(self, dt)
			end
		else
			-- follow tractor in front of me
			frontTractor = self.cp.activeCombine.courseplayers[self.cp.positionWithCombine - 1]
			-- print(string.format('%s: activeCombine ~= nil, my position=%d, frontTractor (positionWithCombine %d) = %q', nameNum(self), self.cp.positionWithCombine, self.cp.positionWithCombine - 1, nameNum(frontTractor)));
			--	courseplay:follow_tractor(self, dt, tractor)
			self.cp.modeState = 6
			courseplay:unload_combine(self, dt)
		end
	else -- NO active combine
		-- STOP!!
		if self.isRealistic then
			courseplay:driveInMRDirection(self, 0, 1, true, dt, false);
		else
			AIVehicleUtil.driveInDirection(self, dt, self.cp.steeringAngle, 0, 0, 28, false, moveForwards, 0, 1)
		end;

		if self.cp.isLoaded then
			-- print(('%s [%s(%d)]: activeCombine=nil, isLoaded=true -> set recordnumber to 2, modeState to 99, return false'):format(nameNum(self), curFile, debug.getinfo(1).currentline)); -- DEBUG140301
			self.recordnumber = 2
			self.cp.modeState = 99
			return false
		end

		-- are there any combines out there that need my help?
		if self.cp.timeOut < self.timer then
			if self.cp.lastActiveCombine ~= nil then
				local distance = courseplay:distance_to_object(self, self.cp.lastActiveCombine)
				if distance > 20 then
					self.cp.lastActiveCombine = nil
				else
					courseplay:debug(string.format("%s (%s): last combine is just %.0f away, so wait", nameNum(self), tostring(self.id), distance), 4);
				end
			else 
				courseplay:update_combines(self)
			end
			courseplay:set_timeout(self, 5000)
		end

		--is any of the reachable combines full?
		if self.cp.reachableCombines ~= nil then
			if table.getn(self.cp.reachableCombines) > 0 then
				-- choose the combine that needs me the most
				if self.best_combine ~= nil and self.cp.activeCombine == nil then
					courseplay:debug(string.format("%s (%s): request check-in @ %s", nameNum(self), tostring(self.id), tostring(self.combineID)), 4);
					if courseplay:register_at_combine(self, self.best_combine) then
						self.cp.modeState = 2
					end
				else
					self.cp.infoText = courseplay:loc("CPwaitFillLevel");
				end


				local highest_fill_level = 0;
				local num_courseplayers = 0;
				local distance = 0;

				self.best_combine = nil;
				self.combineID = 0;
				self.distanceToCombine = 99999999999;

				-- chose the combine who needs me the most
				for k, combine in pairs(self.cp.reachableCombines) do
					if (combine.grainTankFillLevel >= (combine.grainTankCapacity * self.cp.followAtFillLevel / 100)) or combine.grainTankCapacity == 0 or combine.wants_courseplayer then
						if combine.grainTankCapacity == 0 then
							if combine.courseplayers == nil then
								self.best_combine = combine
							else
								local numCombineCourseplayers = #combine.courseplayers;
								if numCombineCourseplayers <= num_courseplayers or self.best_combine == nil then
									num_courseplayers = numCombineCourseplayers;
									if numCombineCourseplayers > 0 then
										frontTractor = combine.courseplayers[num_courseplayers];
										local canFollowFrontTractor = frontTractor.cp.tipperFillLevelPct and frontTractor.cp.tipperFillLevelPct >= self.cp.followAtFillLevel;
										-- print(string.format('frontTractor (pos %d)=%q, canFollowFrontTractor=%s', numCombineCourseplayers, nameNum(frontTractor), tostring(canFollowFrontTractor)));
										if canFollowFrontTractor then
											self.best_combine = combine
										end
									else
										self.best_combine = combine
									end
								end;
							end 

						elseif combine.grainTankFillLevel >= highest_fill_level and combine.isCheckedIn == nil then
							highest_fill_level = combine.grainTankFillLevel
							self.best_combine = combine
							local cx, cy, cz = getWorldTranslation(combine.rootNode)
							local sx, sy, sz = getWorldTranslation(self.rootNode)
							distance = courseplay:distance(sx, sz, cx, cz)
							self.distanceToCombine = distance
							self.callCombineFillLevel = self.cp.tipperFillLevelPct
							self.combineID = combine.id
						end
					end
				end

				if self.combineID ~= 0 then
					courseplay:debug(string.format("%s (%s): call combine: %s", nameNum(self), tostring(self.id), tostring(self.combineID)), 4);
				end

			else
				self.cp.infoText = courseplay:loc("CPnoCombineInReach")
			end
		end
	end
end

function courseplay:unload_combine(self, dt)
	local curFile = "mode2.lua"
	local allowedToDrive = true
	local combine = self.cp.activeCombine
	local x, y, z = getWorldTranslation(self.cp.DirectionNode)
	local currentX, currentY, currentZ = nil, nil, nil

	--local sl = nil --kann die weg??
	local combine_fill_level, combine_turning = nil, false
	local refSpeed = nil
	local handleTurn = false
	local isHarvester = false
	local xt, yt, zt = nil, nil, nil
	local dod = nil

	-- Calculate Trailer Offset

	if self.cp.currentTrailerToFill ~= nil then
		xt, yt, zt = worldToLocal(self.tippers[self.cp.currentTrailerToFill].fillRootNode, x, y, z)
	else
		--courseplay:debug(nameNum(self) .. ": no cp.currentTrailerToFillSet", 4);
		xt, yt, zt = worldToLocal(self.tippers[1].rootNode, x, y, z)
	end

	-- support for tippers like hw80
	if zt < 0 then
		zt = zt * -1
	end

	local trailer_offset = zt + self.cp.tipperOffset


	if self.cp.speeds.sl == nil then
		self.cp.speeds.sl = 3
	end

	if self.isChopperTurning == nil then
		self.isChopperTurning = false
	end

	if combine.grainTankCapacity > 0 then
		combine_fill_level = combine.grainTankFillLevel * 100 / combine.grainTankCapacity
	else -- combine is a chopper / has no tank
		combine_fill_level = 51;
	end
	local tractor = combine
	if courseplay:isAttachedCombine(combine) then
		tractor = combine.attacherVehicle
	end

	local combineIsHelperTurning = false
	if tractor.turnStage ~= nil and tractor.turnStage ~= 0 then
		combineIsHelperTurning = true
	end

	-- auto combine
	if self.cp.turnCounter == nil then
			self.cp.turnCounter = 0
	end
	
	local AutoCombineIsTurning = false
	local combineIsAutoCombine = false
	local autoCombineExtraMoveBack = 0
	if combine.acParameters ~= nil and combine.acParameters.enabled and combine.isAIThreshing then
		combineIsAutoCombine = true
		if combine.cp.turnStage == nil then
			combine.cp.turnStage = 0
		end
		if combine.acTurnStage ~= 0 then 
			combine.cp.turnStage = 2
			autoCombineExtraMoveBack = self.cp.turnRadius*1.5
			AutoCombineIsTurning = true
		else
			combine.cp.turnStage = 0
		end
	end
	
	-- is combine turning ?
	
	local aiTurn = combine.isAIThreshing and (combine.turnStage == 1 or combine.turnStage == 2 or combine.turnStage == 4 or combine.turnStage == 5)
	if tractor ~= nil and (aiTurn or (tractor.cp.turnStage > 0)) then
		self.cp.infoText = courseplay:loc("CPCombineTurning") -- "Drescher wendet. "
		combine_turning = true
	end
	if self.cp.modeState == 2 or self.cp.modeState == 3 or self.cp.modeState == 4 then
		if combine == nil then
			self.cp.infoText = "this should never happen";
			allowedToDrive = false
		end
	end



	local offset_to_chopper = self.cp.combineOffset
	if combineIsHelperTurning or tractor.cp.turnStage ~= 0 then
		offset_to_chopper = self.cp.combineOffset * 1.6 --1,3
	end


	local x1, y1, z1 = worldToLocal(combine.rootNode, x, y, z)
	local distance = Utils.vector2Length(x1, z1)

	local safetyDistance = 11;
	if courseplay:isAttachedCombine(combine) then
		safetyDistance = 11;
	elseif combine.cp.isHarvesterSteerable or combine.cp.isSugarBeetLoader then
		safetyDistance = 24;
	elseif combine.cp.isCombine then
		safetyDistance = 10;
	elseif combine.cp.isChopper then
		safetyDistance = 11;
	end;

	if self.cp.modeState == 2 then -- Drive to Combine or Cornchopper
		self.cp.speeds.sl = 2
		refSpeed = self.cp.speeds.field
		--courseplay:remove_from_combines_ignore_list(self, combine)
		self.cp.infoText = courseplay:loc("CPDriveBehinCombine");

		local x1, y1, z1 = worldToLocal(tractor.rootNode, x, y, z)

		if z1 > -(self.cp.turnRadius + safetyDistance) then -- tractor in front of combine     
			-- left side of combine
			local cx_left, cy_left, cz_left = localToWorld(tractor.rootNode, 20, 0, -30) 
			-- righ side of combine
			local cx_right, cy_right, cz_right = localToWorld(tractor.rootNode, -20, 0, -30) 
			local lx, ly, lz = worldToLocal(self.cp.DirectionNode, cx_left, y, cz_left)
			-- distance to left position
			local disL = Utils.vector2Length(lx, lz)
			local rx, ry, rz = worldToLocal(self.cp.DirectionNode, cx_right, y, cz_right)
			-- distance to right position
			local disR = Utils.vector2Length(rx, rz)

			if disL < disR then
				currentX, currentY, currentZ = cx_left, cy_left, cz_left
			else
				currentX, currentY, currentZ = cx_right, cy_right, cz_right
			end

		else
			-- tractor behind combine
			if not combine.cp.isChopper then
				currentX, currentY, currentZ = localToWorld(tractor.rootNode, self.cp.combineOffset, 0, -(self.cp.turnRadius + safetyDistance)) --!!!
			else
				currentX, currentY, currentZ = localToWorld(tractor.rootNode, 0, 0, -(self.cp.turnRadius + safetyDistance))
			end
		end

		--[[
		--PATHFINDING
		if self.cp.realisticDriving and not self.cp.calculatedCourseToCombine then
			if courseplay:calculate_course_to(self, currentX, currentZ) then
				self.cp.modeState = 5;
				self.cp.shortestDistToWp = nil;
				self.cp.mode2nextState = 2; -- modeState when waypoint is reached
			end;
		end;
		--]]



		local lx, ly, lz = worldToLocal(self.cp.DirectionNode, currentX, currentY, currentZ)
		dod = Utils.vector2Length(lx, lz)
		-- near point
		if dod < 3 then -- change to self.cp.modeState 4 == drive behind combine or cornChopper
			if combine.cp.isChopper and (not self.isChopperTurning or combineIsAutoCombine) then -- decide on which side to drive based on ai-combine
				courseplay:sideToDrive(self, combine, 10);
				if self.sideToDrive == "right" then
						self.cp.combineOffset = math.abs(self.cp.combineOffset) * -1;
				else 
					self.cp.combineOffset = math.abs(self.cp.combineOffset);
				end
			end
			self.cp.modeState = 4
		end

		-- end self.cp.modeState 2
	elseif self.cp.modeState == 4 then -- Drive to rear Combine or Cornchopper
		if combine.cp.offset == nil or self.cp.combineOffset == 0 then
			--print("offset not saved - calculate")
			courseplay:calculateCombineOffset(self, combine);
		elseif not combine.cp.isChopper and not combine.cp.isSugarBeetLoader and self.cp.combineOffsetAutoMode and self.cp.combineOffset ~= combine.cp.offset then
			--print("set saved offset")
			self.cp.combineOffset = combine.cp.offset			
		end
		self.cp.infoText = courseplay:loc("CPDriveToCombine") -- "Fahre zum Drescher"
		--courseplay:add_to_combines_ignore_list(self, combine)
		refSpeed = self.cp.speeds.field

		local tX, tY, tZ = nil, nil, nil

		if combine.cp.isSugarBeetLoader then
			local prnToCombineZ = courseplay:calculateVerticalOffset(self, combine);
	
			tX, tY, tZ = localToWorld(combine.rootNode, self.cp.combineOffset, 0, prnToCombineZ -5);
		else			
			tX, tY, tZ = localToWorld(combine.rootNode, self.cp.combineOffset, 0, -5);
		end

		if combine.attachedImplements ~= nil then
			for k, i in pairs(combine.attachedImplements) do
				local implement = i.object;
				if implement.haeckseldolly == true then
					tX, tY, tZ = localToWorld(implement.rootNode, self.cp.combineOffset, 0, trailer_offset)
				end
			end
		end

		currentX, currentZ = tX, tZ

		local lx, ly, lz = nil, nil, nil

		lx, ly, lz = worldToLocal(self.cp.DirectionNode, tX, y, tZ)

		if currentX ~= nil and currentZ ~= nil then
			local lx, ly, lz = worldToLocal(self.cp.DirectionNode, currentX, y, currentZ)
			dod = Utils.vector2Length(lx, lz)
		else
			dod = Utils.vector2Length(lx, lz)
		end


		if dod < 2 then -- dod < 2
			allowedToDrive = false
			self.cp.modeState = 3 -- change to self.cp.modeState 3 == drive to unload pipe
			self.isChopperTurning = false
		end

		if dod > 50 then
			self.cp.modeState = 2
		end

	elseif self.cp.modeState == 3 then --drive to unload pipe

		self.cp.infoText = courseplay:loc("CPDriveNextCombine") -- "Fahre neben Drescher"
		--courseplay:add_to_combines_ignore_list(self, combine)
		refSpeed = self.cp.speeds.field

		if self.cp.nextTargets ~= nil then
			self.cp.nextTargets = {}
		end

		if combine_fill_level == 0 then --combine empty set waypoints on the field !!!
			if combine.cp.offset == nil then
				--print("saving offset")
				combine.cp.offset = self.cp.combineOffset;
			end			
			local fruitSide = courseplay:sideToDrive(self, combine, -10)
			if fruitSide == "none" then
				fruitSide = courseplay:sideToDrive(self, combine, -50)
			end
			local offset = math.abs(self.cp.combineOffset)
			local DirTx,_,DirTz = worldToLocal(self.rootNode,self.Waypoints[self.maxnumber].cx,0, self.Waypoints[self.maxnumber].cz)
			if self.cp.combineOffset > 0 then  --I'm left
				if fruitSide == "right" or fruitSide == "none" then 
					courseplay:debug(nameNum(self) .. ": I'm left, fruit is right", 4)
					local fx,fy,fz = localToWorld(self.rootNode, 0, 0, 8)
					local sx,sy,sz = localToWorld(self.rootNode, 0 , 0, -self.cp.turnRadius-trailer_offset-autoCombineExtraMoveBack)
					if courseplay:is_field(fx, fz) and not combineIsAutoCombine then
						courseplay:debug(nameNum(self) .. ": 1st target is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, 0 , 0, 5);	
						self.cp.modeState = 5
					elseif courseplay:is_field(sx, sz) then
						courseplay:debug(nameNum(self) .. ": 2nd target is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, 2 , 0, -self.cp.turnRadius);
						courseplay:addNewTarget(self, 0 ,  -self.cp.turnRadius-trailer_offset-autoCombineExtraMoveBack);
						self.cp.modeState = 5
					else
						courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.rootNode, 2 , 0, -self.cp.turnRadius-trailer_offset)
						courseplay:addNewTarget(self, DirTx, DirTz);
						self.cp.modeState = 5
					end					
				else
					courseplay:debug(nameNum(self) .. ": I'm left, fruit is left", 4)
					local fx,fy,fz = localToWorld(self.rootNode, 3*offset*-1, 0, -self.cp.turnRadius-trailer_offset)
					local tx,ty,tz = localToWorld(self.rootNode, 3*offset*-1, 0, -(2*self.cp.turnRadius)-trailer_offset)
					if courseplay:is_field(fx, fz) then
						courseplay:debug(nameNum(self) .. ": deepest waypoint is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, 2, 0, -self.cp.turnRadius-trailer_offset);
						courseplay:addNewTarget(self, 3*offset*-1 ,  -self.cp.turnRadius-trailer_offset);
						fx,fy,fz = localToWorld(self.rootNode, 3*offset*-1, 0, 0)
						sx,sy,sz = localToWorld(self.rootNode, 3*offset*-1, 0, -(2*self.cp.turnRadius)-trailer_offset)
						if courseplay:is_field(fx, fz) then
							courseplay:debug(nameNum(self) .. ": 1st target is on field", 4)
							courseplay:addNewTarget(self, 3*offset*-1,0);
						elseif courseplay:is_field(sx, sz) then
							courseplay:debug(nameNum(self) .. ": 2nd target is on field",4)
							courseplay:addNewTarget(self, 3*offset*-1 ,  -(2*self.cp.turnRadius)-trailer_offset);
						else
							courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
							self.cp.curTarget.x, self.cp.curTarget.z  = self.Waypoints[self.maxnumber].cx, self.Waypoints[self.maxnumber].cz
						end
						self.cp.modeState = 5
					elseif courseplay:is_field(tx, tz) then		
						courseplay:debug(nameNum(self) .. ": deepest waypoint is not on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, self.cp.turnRadius, 0, 0);
						courseplay:addNewTarget(self, 0 ,  -(2*trailer_offset));
						courseplay:addNewTarget(self, 3*offset*-1 ,  -(2*trailer_offset));
						courseplay:addNewTarget(self, 3*offset*-1 , self.cp.turnRadius);
						self.cp.modeState = 5
					else
						courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.rootNode, 2 , 0, -self.cp.turnRadius-trailer_offset)
						courseplay:addNewTarget(self, DirTx, DirTz);
						self.cp.modeState = 5
					end
				end
			else
				if fruitSide == "right" or fruitSide == "none" then 
					courseplay:debug(nameNum(self) .. ": I'm right, fruit is right", 4)
					local fx,fy,fz = localToWorld(self.rootNode, 3*offset, 0, -self.cp.turnRadius-trailer_offset)
					local sx,sy,sz = localToWorld(self.rootNode, 3*offset,0,  -(2*trailer_offset))
					if courseplay:is_field(fx, fz) then
						courseplay:debug(nameNum(self) .. ": deepest waypoint is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, -4, 0, -self.cp.turnRadius-trailer_offset);
						courseplay:addNewTarget(self, 3*offset ,  -self.cp.turnRadius-trailer_offset);
						fx,fy,fz = localToWorld(self.rootNode, 3*offset, 0, 0)
						sx,sy,sz = localToWorld(self.rootNode, 3*offset, 0, -(2*self.cp.turnRadius)-trailer_offset)
						if courseplay:is_field(fx, fz) then
							courseplay:debug(nameNum(self) .. ": 1st target is on field", 4)
							courseplay:addNewTarget(self, 3*offset,0);

						elseif courseplay:is_field(sx, sz) then
							courseplay:debug(nameNum(self) .. ": 2nd target is on field", 4)
							courseplay:addNewTarget(self, 3*offset,  -(2*self.cp.turnRadius)-trailer_offset);
						else
							courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
							self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.rootNode, -2 , 0, -self.cp.turnRadius-trailer_offset)
							courseplay:addNewTarget(self, DirTx, DirTz);
						end
						self.cp.modeState = 5

					elseif courseplay:is_field(sx, sz) then	
						courseplay:debug(nameNum(self) .. ": deepest waypoint is not on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, -self.cp.turnRadius, 0, 0);
						courseplay:addNewTarget(self, 0 ,  -(2*trailer_offset));
						courseplay:addNewTarget(self, 3*offset,  -(2*trailer_offset));
						courseplay:addNewTarget(self, 3*offset, self.cp.turnRadius);
						self.cp.modeState = 5
					else
						courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.rootNode, -2 , 0, -self.cp.turnRadius-trailer_offset)
						courseplay:addNewTarget(self, DirTx, DirTz);
						self.cp.modeState = 5
					end
				else
					courseplay:debug(nameNum(self) .. ": I'm right, fruit is left", 4)
					local fx,fy,fz = localToWorld(self.rootNode, 0, 0, 3)
					local sx,sy,sz = localToWorld(self.rootNode, 0,0, -self.cp.turnRadius-trailer_offset)
					if courseplay:is_field(fx, fz) then
						courseplay:debug(nameNum(self) .. ": 1st target is on field", 4)
						self.cp.modeState = 1

					elseif courseplay:is_field(sx, sz) then
						courseplay:debug(nameNum(self) .. ": 2nd target is on field", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, -2 , 0, -self.cp.turnRadius);
						courseplay:addNewTarget(self, 0, -self.cp.turnRadius-trailer_offset);
						self.cp.modeState = 5
					else
						courseplay:debug(nameNum(self) .. ": backup- back to start", 4)
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z  = localToWorld(self.rootNode, -2 , 0, -self.cp.turnRadius-trailer_offset)
						courseplay:addNewTarget(self, DirTx, DirTz);
						self.cp.modeState = 5
					end

				end

			end


			if self.cp.tipperFillLevelPct >= self.cp.driveOnAtFillLevel then
				self.cp.isLoaded = true
			else
				self.cp.mode2nextState = 1
			end
		end

		--CALCULATE HORIZONTAL OFFSET (side offset)
		if combine.cp.offset == nil and not combine.cp.isChopper then
			courseplay:calculateCombineOffset(self, combine);
		end
		currentX, currentY, currentZ = localToWorld(combine.rootNode, self.cp.combineOffset, 0, trailer_offset + 5)
		
		--CALCULATE VERTICAL OFFSET (tipper offset)
		local prnToCombineZ = courseplay:calculateVerticalOffset(self, combine);
		
		--SET TARGET UNLOADING COORDINATES @ COMBINE
		local ttX, ttZ = courseplay:setTargetUnloadingCoords(self, combine, trailer_offset, prnToCombineZ);
		
		local lx, ly, lz = worldToLocal(self.cp.DirectionNode, ttX, y, ttZ)
		dod = Utils.vector2Length(lx, lz)
		if dod > 40 or self.isChopperTurning == true then
			self.cp.modeState = 2
		end
		-- combine is not moving and trailer is under pipe
		if not combine.cp.isChopper and tractor.movingDirection == 0 and (lz <= 1 or lz < -0.1 * trailer_offset) then
			self.cp.infoText = courseplay:loc("CPCombineWantsMeToStop") -- "Drescher sagt ich soll anhalten."
			allowedToDrive = false
		elseif combine.cp.isChopper then
			if combine.movingDirection == 0 and dod == -1 and self.isChopperTurning == false then
				allowedToDrive = false
				self.cp.infoText = courseplay:loc("CPCombineWantsMeToStop") -- "Drescher sagt ich soll anhalten."
			end
			if lz < -2 then
				allowedToDrive = false
				self.cp.infoText = courseplay:loc("CPCombineWantsMeToStop")
				--self.cp.modeState = 2
			end
		elseif lz < -1.5 then
				allowedToDrive = false
				self.cp.infoText = courseplay:loc("CPCombineWantsMeToStop")
		end

		-- refspeed depends on the distance to the combine
		local combine_speed = tractor.lastSpeed
		if combine.cp.isChopper then
			self.cp.speeds.sl = 2
			if lz > 20 then
				refSpeed = self.cp.speeds.field
			elseif lz > 4 and (combine_speed*3600) > 5 then
				refSpeed = combine_speed *1.5
			elseif lz > 10 then
				refSpeed = self.cp.speeds.turn
			elseif lz < -1 then
				refSpeed = combine_speed / 2
			else
				refSpeed = math.max(combine_speed,3/3600)
			end
			
			if ((combineIsHelperTurning or tractor.cp.turnStage ~= 0) and lz < 20) or (combine.movingDirection == 0 and lz < 5) then
				refSpeed = 4 / 3600
				self.cp.speeds.sl = 1
				if self.ESLimiter == nil then
					self.motor.maxRpm[self.cp.speeds.sl] = 200
				end 
			end
		else
			self.cp.speeds.sl = 2
			if lz > 5 then
				refSpeed = self.cp.speeds.field
			elseif lz < -0.5 then
				refSpeed = combine_speed - (3/3600)
			elseif lz > 1 or combine.sentPipeIsUnloading ~= true  then  
				refSpeed = combine_speed + (3/3600) 
			else
				refSpeed = combine_speed
			end
			if ((combineIsHelperTurning or tractor.cp.turnStage ~= 0) and lz < 20) or (self.timer < self.cp.driveSlowTimer) or (combine.movingDirection == 0 and lz < 15) then
				refSpeed = 4 / 3600
				self.cp.speeds.sl = 1
				if self.ESLimiter == nil then
					self.motor.maxRpm[self.cp.speeds.sl] = 200
				end 
				if combineIsHelperTurning or tractor.cp.turnStage ~= 0 then
					self.cp.driveSlowTimer = self.timer + 2000
				end
			end
		
		end

		--courseplay:debug("combine.sentPipeIsUnloading: "..tostring(combine.sentPipeIsUnloading).." refSpeed:  "..tostring(refSpeed*3600).." combine_speed:  "..tostring(combine_speed*3600), 4)

		---------------------------------------------------------------------
	end -- end self.cp.modeState 3 or 4
	local cx, cy, cz = getWorldTranslation(combine.rootNode)
	local sx, sy, sz = getWorldTranslation(self.rootNode)
	distance = courseplay:distance(sx, sz, cx, cz)
	if combine_turning and not combine.cp.isChopper then
		if combine.grainTankFillLevel > combine.grainTankCapacity*0.9 then
			if combineIsAutoCombine and combine.acIsCPStopped ~= nil then
				combine.acIsCPStopped = true
			elseif combine.isAIThreshing then 
				combine.waitForTurnTime = combine.time + 100
			elseif tractor.drive == true then
				combine.cp.waitingForTrailerToUnload = true
			end			
		elseif distance < 50 then
			if AutoCombineIsTurning and combine.acIsCPStopped ~= nil then
				combine.acIsCPStopped = true
			elseif combine.isAIThreshing and not (combine_fill_level == 0 and combine.currentPipeState ~= 2) then
				combine.waitForTurnTime = combine.time + 100
			elseif tractor.drive == true and not (combine_fill_level == 0 and combine:getCombineTrailerInRangePipeState()==0) then
				combine.cp.waitingForTrailerToUnload = true
			end
		elseif distance < 100 and self.cp.modeState == 2 then
			allowedToDrive = courseplay:brakeToStop(self)
		end 
	end
	if combine_turning and distance < 20 then
		if self.cp.modeState == 3 or self.cp.modeState == 4 then
			if combine.cp.isChopper then
				local fruitSide = courseplay:sideToDrive(self, combine, -10,true);
				
				--new chopper turn maneuver by Thomas G�rtner  
				if fruitSide == "left" then -- chopper will turn left

					if self.cp.combineOffset > 0 then -- I'm left of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm left", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name)), 4);
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, 0, 0, self.cp.turnRadius);
						courseplay:addNewTarget(self, 2*self.cp.turnRadius*-1 ,  self.cp.turnRadius);
						self.isChopperTurning = true
	
					else --i'm right of choppper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns left, I'm right", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name)), 4);
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, self.cp.turnRadius*-1, 0, self.cp.turnRadius);
						self.isChopperTurning = true
					end
					
				else -- chopper will turn right
					if self.cp.combineOffset < 0 then -- I'm right of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm right", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name)), 4);
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, 0, 0, self.cp.turnRadius);
						courseplay:addNewTarget(self, 2*self.cp.turnRadius,     self.cp.turnRadius);
						self.isChopperTurning = true
					else -- I'm left of chopper
						courseplay:debug(string.format("%s(%i): %s @ %s: combine turns right, I'm left", curFile, debug.getinfo(1).currentline, nameNum(self), tostring(combine.name)), 4);
						self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(self.rootNode, self.cp.turnRadius, 0, self.cp.turnRadius);
						self.isChopperTurning = true
					end
				end

				if self.cp.combineOffsetAutoMode then
					if self.sideToDrive == "right" then
						self.cp.combineOffset = combine.cp.offset * -1;
					elseif self.sideToDrive == "left" then
						self.cp.combineOffset = combine.cp.offset;
					end;
				else
					if self.sideToDrive == "right" then
						self.cp.combineOffset = math.abs(self.cp.combineOffset) * -1;
					elseif self.sideToDrive == "left" then
						self.cp.combineOffset = math.abs(self.cp.combineOffset);
					end;
				end;
				self.cp.modeState = 5
				self.cp.shortestDistToWp = nil
				self.cp.mode2nextState = 7
			end
		-- elseif self.cp.modeState ~= 5 and self.cp.modeState ~= 99 and not self.cp.realisticDriving then
		elseif self.cp.modeState ~= 5 and self.cp.modeState ~= 9 and not self.cp.realisticDriving then
			-- just wait until combine has turned
			allowedToDrive = false
			self.cp.infoText = courseplay:loc("CPCombineWantsMeToStop")
		end
	end


	if self.cp.modeState == 7 then
		if combine.movingDirection == 0 then
			self.cp.modeState = 3
		else
			self.cp.infoText = courseplay:loc("CPWaitUntilCombineTurned");
		end
	end


	--[[ TODO: MODESTATE 99 - WTF?
	-- Turn maneuver
	if self.cp.modeState == 99 and self.cp.curTarget.x ~= nil and self.cp.curTarget.z ~= nil then
		--courseplay:remove_from_combines_ignore_list(self, combine)
		self.cp.infoText = string.format(courseplay:loc("CPTurningTo"), self.cp.curTarget.x, self.cp.curTarget.z)
		allowedToDrive = false
		local mx, mz = self.cp.curTarget.x, self.cp.curTarget.z
		local lx, ly, lz = worldToLocal(self.cp.DirectionNode, mx, y, mz)
		self.cp.speeds.sl = 1
		refSpeed = self.cp.speeds.field --self.cp.speeds.turn

		if lz > 0 and math.abs(lx) < lz * 0.5 then -- lz * 0.5    --2
			if self.cp.mode2nextState == 4 and not combine_turning then
				self.cp.curTarget.x = nil
				self.cp.curTarget.z = nil
				self.cp.modeState = self.cp.mode2nextState
				self.cp.mode2nextState = 0
			end

			if self.cp.mode2nextState == 1 or self.cp.mode2nextState == 2 then
				-- is there another waypoint to go to?
				if #(self.cp.nextTargets) > 0 then
					self.cp.modeState = 5
					self.cp.shortestDistToWp = nil
					courseplay:setCurrentTargetFromList(self, 1);
				else
					self.cp.modeState = self.cp.mode2nextState
					self.cp.mode2nextState = 0
				end
			end
		else
			currentX, currentY, currentZ = localToWorld(self.cp.DirectionNode, self.turn_factor, 0, 5)
			allowedToDrive = true
		end
	end
	--]]



	-- drive to given waypoint
	if self.cp.modeState == 5 and self.cp.curTarget.x ~= nil and self.cp.curTarget.z ~= nil then
		if combine ~= nil then
			--courseplay:remove_from_combines_ignore_list(self, combine)
		end
		self.cp.infoText = string.format(courseplay:loc("CPDriveToWP"), self.cp.curTarget.x, self.cp.curTarget.z)
		currentX = self.cp.curTarget.x
		currentY = self.cp.curTarget.y
		currentZ = self.cp.curTarget.z
		self.cp.speeds.sl = 2
		refSpeed = self.cp.speeds.field

		distance_to_wp = courseplay:distance_to_point(self, currentX, y, currentZ)

		if #(self.cp.nextTargets) == 0 then
			if distance_to_wp < 10 then
				refSpeed = self.cp.speeds.turn -- 3/3600
				self.cp.speeds.sl = 1
			end
		end

		-- avoid circling
		local distToChange = 1
		if self.cp.shortestDistToWp == nil or self.cp.shortestDistToWp > distance_to_wp then
			self.cp.shortestDistToWp = distance_to_wp
		end

		if distance_to_wp > self.cp.shortestDistToWp and distance_to_wp < 3 then
			distToChange = distance_to_wp + 1
		end

		if distance_to_wp < distToChange then
			if self.cp.mode2nextState == 81 then
				if self.cp.activeCombine ~= nil then
					courseplay:unregister_at_combine(self, self.cp.activeCombine)
				end
			end

			self.cp.shortestDistToWp = nil
			if #(self.cp.nextTargets) > 0 then
				--	  	self.cp.modeState = 5
				courseplay:setCurrentTargetFromList(self, 1);
			else
				allowedToDrive = false
				if self.cp.mode2nextState ~= 2 then
					self.cp.calculatedCourseToCombine = false
				end
				if self.cp.mode2nextState == 7 then

					self.cp.modeState = 7

					--self.cp.curTarget.x, self.cp.curTarget.y, self.cp.curTarget.z = localToWorld(combine.rootNode, self.chopper_offset*0.7, 0, -9) -- -2          --??? *0,5 -10

				elseif self.cp.mode2nextState == 4 and combine_turning then
					self.cp.infoText = courseplay:loc("CPWaitUntilCombineTurned");
				elseif self.cp.mode2nextState == 81 then -- tipper turning from combine

					-- print(('%s [%s(%d)]: no nextTargets, mode2nextState=81 -> set recordnumber to 2, modeState to 99, isLoaded to true, return false'):format(nameNum(self), curFile, debug.getinfo(1).currentline)); -- DEBUG140301
					self.recordnumber = 2
					courseplay:unregister_at_combine(self, self.cp.activeCombine)
					self.cp.modeState = 99
					self.cp.isLoaded = true

				elseif self.cp.mode2nextState == 1 then
					--	self.cp.speeds.sl = 1
					--	refSpeed = self.cp.speeds.turn
					self.cp.modeState = self.cp.mode2nextState
					self.cp.mode2nextState = 0

				else
					self.cp.modeState = self.cp.mode2nextState
					self.cp.mode2nextState = 0
				end
			end
		end
	end

	if self.cp.modeState == 6 and frontTractor ~= nil then --Follow Tractor
		self.cp.infoText = courseplay:loc("CPFollowTractor") -- "Fahre hinter Traktor"
		--use the current tractor's sideToDrive as own
		if frontTractor.sideToDrive ~= nil then
			courseplay:debug(string.format("%s: setting current tractor's sideToDrive (%s) as my own", nameNum(self), tostring(frontTractor.sideToDrive)), 4);
			self.sideToDrive = frontTractor.sideToDrive;
		end;

		-- drive behind tractor
		local backDistance = math.max(10,(self.cp.turnRadius + safetyDistance))
		local dx,dz = AIVehicleUtil.getDriveDirection(frontTractor.rootNode, x, y, z);
		local x1, y1, z1 = worldToLocal(frontTractor.rootNode, x, y, z)
		local distance = Utils.vector2Length(x1, z1)
		if z1 > -backDistance and dz > -0.9 then
			-- tractor in front of tractor
			-- left side of tractor
			local cx_left, cy_left, cz_left = localToWorld(frontTractor.rootNode, 30, 0, -backDistance-20)
			-- righ side of tractor
			local cx_right, cy_right, cz_right = localToWorld(frontTractor.rootNode, -30, 0, -backDistance-20)
			local lx, ly, lz = worldToLocal(self.cp.DirectionNode, cx_left, y, cz_left)
			-- distance to left position
			local disL = Utils.vector2Length(lx, lz)
			local rx, ry, rz = worldToLocal(self.cp.DirectionNode, cx_right, y, cz_right)
			-- distance to right position
			local disR = Utils.vector2Length(rx, rz)
			if disL < disR then
				currentX, currentY, currentZ = cx_left, cy_left, cz_left
			else
				currentX, currentY, currentZ = cx_right, cy_right, cz_right
			end
		else
			-- tractor behind tractor
			currentX, currentY, currentZ = localToWorld(frontTractor.rootNode, 0, 0, -backDistance * 1.5); -- -backDistance * 1
		end;



		local lx, ly, lz = worldToLocal(self.cp.DirectionNode, currentX, currentY, currentZ)
		dod = Utils.vector2Length(lx, lz)
		-- if dod < 2 or (self.cp.positionWithCombine == 2 and frontTractor.cp.modeState ~= 3 and dod < 100) then
		if dod < 2 or (self.cp.positionWithCombine == 2 and combine.courseplayers[1].cp.modeState ~= 3 and dod < 100) then
			-- print(string.format('\tdod=%s, frontTractor.cp.modeState=%s -> brakeToStop', tostring(dod), tostring(frontTractor.cp.modeState)));
			allowedToDrive = courseplay:brakeToStop(self)
		end
		if combine.cp.isSugarBeetLoader then
			if distance > 50 then
				refSpeed = self.cp.speeds.max
			else
				refSpeed = Utils.clamp(frontTractor.lastSpeedReal, self.cp.speeds.turn, self.cp.speeds.field)
			end
		else
			if distance > 50 then
				refSpeed = self.cp.speeds.max
			else
				refSpeed = frontTractor.lastSpeedReal --10/3600 -- frontTractor.lastSpeedReal
			end
		end
		--courseplay:debug(string.format("distance: %d  dod: %d",distance,dod ), 4)
	end

	if currentX == nil or currentZ == nil then
		self.cp.infoText = courseplay:loc("CPWaitForWaypoint") -- "Warte bis ich neuen Wegpunkt habe"
		allowedToDrive = courseplay:brakeToStop(self)
	end

	if self.cp.forcedToStop then
		self.cp.infoText = courseplay:loc("CPCombineWantsMeToStop") -- "Drescher sagt ich soll anhalten."
		allowedToDrive = courseplay:brakeToStop(self)
	end

	if self.showWaterWarning then
		allowedToDrive = false
		courseplay:setGlobalInfoText(self, 'WATER');
	end

	-- check traffic and calculate speed
	
	allowedToDrive = courseplay:checkTraffic(self, true, allowedToDrive)
	refSpeed = courseplay:regulateTrafficSpeed(self,refSpeed,allowedToDrive)


	if allowedToDrive then
		if self.cp.speeds.sl == nil then
			self.cp.speeds.sl = 3
		end
		local maxRpm = self.motor.maxRpm[self.cp.speeds.sl]
		local real_speed = self.lastSpeedReal

		if refSpeed == nil then
			refSpeed = real_speed
		end
		
		if self.isRealistic then
			if self.isChopperTurning then
				refSpeed = self.cp.speeds.turn
			end
			courseplay:setMRSpeed(self, refSpeed, self.cp.speeds.sl,allowedToDrive)
		else
			courseplay:setSpeed(self, refSpeed, self.cp.speeds.sl)
		end
	end


	if g_server ~= nil then
		local targetX, targetZ = nil, nil
		local moveForwards = true
		if currentX ~= nil and currentZ ~= nil then
			targetX, targetZ = AIVehicleUtil.getDriveDirection(self.cp.DirectionNode, currentX, y, currentZ)
		else
			allowedToDrive = false
		end

		if not allowedToDrive then
			if self.isRealistic then
				courseplay:driveInMRDirection(self, 0,1,true,dt,false)
			else
				AIVehicleUtil.driveInDirection(self, dt, 30, 0, 0, 28, false, moveForwards, 0, 1)
				if g_server ~= nil then
					AIVehicleUtil.driveInDirection(self, dt, self.cp.steeringAngle, 0.5, 0.5, 28, false, moveForwards, 0, 1)
				end
				
			end
			-- unload active tipper if given
			return;
		end
		
		if self.cp.TrafficBrake then
			if self.isRealistic then
				AIVehicleUtil.mrDriveInDirection(self, dt, 1, false, true, 0, 1, self.cp.speeds.sl, true, true)
			else
				moveForwards = false
				lx = 0
				lz = 1
			end
		end

		self.cp.TrafficBrake = false
		if self.cp.modeState == 5 or self.cp.modeState == 2 then
			targetX, targetZ = courseplay:isTheWayToTargetFree(self, targetX, targetZ)
		end
		courseplay:setTrafficCollision(self, targetX, targetZ,true)
		
		if self.isRealistic then
		
			courseplay:driveInMRDirection(self, targetX, targetZ,moveForwards, dt, allowedToDrive);
		else
			AIVehicleUtil.driveInDirection(self, dt, self.cp.steeringAngle, 0.5, 0.5, 8, allowedToDrive, moveForwards, targetX, targetZ, self.cp.speeds.sl, 0.4)
		end

		if courseplay.debugChannels[4] and self.cp.nextTargets and self.cp.curTarget.x and self.cp.curTarget.z then
			drawDebugPoint(self.cp.curTarget.x, self.cp.curTarget.y or 0, self.cp.curTarget.z, 1, 0.65, 0, 1);
			
			for i,tp in pairs(self.cp.nextTargets) do
				drawDebugPoint(tp.x, tp.y or 0, tp.z, 1, 0.65, 0, 1);
				if i == 1 then
					drawDebugLine(self.cp.curTarget.x, self.cp.curTarget.y or 0, self.cp.curTarget.z, 1, 0, 1, tp.x, tp.y or 0, tp.z, 1, 0, 1); 
				else
					local pp = self.cp.nextTargets[i-1];
					drawDebugLine(pp.x, pp.y or 0, pp.z, 1, 0, 1, tp.x, tp.y or 0, tp.z, 1, 0, 1); 
				end;
			end;
		end;
	end
end

function courseplay:calculate_course_to(self, target_x, target_z)
	local curFile = "mode2.lua"

	self.cp.calculatedCourseToCombine = true
	-- check if there is fruit between me and the target, return false if not to avoid the calculating
	local node = self.cp.DirectionNode
	local x, y, z = getWorldTranslation(node)
	local hx, hy, hz = localToWorld(node, -2, 0, 0)
	local lx, ly, lz = nil, nil, nil
	local dlx, dly, dlz = worldToLocal(node, target_x, y, target_z)
	local dnx = dlz * -1
	local dnz = dlx
	local angle = math.atan(dnz / dnx)
	dnx = math.cos(angle) * -2
	dnz = math.sin(angle) * -2
	hx, hy, hz = localToWorld(node, dnx, 0, dnz)
	local density = 0
	for i = 1, FruitUtil.NUM_FRUITTYPES do
		if i ~= FruitUtil.FRUITTYPE_GRASS then
			density = density + Utils.getFruitArea(i, x, z, target_x, target_z, hx, hz);
		end
	end
	if density == 0 then
		return false
	end
	if not self.cp.realisticDriving then
		return false
	end
	if self.cp.activeCombine ~= nil then
		local fruit_type = self.cp.activeCombine.lastValidInputFruitType
	elseif self.cp.tipperAttached then
		local fruit_type = self.tippers[1].getCurrentFruitType
	else
		local fruit_type = nil
	end
	--courseplay:debug(string.format("position x: %d z %d", x, z ), 4)
	local wp_counter = 0
	local wps = CalcMoves(z, x, target_z, target_x, fruit_type)
	--courseplay:debug(tableShow(wps, nameNum(self) .. " wps"), 4)
	if wps ~= nil then
		self.next_targets = {}
		for _, wp in pairs(wps) do
			wp_counter = wp_counter + 1
			local next_wp = { x = wp.y, y = 0, z = wp.x }
			table.insert(self.next_targets, next_wp)
			wp_counter = 0
		end
		self.target_x = self.next_targets[1].x
		self.target_y = self.next_targets[1].y
		self.target_z = self.next_targets[1].z
		self.no_speed_limit = true
		table.remove(self.next_targets, 1)
		self.cp.modeState = 5
	else
		return false
	end
	return true
end

function courseplay:calculateCombineOffset(self, combine)
	local curFile = "mode2.lua";
	local offs = self.cp.combineOffset
	local offsPos = math.abs(self.cp.combineOffset)
	
	local prnX,prnY,prnZ, prnwX,prnwY,prnwZ, combineToPrnX,combineToPrnY,combineToPrnZ = 0,0,0, 0,0,0, 0,0,0;
	if combine.pipeRaycastNode ~= nil then
		prnX, prnY, prnZ = getTranslation(combine.pipeRaycastNode)
		prnwX, prnwY, prnwZ = getWorldTranslation(combine.pipeRaycastNode)
		combineToPrnX, combineToPrnY, combineToPrnZ = worldToLocal(combine.rootNode, prnwX, prnwY, prnwZ)

		if combineToPrnX >= 0 then
			combine.cp.pipeSide = 1; --left
			--print("pipe is left")
		else
			combine.cp.pipeSide = -1; --right
			--print("pipe is right")		
		end;
	end;

	--special tools, special cases
	if self.cp.combineOffsetAutoMode and combine.cp.isJohnDeereS650 then
		offs =  7.7;
	elseif self.cp.combineOffsetAutoMode and combine.cp.isCaseIH7130 then
		offs =  8.0;
	elseif self.cp.combineOffsetAutoMode and (combine.cp.isCaseIH9230 or combine.cp.isCaseIH9230Crawler) then
		offs = 11.5;
	elseif self.cp.combineOffsetAutoMode and combine.cp.isDeutz5465H then
		offs =  5.1;
	elseif self.cp.combineOffsetAutoMode and combine.cp.isGrimmeRootster604 then
		offs = -4.3;
	elseif self.cp.combineOffsetAutoMode and combine.cp.isGrimmeSE7555 then
		offs =  4.3;
	elseif self.cp.combineOffsetAutoMode and combine.cp.isFahrM66 then
		offs =  4.4;
	elseif self.cp.combineOffsetAutoMode and combine.cp.isJF1060 then
		offs =  7.0;
	elseif self.cp.combineOffsetAutoMode and combine.cp.isRopaEuroTiger then
		offs =  5.2;
	
	--Sugarbeet Loaders (e.g. Ropa Euro Maus, Holmer Terra Felis)
	elseif self.cp.combineOffsetAutoMode and combine.cp.isSugarBeetLoader then
		local utwX,utwY,utwZ = getWorldTranslation(combine.unloadingTrigger.node);
		local combineToUtwX,_,combineToUtwZ = worldToLocal(combine.rootNode, utwX,utwY,utwZ);
		offs = combineToUtwX;

	--combine // combine_offset is in auto mode, pipe is open
	elseif not combine.cp.isChopper and self.cp.combineOffsetAutoMode and combine.currentPipeState == 2 and combine.pipeRaycastNode ~= nil then --pipe is open
		if getParent(combine.pipeRaycastNode) == combine.rootNode then -- pipeRaycastNode is direct child of combine.root
			--safety distance so the trailer doesn't crash into the pipe (sidearm)
			local additionalSafetyDistance = 0;
			if combine.cp.isGrimmeMaxtron620 then
				additionalSafetyDistance = 0.9;
			elseif combine.cp.isGrimmeTectron415 then
				additionalSafetyDistance = -0.5;
			end;

			offs = prnX + additionalSafetyDistance;
			--courseplay:debug(string.format("%s(%i): %s @ %s: root > pipeRaycastNode // offs = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, offs), 4)
		elseif getParent(getParent(combine.pipeRaycastNode)) == combine.rootNode then --pipeRaycastNode is direct child of pipe is direct child of combine.root
			local pipeX, pipeY, pipeZ = getTranslation(getParent(combine.pipeRaycastNode))
			offs = pipeX - prnZ;
			
			if prnZ == 0 or combine.cp.isGrimmeRootster604 then
				offs = pipeX - prnY;
			end;
			--courseplay:debug(string.format("%s(%i): %s @ %s: root > pipe > pipeRaycastNode // offs = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, offs), 4)
		elseif combine.pipeRaycastNode ~= nil then --BACKUP pipeRaycastNode isn't direct child of pipe
			offs = combineToPrnX + 0.5;
			--courseplay:debug(string.format("%s(%i): %s @ %s: combineToPrnX // offs = %f", curFile, debug.getinfo(1).currentline, self.name, combine.name, offs), 4)
		elseif combine.cp.lmX ~= nil then --user leftMarker
			offs = combine.cp.lmX + 2.5;
		else --if all else fails
			offs = 8;
		end;

	--combine // combine_offset is in manual mode
	elseif not combine.cp.isChopper and not self.cp.combineOffsetAutoMode and combine.pipeRaycastNode ~= nil then
		offs = offsPos * combine.cp.pipeSide;
		--courseplay:debug(string.format("%s(%i): %s @ %s: [manual] offs = offsPos * pipeSide = %s * %s = %s", curFile, debug.getinfo(1).currentline, self.name, combine.name, tostring(offsPos), tostring(combine.cp.pipeSide), tostring(offs)), 4);
	
	--combine // combine_offset is in auto mode
	elseif not combine.cp.isChopper and self.cp.combineOffsetAutoMode and combine.pipeRaycastNode ~= nil then
		offs = offsPos * combine.cp.pipeSide;
		--courseplay:debug(string.format("%s(%i): %s @ %s: [auto] offs = offsPos * pipeSide = %s * %s = %s", curFile, debug.getinfo(1).currentline, self.name, combine.name, tostring(offsPos), tostring(combine.cp.pipeSide), tostring(offs)), 4);

	--chopper // combine_offset is in auto mode
	elseif combine.cp.isChopper and self.cp.combineOffsetAutoMode then
		if combine.cp.lmX ~= nil then
			offs = math.max(combine.cp.lmX + 2.5, 7);
		else
			offs = 8;
		end;
		courseplay:sideToDrive(self, combine, 10);
			
		if self.sideToDrive ~= nil then
			if self.sideToDrive == "left" then
				offs = math.abs(offs);
			elseif self.sideToDrive == "right" then
				offs = math.abs(offs) * -1;
			end;
		end;
	end;
	
	--cornChopper forced side offset
	if combine.cp.isChopper and combine.cp.forcedSide ~= nil then
		if combine.cp.forcedSide == "left" then
			offs = math.abs(offs);
		elseif combine.cp.forcedSide == "right" then
			offs = math.abs(offs) * -1;
		end
		--courseplay:debug(string.format("%s(%i): %s @ %s: cp.forcedSide=%s => offs=%f", curFile, debug.getinfo(1).currentline, self.name, combine.name, combine.cp.forcedSide, offs), 4)
	end

	--refresh for display in HUD and other calculations
	self.cp.combineOffset = offs;
end;

function courseplay:calculateVerticalOffset(self, combine)
	local cwX,cwY,cwZ;
	if combine.cp.isSugarBeetLoader then
		cwX, cwY, cwZ = getWorldTranslation(combine.unloadingTrigger.node);
	else
		cwX, cwY, cwZ = getWorldTranslation(combine.pipeRaycastNode);
	end;
	
	local _, _, prnToCombineZ = worldToLocal(combine.rootNode, cwX, cwY, cwZ); 
	
	return prnToCombineZ;
end;

function courseplay:setTargetUnloadingCoords(self, combine, trailer_offset, prnToCombineZ)
	local sourceRootNode = combine.rootNode;

	if combine.cp.isChopper then
		prnToCombineZ = 0;

		if combine.attachedImplements ~= nil then
			for k, i in pairs(combine.attachedImplements) do
				local implement = i.object;
				if implement.haeckseldolly == true then
					sourceRootNode = implement.rootNode;
				end;
			end;
		end;
	end;
	
	local ttX, _, ttZ = localToWorld(sourceRootNode, self.cp.combineOffset, 0, trailer_offset + prnToCombineZ);
	
	return ttX, ttZ;
end;
