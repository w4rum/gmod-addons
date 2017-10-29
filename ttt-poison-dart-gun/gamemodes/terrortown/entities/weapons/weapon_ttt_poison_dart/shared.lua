AddCSLuaFile() -- send lua file to clients

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

SWEP.Primary.ClipSize       = 1
SWEP.Primary.DefaultClip    = 0 -- will be overwritten on spawn by ammo amount set in cvar
local ammoname              = "poisondart-gun-ammo"
SWEP.Primary.Ammo           = ammoname
game.AddAmmoType( {
    name = ammoname,
    force = 0,
    npcdmg = 0,
    plydmg = 0
})
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

if SERVER then
    CreateConVar("ttt_poisondart_interval", 1, {}, "The amount of seconds between each damage tick of the poison"):GetInt()
    CreateConVar("ttt_poisondart_damage", 3, {}, "The amount of damage each tick of the poison deals"):GetInt()
    CreateConVar("ttt_poisondart_ticks", 34, {}, "The amount of ticks the poison lasts before wearing off"):GetInt()
end
CreateConVar("ttt_poisondart_ammo", 1, { FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE}, "The amount of ammo a player gets when first purchasing the poison dart gun")

function SWEP:WasBought(buyer)
    if (SERVER) then
        local desiredAmmo = GetConVar("ttt_poisondart_ammo"):GetInt();
        if (desiredAmmo > 0) then
            self.Weapon:SetClip1(1)
            buyer:GiveAmmo(desiredAmmo - 1, self.Primary.Ammo, true)
        end
    end
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
            -- get fresh configuration
            poisonInterval = GetConVar("ttt_poisondart_interval"):GetInt()
            poisonDamage = GetConVar("ttt_poisondart_damage"):GetInt()
            poisonTicks = GetConVar("ttt_poisondart_ticks"):GetInt()

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
            victim.poisonticksPassed = 0

            victim.poisonDmgInfo = DamageInfo()
            victim.poisonDmgInfo:SetDamage(poisonDamage)
            if IsValid(self.Owner) then
                victim.poisonDmgInfo:SetAttacker(self.Owner)
            end
            victim.poisonDmgInfo:SetInflictor(self)
            victim.poisonDmgInfo:SetDamageType(DMG_NERVEGAS) -- DMG_POISON produces a bright flash that I couldn't scale down
            -- reported position = red bar on the side of the screen shown upon taking damage
            -- to hide the attacker's position on poison ticks, show victim position instead
            victim.poisonDmgInfo:SetReportedPosition(victim:GetPos())

            timer.Create(timerName, poisonInterval, 0, function()
                -- if stop flag has been set, destroy timer
                if not victim:GetNWBool("poisondart_poisoned", false) then
                    timer.Destroy(timerName)
                else
                    -- only run as long as victim is alive, stop timer otherwise
                    local ticksPassed = victim.poisonticksPassed
                    if IsValid(victim) and victim:IsTerror() and victim:Alive() and (ticksPassed < poisonTicks) then
                        victim:TakeDamageInfo(victim.poisonDmgInfo)
                        victim.poisonticksPassed = victim.poisonticksPassed + 1
                    else
                        victim:SetNWBool("poisondart_poisoned", false)
                    end
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

-- make the screen slightly yellow and blend some frames as a kind of "nausea" effect
if CLIENT then
    hook.Add("RenderScreenspaceEffects", "poisondart_ppeffects", function()
        if LocalPlayer():GetNWBool("poisondart_poisoned", false) then
            local colorModify = {
	        [ "$pp_colour_addr" ] = 0.3,
	        [ "$pp_colour_addg" ] = 0.3,
	        [ "$pp_colour_addb" ] = 0,
	        [ "$pp_colour_brightness" ] = 0,
	        [ "$pp_colour_contrast" ] = 1,
	        [ "$pp_colour_colour" ] = 1,
	        [ "$pp_colour_mulr" ] = 0,
	        [ "$pp_colour_mulg" ] = 0,
                [ "$pp_colour_mulb" ] = 0
            }
            DrawColorModify(colorModify)
            DrawMotionBlur(0.17, 0.65, 0.03)
        end
    end)

    -- remove poison warning notification upon taking DMG_POISON damage
    -- currently not doing anything as DMG_NERVEGAS is used instead
    hook.Add("HUDShouldDraw", "poisondart_disablepoisonwarning", function(name)
        if (name == "CHudPoisonDamageIndicator") then return false end
    end)
end

-- remove any poison effects on player death or round start
if SERVER then
    hook.Add("PostPlayerDeath", "poisondart_unpoison_on_death", function(ply, infl, att)
        ply:SetNWBool("poisondart_poisoned", false)
    end)
    hook.Add("TTTPrepareRound", "poisondart_unpoison_on_prepare", function()
        for i, j in pairs(player.GetAll()) do
            j:SetNWBool("poisondart_poisoned", false)
        end
    end)
end

