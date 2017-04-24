--[[ TODO:
	 - Make some nice DamageInfo
]]

if SERVER then
   AddCSLuaFile( "shared.lua" )
end

SWEP.HoldType			= "pistol"

if CLIENT then
   SWEP.PrintName = "Golden Desert Eagle"
   SWEP.Slot = 6

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "A golden Desert Eagle that kills if the target is a traitor. Otherwise, the marksman dies."
   };

   SWEP.Icon = "VGUI/ttt/icon_deagle"
end

SWEP.Base = "weapon_tttbase"
SWEP.Primary.Recoil	= 6
SWEP.Primary.Damage = 0
SWEP.Primary.Delay = 0.6
SWEP.Primary.Cone = 0.02
SWEP.Primary.ClipSize = 1
SWEP.Primary.Automatic = true
SWEP.Primary.DefaultClip = 1
SWEP.Primary.ClipMax = 1
SWEP.Primary.TakeAmmo = 1
SWEP.Primary.Ammo = "Golden Deagle Ammo"

SWEP.Kind = WEAPON_EQUIP1
SWEP.CanBuy = {ROLE_DETECTIVE} -- only traitors can buy
SWEP.WeaponID = AMMO_GOLDENDEAGLE

SWEP.AmmoEnt = "item_ammo_goldendeagle"

SWEP.UseHands			= true
SWEP.ViewModelFlip		= false
SWEP.ViewModelFOV		= 54
SWEP.ViewModel			= "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel			= "models/weapons/w_pist_deagle.mdl"

SWEP.Primary.Sound			= Sound( "Weapon_Deagle.Single" )

SWEP.IronSightsPos = Vector(-6.361, -3.701, 2.15)
SWEP.IronSightsAng = Vector(0, 0, 0)

SWEP.PrimaryAnim = ACT_VM_PRIMARYATTACK

-- We were bought as special equipment, and we have an extra to give
function SWEP:WasBought(buyer)
   if IsValid(buyer) then -- probably already self.Owner
      buyer:GiveAmmo( 1, "Golden Deagle Ammo" )
   end
end

function SWEP:PrimaryAttack()
 
	if ( !self:CanPrimaryAttack() ) then return end
 
	local trace = util.GetPlayerTrace(self.Owner)
	local tr = util.TraceLine(trace)
	
		bullet = {}
		bullet.Num    = 1
		bullet.Src    = self.Owner:GetShootPos()
		bullet.Dir    = self.Owner:GetAimVector()
		bullet.Spread = Vector(0, 0, 0)
		bullet.Tracer = 0
		bullet.Force  = 10000
		bullet.Damage = 0
		self.Owner:FireBullets(bullet)
		self.Weapon:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		self.Weapon:EmitSound(Sound( "Weapon_Deagle.Single" ))
	
	if tr.Entity:IsPlayer() then
		if tr.Entity:IsRole(ROLE_TRAITOR) then
			tr.Entity:TakeDamage(10000)
		else
			if (SERVER) then
				for _, v in pairs(player.GetAll()) do
					v:ChatPrint( self.Owner:Nick() .. " has not hit a traitor with the Golden Desert Eagle!" )
				end
			self.Owner:Kill()
			end
		end
	else
		if (SERVER) then
			for _, v in pairs(player.GetAll()) do
				v:ChatPrint( self.Owner:Nick() .. " has not hit a traitor with the Golden Desert Eagle!" )
			end
			self.Owner:Kill()
		end
	end 
	
	self:TakePrimaryAmmo(self.Primary.TakeAmmo)
	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
end 