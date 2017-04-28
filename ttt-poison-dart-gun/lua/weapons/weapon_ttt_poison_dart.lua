AddCSLuaFile()

if CLIENT then
    SWEP.PrintName          = "Neurotoxin Gun"
    SWEP.Author             = "TFlippy, Infaredz and w4rum"

    SWEP.Slot               = 6 -- zero-based here, will be +1 in the ingame HUD
    SWEP.Icon               = "tflippy/vgui/ttt/icon_dartgun"

    SWEP.ViewModelFOV       = 45
    SWEP.ViewModelFlip      = false
    SWEP.CSMuzzleFlashes    = true

    SWEP.EquipMenuData = {
        type = "Weapon",
        desc = "A gas-powered gun that shoots neurotoxin-filled bullets."
    };
end

SWEP.Base                   = "weapon_tttbase"
SWEP.HoldType               = "pistol"
SWEP.AutoSpawnable          = false
SWEP.AllowDrop              = true
SWEP.IsSilent               = true
SWEP.NoSights               = true
SWEP.Kind = WEAPON_EQUIP1

SWEP.Primary.Delay          = 5.00
SWEP.Primary.Recoil         = 4.50
SWEP.Primary.Automatic      = false
SWEP.Primary.SoundLevel     = 30

if SERVER then
    CreateConVar("ttt_poisondart_ammo", 1, { FCVAR_REPLICATED }, "The amount of ammo a player gets when first purchasing the poison dart gun.")
end
local ammo = GetConVar("ttt_poisondart_ammo"):GetInt();
SWEP.Primary.ClipSize       = 1
SWEP.Primary.ClipMax        = ammo
SWEP.Primary.DefaultClip    = ammo
SWEP.Primary.Ammo           = "noammo"
SWEP.HeadshotMultiplier     = 0

SWEP.CanBuy                 = { ROLE_TRAITOR }
SWEP.LimitedStock           = true

SWEP.Primary.Damage         = 0
SWEP.Primary.Cone           = 0.00025
SWEP.Primary.NumShots       = 0

SWEP.IronSightsPos          = Vector(-5.0, -4, 2.799)
SWEP.IronSightsAng          = Vector(0, 0, 0)

SWEP.UseHands               = true
SWEP.ViewModel              = Model("models/tflippy/cstrike/c_pist_usp.mdl")
SWEP.WorldModel             = Model("models/tflippy/w_pist_usp_silencer.mdl")
SWEP.Primary.Sound          = Sound( "Neurotoxin.TFlippy.Single" )

SWEP.PrimaryAnim            = ACT_VM_PRIMARYATTACK_SILENCED
SWEP.ReloadAnim             = ACT_VM_RELOAD_SILENCED

local poisonInterval = 1
local poisonDamage = 3
local poisonTicks = 40

if (SERVER) then
    poisonInterval = CreateConVar("ttt_poisondart_interval", 1, {}, "The amount of seconds between each damage tick of the poison")
    poisonDamage = CreateConVar("ttt_poisondart_damage", 3, {}, "The amount of damage each tick of the poison deals")
    poisonTicks = CreateConVar("ttt_poisondart_ticks", 1, {}, "The amount of ticks the poison lasts before wearing off")
end

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

    self.Owner:FireBullets(bullet)
end

function SWEP:PrimaryAttack(worldsnd)
    self.Weapon:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
    self.Weapon:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

    if not self:CanPrimaryAttack() then return end

    self.Owner:LagCompensation(true)

    -- sound
    if not worldsnd then
        self.Weapon:EmitSound( self.Primary.Sound )
        self.Weapon:SendWeaponAnim(ACT_VM_PRIMARYATTACK_SILENCED)
    else
        WorldSound(self.Primary.Sound, self:GetPos())
    end

    self:Shoot()

    if SERVER then
        if self.Owner:GetEyeTrace().HitNonWorld and self.Owner:GetEyeTrace().Entity:IsPlayer() then

            local victim = self.Owner:GetEyeTrace().Entity
            local uid = victim:UniqueID()
            victim:EmitSound("ambient/voices/citizen_beaten" .. math.random(1,5) .. ".wav",500,100)

            -- damagelog entry
            DamageLog("POISON:\t " .. self.Owner:Nick() .. " [" .. self.Owner:GetRoleString() .. "]" ..
                " poisoned " .. (IsValid(victim) and victim:Nick() or "<disconnected>") .." [" ..
                victim:GetRoleString() .. "]" .. " with a Neurotoxin Gun.")

            -- continuous poison damage
            victim:SetNWBool("poisondart_poisoned", true)
            local timerName = uid .. "poisondart"
            timer.Create(timerName, poisonInterval, poisonTicks, function()
                
                -- only run as long as victim is alive, stop timer otherwise
                if IsValid(victim) and victim:IsTerror() then
                    local dmginfo = DamageInfo()
                    dmginfo:SetDamage(poisonDamage)
                    if IsValid(self.Owner) then
                        dmginfo:SetAttacker(self.Owner)
                    end
                    dmginfo:SetInflictor(self)
                    dmginfo:SetDamageType(DMG_POISON)

                else
                    victim:SetNWBool("poisondart_poisoned", false)
                    timer.Destroy(timerName)
                end
            end)
        end
    end
    self:TakePrimaryAmmo(1)

    if IsValid(self.Owner) then
        self.Owner:SetAnimation( PLAYER_ATTACK1 )

        self.Owner:ViewPunch( Angle( math.Rand(-0.8,-0.8) * self.Primary.Recoil, math.Rand(-0.1,0.1) *self.Primary.Recoil, 0 ) )
    end

    if ( (game.SinglePlayer() && SERVER) || CLIENT ) then
        self:SetNetworkedFloat( "LastShootTime", CurTime() )
    end

    self.Owner:LagCompensation(false)

end

hook.Add("DrawOverlay", "poisondart_overlay", function()
    if LocalPlayer:GetNWBool("poisondart_poisoned", false) then
        DrawColorModify({ 
            [ "$pp_colour_addr" ] = 0.02,
            [ "$pp_colour_addg" ] = 0.02,
    })
    end
end)
