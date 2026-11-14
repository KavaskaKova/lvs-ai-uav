function ENT:OnCreateAI()
	self:StartEngine()
end

function ENT:OnRemoveAI()
	self:StopEngine()
end

function ENT:AIGetRamTarget( ent )
	if not IsValid( ent ) or ent == self then return NULL end

	if not self:IsEnemy( ent ) then return NULL end

	if ent:IsPlayer() then
		if not ent:Alive() then return NULL end

		local Veh = ent:lvsGetVehicle()

		if IsValid( Veh ) then
			ent = Veh
		end
	end

	if ent.LVS and ent.IsDestroyed and ent:IsDestroyed() then return NULL end

	return ent
end

function ENT:AIGetKamikazeTarget()
	local Target = self:AIGetRamTarget( self:GetHardLockTarget() )

	if IsValid( Target ) then return Target end

	local Found = self:AIGetTarget()

	Target = self:AIGetRamTarget( Found )

	if IsValid( Target ) then return Target end

	if IsValid( Found ) then
		self._lvsNextAICheck = 0
	end

	return NULL
end

function ENT:RunAI()
	local mySpeed = self:GetVelocity():Length()
	local myPos = self:GetPos()
	local StartPos = self:LocalToWorld( self:OBBCenter() )

	local TraceFilter = self:GetCrosshairFilterEnts()

	local Victim = self:AIGetKamikazeTarget()

	self._lvsRamTarget = Victim

	if IsValid( Victim ) then
		local TargetPos = Victim:LocalToWorld( Victim:OBBCenter() )

		local Dist = (TargetPos - StartPos):Length()
		local LeadTime = math.Clamp( Dist / math.max( mySpeed, 500 ), 0, 3 )

		TargetPos = TargetPos + Victim:GetVelocity() * LeadTime

		if Dist > 800 then
			local TraceDown = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + Vector(0,0,-300) } )

			if TraceDown.Hit then
				TargetPos.z = math.max( TargetPos.z, StartPos.z + 500 )
			end
		end

		self._AIFireInput = false

		self._lvsTargetPos = TargetPos

		self:SetAIAimVector( (TargetPos - myPos):GetNormalized() )

		return
	end

	local RangerLength = 15000

	local myRadius = self:BoundingRadius()
	local myDir = self:GetForward()

	local MinDist = 600 + mySpeed

	local FrontLeft = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles( Angle(0,20,0) ):Forward() * RangerLength } )
	local FrontRight = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles( Angle(0,-20,0) ):Forward() * RangerLength } )

	local FrontLeft2 = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles( Angle(25,65,0) ):Forward() * RangerLength } )
	local FrontRight2 = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles( Angle(25,-65,0) ):Forward() * RangerLength } )

	local FrontLeft3 = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles( Angle(-25,65,0) ):Forward() * RangerLength } )
	local FrontRight3 = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles( Angle(-25,-65,0) ):Forward() * RangerLength } )

	local FrontUp = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles( Angle(-20,0,0) ):Forward() * RangerLength } )
	local FrontDown = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + self:LocalToWorldAngles( Angle(20,0,0) ):Forward() * RangerLength } )

	local TraceDown = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + Vector(0,0,-RangerLength) } )
	local TraceUp = util.TraceLine( { start = StartPos, filter = TraceFilter, endpos = StartPos + Vector(0,0,RangerLength) } )

	local cAvoid = Vector(0,0,0)

	for _, v in pairs( LVS:GetVehicles() ) do
		if v == self then continue end

		local theirRadius = v:BoundingRadius()
		local Sub = (myPos - v:GetPos())
		local Dir = Sub:GetNormalized()
		local Dist = Sub:Length()

		if Dist < (theirRadius + myRadius + 200) then
			if math.deg( math.acos( math.Clamp( myDir:Dot( -Dir ) ,-1,1) ) ) < 90 then
				cAvoid = cAvoid + Dir * (theirRadius + myRadius + 500)
			end
		end
	end

	local FLp = FrontLeft.HitPos + FrontLeft.HitNormal * MinDist + cAvoid * 8
	local FRp = FrontRight.HitPos + FrontRight.HitNormal * MinDist + cAvoid * 8

	local FL2p = FrontLeft2.HitPos + FrontLeft2.HitNormal * MinDist
	local FR2p = FrontRight2.HitPos + FrontRight2.HitNormal * MinDist

	local FL3p = FrontLeft3.HitPos + FrontLeft3.HitNormal * MinDist
	local FR3p = FrontRight3.HitPos + FrontRight3.HitNormal * MinDist

	local FUp = FrontUp.HitPos + FrontUp.HitNormal * MinDist
	local FDp = FrontDown.HitPos + FrontDown.HitNormal * MinDist

	local Up = TraceUp.HitPos + TraceUp.HitNormal * MinDist
	local Dp = TraceDown.HitPos + TraceDown.HitNormal * MinDist

	local TargetPos = (FLp+FRp+FL2p+FR2p+FL3p+FR3p+FUp+FDp+Up+Dp) / 10

	local alt = (StartPos - TraceDown.HitPos):Length()
	local ceiling = (StartPos - TraceUp.HitPos):Length()

	self._AIFireInput = false

	if alt < 600 or ceiling < 600 then
		if ceiling < 600 then
			TargetPos.z = StartPos.z - 2000
		else
			TargetPos.z = StartPos.z + 2000
		end
	end

	self._lvsTargetPos = TargetPos

	self:SetAIAimVector( (TargetPos - myPos):GetNormalized() )
end

function ENT:CalcAIMove( PhysObj, deltatime )
	if not self._lvsTargetPos then return end

	local StartPos = self:LocalToWorld( self:OBBCenter() )

	local TargetPos = self._lvsTargetPos

	local VelL = PhysObj:WorldToLocal( PhysObj:GetPos() + PhysObj:GetVelocity() )
	local AngVel = PhysObj:GetAngleVelocity()

	local LPos = self:WorldToLocal( TargetPos )

	local Pitch = math.Clamp(LPos.x * 0.01 - VelL.x * 0.01,-1,1) * 40
	local Yaw = (TargetPos - StartPos):Angle().y
	local Roll = math.Clamp(VelL.y * 0.01,-1,1) * 40

	local Ang = self:GetAngles()

	local Steer = self:GetSteer()
	Steer.x = math.Clamp( Roll - Ang.r - AngVel.x,-1,1)
	Steer.y = math.Clamp( Pitch - Ang.p - AngVel.y,-1,1)
	Steer.z = math.Clamp( self:WorldToLocalAngles( Angle(0,Yaw,0) ).y / 10,-1,1)

	self:SetSteer( Steer )
	self:SetThrust( math.Clamp( LPos.z - VelL.z,-1,1) )
end

function ENT:AISelectWeapon( ID )
	if ID == self:GetSelectedWeapon() then return end

	local T = CurTime()

	if (self._nextAISwitchWeapon or 0) > T then return end

	self._nextAISwitchWeapon = T + math.random(3,6)

	self:SelectWeapon( ID )
end

function ENT:OnAITakeDamage( dmginfo )
	local attacker = dmginfo:GetAttacker()

	if not IsValid( attacker ) then return end

	self:SetHardLockTarget( attacker )
end

function ENT:SetHardLockTarget( target )
	if not self:IsEnemy( target ) then return end

	self._HardLockTarget =  target
	self._HardLockTime = CurTime() + 4
end

function ENT:GetHardLockTarget()
	if (self._HardLockTime or 0) < CurTime() then return NULL end

	return self._HardLockTarget
end