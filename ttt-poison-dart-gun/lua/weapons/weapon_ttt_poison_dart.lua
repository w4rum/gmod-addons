AddCSLuaFile()

if CLIENT then
   SWEP.PrintName = "Neurotoxin Gun"
   SWEP.Author = "TFlippy + Infaredz"
   
   SWEP.Slot      = 6 -- add 1 to get the slot number key
   SWEP.Icon = "tflippy/vgui/ttt/icon_dartgun"
   
   SWEP.ViewModelFOV  = 45
   SWEP.ViewModelFlip = false
   SWEP.CSMuzzleFlashes = true
   
   SWEP.EquipMenuData = {
   type = "Weapon",
   desc = "A gas-powered gun that shoots \nneurotoxin-filled bullets."
   };
end

SWEP.Base				= "weapon_tttbase"

SWEP.HoldType			= "pistol"
SWEP.AutoSpawnable      = false
SWEP.AllowDrop = true
SWEP.IsSilent = true
SWEP.NoSights = true
SWEP.Kind = WEAPON_EQUIP1

SWEP.Primary.Delay       = 5.00
SWEP.Primary.Recoil      = 4.50
SWEP.Primary.Automatic   = false
SWEP.Primary.SoundLevel	= 30

SWEP.Primary.ClipSize    = 1
SWEP.Primary.ClipMax     = 3
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Ammo        = "AR2AltFire"
SWEP.HeadshotMultiplier = 5

SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.LimitedStock = true

SWEP.Primary.Damage      = 5
SWEP.Primary.Cone        = 0.00025
SWEP.Primary.NumShots 	 = 0

SWEP.IronSightsPos = Vector(-5.0, -4, 2.799)
SWEP.IronSightsAng = Vector(0, 0, 0)

SWEP.UseHands	= true
SWEP.ViewModel  = Model("models/tflippy/cstrike/c_pist_usp.mdl")
SWEP.WorldModel = Model("models/tflippy/w_pist_usp_silencer.mdl")
SWEP.Primary.Sound = Sound( "Neurotoxin.TFlippy.Single" )
 
SWEP.PrimaryAnim = ACT_VM_PRIMARYATTACK_SILENCED
SWEP.ReloadAnim = ACT_VM_RELOAD_SILENCED
 
function SWEP:Deploy()
   self.Weapon:SendWeaponAnim(ACT_VM_DRAW_SILENCED)
   return true
end
  
function SWEP:Shoot()
   local cone = self.Primary.Cone
   local bullet = {}
   bullet.Num       = self.Primary.NumShots
   bullet.Src       = self.Owner:GetShootPos()
   bullet.Dir       = self.Owner:GetAimVector()
   bullet.Tracer    = 1
   bullet.Force     = 1
   bullet.Damage    = self.Primary.Damage
   bullet.TracerName = "AntlionGib"

   self.Owner:FireBullets( bullet )
end
  
function SWEP:PrimaryAttack(worldsnd)
   self.Weapon:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
   self.Weapon:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
 
   if not self:CanPrimaryAttack() then return end
    
	self.Owner:LagCompensation(true)
	
   if not worldsnd then
      self.Weapon:EmitSound( self.Primary.Sound )
	  self.Weapon:SendWeaponAnim(ACT_VM_PRIMARYATTACK_SILENCED)
   else
      WorldSound(self.Primary.Sound, self:GetPos())
   end

   local Tracer = 1
   
   self:Shoot()

   if SERVER then
   if self.Owner:GetEyeTrace().HitNonWorld and self.Owner:GetEyeTrace().Entity:IsPlayer() then
  
   local en = self.Owner:GetEyeTrace().Entity
   local uni = en:UniqueID()
   en:EmitSound("ambient/voices/citizen_beaten" .. math.random(1,5) .. ".wav",500,100)
   DamageLog("POISON:\t " .. self.Owner:Nick() .. " [" .. self.Owner:GetRoleString() .. "]" .. " poisoned " .. (IsValid(en) and en:Nick() or "<disconnected>") .." [" .. en:GetRoleString() .. "]" .. " with a Neurotoxin Gun.")
   timer.Create(en:UniqueID() .. "poisondart", 1, 0, function()
    
   if IsValid(en) and en:IsTerror() then
   if IsValid(self.Owner) then
   en:TakeDamage(3,self.Weapon,self.Owner)
   
   else
      en:TakeDamage(3,self.Weapon,self.Weapon)
   end
else
timer.Destroy(uni .. "poisondart")
end
   end)
    
   end
   end
   self:TakePrimaryAmmo( 1 )
    
   if IsValid(self.Owner) then
      self.Owner:SetAnimation( PLAYER_ATTACK1 )

      self.Owner:ViewPunch( Angle( math.Rand(-0.8,-0.8) * self.Primary.Recoil, math.Rand(-0.1,0.1) *self.Primary.Recoil, 0 ) )
   end

   if ( (game.SinglePlayer() && SERVER) || CLIENT ) then
      self:SetNetworkedFloat( "LastShootTime", CurTime() )
   end
 
	self.Owner:LagCompensation(false)
 
end

function SWEP:WasBought(buyer)
   if IsValid(buyer) then
      buyer:GiveAmmo( 2, "AR2AltFire" )
   end
end