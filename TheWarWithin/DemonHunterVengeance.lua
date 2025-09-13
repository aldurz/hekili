-- DemonHunterVengeance.lua
-- August 2025
-- Patch 11.2

-- TODO: Support other sources of queued fragments, like sigils.
-- TODO: Improve timeliness of soul fragments

if UnitClassBase( "player" ) ~= "DEMONHUNTER" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State
local spec = Hekili:NewSpecialization( 581 )

---- Local function declarations for increased performance
-- Strings
local strformat = string.format
-- Tables
local insert, remove, sort, wipe = table.insert, table.remove, table.sort, table.wipe
-- Math
local abs, ceil, floor, max, sqrt = math.abs, math.ceil, math.floor, math.max, math.sqrt

-- Common WoW APIs, comment out unneeded per-spec
-- local GetSpellCastCount = C_Spell.GetSpellCastCount
-- local GetSpellInfo = C_Spell.GetSpellInfo
-- local GetSpellInfo = ns.GetUnpackedSpellInfo
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
-- local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local IsSpellOverlayed = C_SpellActivationOverlay.IsSpellOverlayed
local IsSpellKnownOrOverridesKnown = C_SpellBook.IsSpellInSpellBook
-- local IsActiveSpell = ns.IsActiveSpell

-- Specialization-specific local functions (if any)

spec:RegisterResource( Enum.PowerType.Fury, {
    -- Immolation Aura now grants 8 up front, then 2 per second
    immolation_aura = {
        aura    = "immolation_aura",

        last = function ()
            local app = state.buff.immolation_aura.applied
            local t = state.query_time

            return app + floor( t - app )
        end,

        interval = 1,
        value = 2
    },
    -- 5 fury every 2 seconds for 8 seconds
    student_of_suffering = {
        aura    = "student_of_suffering",

        last = function ()
            local app = state.buff.student_of_suffering.applied
            local t = state.query_time

            return app + floor( t - app )
        end,

        interval = 2,
        value = 5
    },
} )

-- Talents
spec:RegisterTalents( {

    -- Demon Hunter
    aldrachi_design                = {  90999,  391409, 1 }, -- Increases your chance to parry by $s1%
    aura_of_pain                   = {  90933,  207347, 1 }, -- Increases the critical strike chance of Immolation Aura by $s1%
    blazing_path                   = {  91008,  320416, 1 }, -- Infernal Strike gains an additional charge
    bouncing_glaives               = {  90931,  320386, 1 }, -- Throw Glaive ricochets to $s1 additional target
    champion_of_the_glaive         = {  90994,  429211, 1 }, -- Throw Glaive has $s1 charges and $s2 yard increased range
    chaos_fragments                = {  95154,  320412, 1 }, -- Each enemy stunned by Chaos Nova has a $s1% chance to generate a Lesser Soul Fragment
    chaos_nova                     = {  90993,  179057, 1 }, -- Unleash an eruption of fel energy, dealing $s$s2 Chaos damage and stunning all nearby enemies for $s3 sec. Each enemy stunned by Chaos Nova has a $s4% chance to generate a Lesser Soul Fragment
    charred_warblades              = {  90948,  213010, 1 }, -- You heal for $s1% of all Fire damage you deal
    collective_anguish             = {  95152,  390152, 1 }, -- Fel Devastation summons an allied Havoc Demon Hunter who casts Eye Beam, dealing $s$s2 Chaos damage over $s3 sec. Deals reduced damage beyond $s4 targets
    consume_magic                  = {  91006,  278326, 1 }, -- Consume $s1 beneficial Magic effect removing it from the target
    darkness                       = {  91002,  196718, 1 }, -- Summons darkness around you in an $s1 yd radius, granting friendly targets a $s2% chance to avoid all damage from an attack. Lasts $s3 sec. Chance to avoid damage increased by $s4% when not in a raid
    demon_muzzle                   = {  90928,  388111, 1 }, -- Enemies deal $s1% reduced magic damage to you for $s2 sec after being afflicted by one of your Sigils
    demonic                        = {  91003,  213410, 1 }, -- Fel Devastation causes you to enter demon form for $s1 sec after it finishes dealing damage
    disrupting_fury                = {  90937,  183782, 1 }, -- Disrupt generates $s1 Fury on a successful interrupt
    erratic_felheart               = {  90996,  391397, 2 }, -- The cooldown of Infernal Strike is reduced by $s1%
    felblade                       = {  95150,  232893, 1 }, -- Charge to your target and deal $s$s2 Fire damage. Fracture has a chance to reset the cooldown of Felblade. Generates $s3 Fury
    felfire_haste                  = {  90939,  389846, 1 }, -- Infernal Strike increases your movement speed by $s1% for $s2 sec
    flames_of_fury                 = {  90949,  389694, 2 }, -- Sigil of Flame deals $s1% increased damage and generates $s2 additional Fury per target hit
    illidari_knowledge             = {  90935,  389696, 1 }, -- Reduces magic damage taken by $s1%
    imprison                       = {  91007,  217832, 1 }, -- Imprisons a demon, beast, or humanoid, incapacitating them for $s1 min. Damage may cancel the effect. Limit $s2
    improved_disrupt               = {  90938,  320361, 1 }, -- Increases the range of Disrupt to $s1 yds
    improved_sigil_of_misery       = {  90945,  320418, 1 }, -- Reduces the cooldown of Sigil of Misery by $s1 sec
    infernal_armor                 = {  91004,  320331, 2 }, -- Immolation Aura increases your armor by $s2% and causes melee attackers to suffer $s$s3 Fire damage
    internal_struggle              = {  90934,  393822, 1 }, -- Increases your mastery by $s1%
    live_by_the_glaive             = {  95151,  428607, 1 }, -- When you parry an attack or have one of your attacks parried, restore $s1% of max health and $s2 Fury. This effect may only occur once every $s3 sec
    long_night                     = {  91001,  389781, 1 }, -- Increases the duration of Darkness by $s1 sec
    lost_in_darkness               = {  90947,  389849, 1 }, -- Spectral Sight has $s1 sec reduced cooldown and no longer reduces movement speed
    master_of_the_glaive           = {  90994,  389763, 1 }, -- Throw Glaive has $s1 charges and snares all enemies hit by $s2% for $s3 sec
    pitch_black                    = {  91001,  389783, 1 }, -- Reduces the cooldown of Darkness by $s1 sec
    precise_sigils                 = {  95155,  389799, 1 }, -- All Sigils are now placed at your target's location
    pursuit                        = {  90940,  320654, 1 }, -- Mastery increases your movement speed
    quickened_sigils               = {  95149,  209281, 1 }, -- All Sigils activate $s1 second faster
    rush_of_chaos                  = {  95148,  320421, 2 }, -- Reduces the cooldown of Metamorphosis by $s1 sec
    shattered_restoration          = {  90950,  389824, 1 }, -- The healing of Shattered Souls is increased by $s1%
    sigil_of_misery                = {  90946,  207684, 1 }, -- Place a Sigil of Misery at the target location that activates after $s1 sec. Causes all enemies affected by the sigil to cower in fear, disorienting them for $s2 sec
    sigil_of_spite                 = {  90997,  390163, 1 }, -- Place a demonic sigil at the target location that activates after $s2 sec. Detonates to deal $s$s3 Chaos damage and shatter up to $s4 Lesser Soul Fragments from enemies affected by the sigil. Deals reduced damage beyond $s5 targets
    soul_rending                   = {  90936,  204909, 2 }, -- Leech increased by $s1%. Gain an additional $s2% leech while Metamorphosis is active
    soul_sigils                    = {  90929,  395446, 1 }, -- Afflicting an enemy with a Sigil generates $s1 Lesser Soul Fragment
    swallowed_anger                = {  91005,  320313, 1 }, -- Consume Magic generates $s1 Fury when a beneficial Magic effect is successfully removed from the target
    the_hunt                       = {  90927,  370965, 1 }, -- Charge to your target, striking them for $s$s3 Chaos damage, rooting them in place for $s4 sec and inflicting $s$s5 Chaos damage over $s6 sec to up to $s7 enemies in your path. The pursuit invigorates your soul, healing you for $s8% of the damage you deal to your Hunt target for $s9 sec
    unrestrained_fury              = {  90941,  320770, 1 }, -- Increases maximum Fury by $s1
    vengeful_bonds                 = {  90930,  320635, 1 }, -- Vengeful Retreat reduces the movement speed of all nearby enemies by $s1% for $s2 sec
    vengeful_retreat               = {  90942,  198793, 1 }, -- Remove all snares and vault away. Nearby enemies take $s$s2 Physical damage
    will_of_the_illidari           = {  91000,  389695, 1 }, -- Increases maximum health by $s1%

    -- Vengeance
    agonizing_flames               = {  90971,  207548, 1 }, -- Immolation Aura increases your movement speed by $s1% and its duration is increased by $s2%
    ascending_flame                = {  90960,  428603, 1 }, -- Sigil of Flame's initial damage is increased by $s1%. Multiple applications of Sigil of Flame may overlap
    bulk_extraction                = {  90956,  320341, 1 }, -- Demolish the spirit of all those around you, dealing $s$s2 Fire damage to nearby enemies and extracting up to $s3 Lesser Soul Fragments, drawing them to you for immediate consumption
    burning_alive                  = {  90959,  207739, 1 }, -- Every $s1 sec, Fiery Brand spreads to one nearby enemy
    burning_blood                  = {  90987,  390213, 1 }, -- Fire damage increased by $s1%
    calcified_spikes               = {  90967,  389720, 1 }, -- You take $s1% reduced damage after Demon Spikes ends, fading by $s2% per second
    chains_of_anger                = {  90964,  389715, 1 }, -- Increases the duration of your Sigils by $s1 sec and radius by $s2 yds
    charred_flesh                  = {  90962,  336639, 2 }, -- Immolation Aura damage increases the duration of your Fiery Brand and Sigil of Flame by $s1 sec
    cycle_of_binding               = {  90963,  389718, 1 }, -- Sigil of Flame reduces the cooldown of your Sigils by $s1 sec
    darkglare_boon                 = {  90985,  389708, 1 }, -- When Fel Devastation finishes fully channeling, it refreshes $s1-$s2% of its cooldown and refunds $s3-$s4 Fury
    deflecting_spikes              = {  90989,  321028, 1 }, -- Demon Spikes also increases your Parry chance by $s1% for $s2 sec
    down_in_flames                 = {  90961,  389732, 1 }, -- Fiery Brand has $s1 sec reduced cooldown and $s2 additional charge
    extended_spikes                = {  90966,  389721, 1 }, -- Increases the duration of Demon Spikes by $s1 sec
    fallout                        = {  90972,  227174, 1 }, -- Immolation Aura's initial burst has a chance to shatter Lesser Soul Fragments from enemies
    feast_of_souls                 = {  90969,  207697, 1 }, -- Soul Cleave heals you for an additional $s1 over $s2 sec
    feed_the_demon                 = {  90983,  218612, 1 }, -- Consuming a Soul Fragment reduces the remaining cooldown of Demon Spikes by $s1 sec
    fel_devastation                = {  90991,  212084, 1 }, -- Unleash the fel within you, damaging enemies directly in front of you for $s$s3 Fire damage over $s4 sec$s$s5 Causing damage also heals you for up to $s6 health
    fel_flame_fortification        = {  90955,  389705, 1 }, -- You take $s1% reduced magic damage while Immolation Aura is active
    fiery_brand                    = {  90951,  204021, 1 }, -- Brand an enemy with a demonic symbol, instantly dealing $s$s3 Fire damage and $s$s4 Fire damage over $s5 sec. The enemy's damage done to you is reduced by $s6% for $s7 sec
    fiery_demise                   = {  90958,  389220, 2 }, -- Fiery Brand also increases Fire damage you deal to the target by $s1%
    focused_cleave                 = {  90975,  343207, 1 }, -- Soul Cleave deals $s1% increased damage to your primary target
    fracture                       = {  90970,  263642, 1 }, -- Rapidly slash your target for $s$s2 Physical damage, and shatter $s3 Lesser Soul Fragments from them. Generates $s4 Fury
    frailty                        = {  90990,  389958, 1 }, -- Enemies struck by Sigil of Flame are afflicted with Frailty for $s1 sec. You heal for $s2% of all damage you deal to targets with Frailty
    illuminated_sigils             = {  90961,  428557, 1 }, -- Sigil of Flame has $s1 sec reduced cooldown and $s2 additional charge. You have $s3% increased chance to parry attacks from enemies afflicted by your Sigil of Flame
    last_resort                    = {  90979,  209258, 1 }, -- Sustaining fatal damage instead transforms you to Metamorphosis form. This may occur once every $s1 min
    meteoric_strikes               = {  90953,  389724, 1 }, -- Reduce the cooldown of Infernal Strike by $s1 sec
    painbringer                    = {  90976,  207387, 2 }, -- Consuming a Soul Fragment reduces all damage you take by $s1% for $s2 sec. Multiple applications may overlap
    perfectly_balanced_glaive      = {  90968,  320387, 1 }, -- Reduces the cooldown of Throw Glaive by $s1 sec
    retaliation                    = {  90952,  389729, 1 }, -- While Demon Spikes is active, melee attacks against you cause the attacker to take $s$s2 Physical damage. Generates high threat
    revel_in_pain                  = {  90957,  343014, 1 }, -- When Fiery Brand expires on your primary target, you gain a shield that absorbs up $s1 damage for $s2 sec, based on your damage dealt to them while Fiery Brand was active
    roaring_fire                   = {  90988,  391178, 1 }, -- Fel Devastation heals you for up to $s1% more, based on your missing health
    ruinous_bulwark                = {  90965,  326853, 1 }, -- Fel Devastation heals for an additional $s1%, and $s2% of its healing is converted into an absorb shield for $s3 sec
    shear_fury                     = {  90970,  389997, 1 }, -- Shear generates $s1 additional Fury
    sigil_of_chains                = {  90954,  202138, 1 }, -- Place a Sigil of Chains at the target location that activates after $s1 sec. All enemies affected by the sigil are pulled to its center and are snared, reducing movement speed by $s2% for $s3 sec
    sigil_of_silence               = {  90988,  202137, 1 }, -- Place a Sigil of Silence at the target location that activates after $s1 sec. Silences all enemies affected by the sigil for $s2 sec
    soul_barrier                   = {  90956,  263648, 1 }, -- Shield yourself for $s1 sec, absorbing $s2 damage. Consumes all available Soul Fragments to add $s3 to the shield per fragment
    soul_carver                    = {  90982,  207407, 1 }, -- Carve into the soul of your target, dealing $s$s3 Fire damage and an additional $s$s4 Fire damage over $s5 sec. Immediately shatters $s6 Lesser Soul Fragments from the target and $s7 additional Lesser Soul Fragment every $s8 sec
    soul_furnace                   = {  90974,  391165, 1 }, -- Every $s1 Soul Fragments you consume increases the damage of your next Soul Cleave or Spirit Bomb by $s2%
    soulcrush                      = {  90980,  389985, 1 }, -- Multiple applications of Frailty may overlap. Soul Cleave applies Frailty to your primary target for $s1 sec
    soulmonger                     = {  90973,  389711, 1 }, -- When consuming a Soul Fragment would heal you above full health it shields you instead, up to a maximum of $s1
    spirit_bomb                    = {  90978,  247454, 1 }, -- Consume up to $s2 available Soul Fragments then explode, damaging nearby enemies for $s$s3 Fire damage per fragment consumed, and afflicting them with Frailty for $s4 sec, causing you to heal for $s5% of damage you deal to them. Deals reduced damage beyond $s6 targets
    stoke_the_flames               = {  90984,  393827, 1 }, -- Fel Devastation damage increased by $s1%
    void_reaver                    = {  90977,  268175, 1 }, -- Frailty now also reduces all damage you take from afflicted targets by $s1%. Enemies struck by Soul Cleave are afflicted with Frailty for $s2 sec
    volatile_flameblood            = {  90986,  390808, 1 }, -- Immolation Aura generates $s1-$s2 Fury when it deals critical damage. This effect may only occur once per $s3 sec
    vulnerability                  = {  90981,  389976, 2 }, -- Frailty now also increases all damage you deal to afflicted targets by $s1%

    -- Aldrachi Reaver
    aldrachi_tactics               = {  94914,  442683, 1 }, -- The second enhanced ability in a pattern shatters an additional Soul Fragment
    army_unto_oneself              = {  94896,  442714, 1 }, -- Felblade surrounds you with a Blade Ward, reducing damage taken by $s1% for $s2 sec
    art_of_the_glaive              = {  94915,  442290, 1 }, -- Consuming $s2 Soul Fragments or casting The Hunt converts your next Throw Glaive into Reaver's Glaive.  Reaver's Glaive: Throw a glaive enhanced with the essence of consumed souls at your target, dealing $s$s5 Physical damage and ricocheting to $s6 additional enemies. Begins a well-practiced pattern of glaivework, enhancing your next Fracture and Soul Cleave. The enhanced ability you cast first deals $s7% increased damage, and the second deals $s8% increased damage
    evasive_action                 = {  94911,  444926, 1 }, -- Vengeful Retreat can be cast a second time within $s1 sec
    fury_of_the_aldrachi           = {  94898,  442718, 1 }, -- When enhanced by Reaver's Glaive, Soul Cleave casts $s1 additional glaive slashes to nearby targets. If cast after Fracture, cast $s2 slashes instead
    incisive_blade                 = {  94895,  442492, 1 }, -- Soul Cleave deals $s1% increased damage
    incorruptible_spirit           = {  94896,  442736, 1 }, -- Each Soul Fragment you consume shields you for an additional $s1% of the amount healed
    keen_engagement                = {  94910,  442497, 1 }, -- Reaver's Glaive generates $s1 Fury
    preemptive_strike              = {  94910,  444997, 1 }, -- Throw Glaive deals $s$s2 Physical damage to enemies near its initial target
    reavers_mark                   = {  94903,  442679, 1 }, -- When enhanced by Reaver's Glaive, Fracture applies Reaver's Mark, which causes the target to take $s1% increased damage for $s2 sec. Max $s3 stacks. Applies $s4 additional stack of Reaver's Mark If cast after Soul Cleave
    thrill_of_the_fight            = {  94919,  442686, 1 }, -- After consuming both enhancements, gain Thrill of the Fight, increasing your attack speed by $s1% for $s2 sec and your damage and healing by $s3% for $s4 sec
    unhindered_assault             = {  94911,  444931, 1 }, -- Vengeful Retreat resets the cooldown of Felblade
    warblades_hunger               = {  94906,  442502, 1 }, -- Consuming a Soul Fragment causes your next Fracture to deal $s1 additional Physical damage
    wounded_quarry                 = {  94897,  442806, 1 }, -- Expose weaknesses in the target of your Reaver's Mark, causing your Physical damage to any enemy to also deal $s1% of the damage dealt to your marked target as Chaos, and sometimes shatter a Lesser Soul Fragment

    -- Felscarred
    burning_blades                 = {  94905,  452408, 1 }, -- Your blades burn with Fel energy, causing your Soul Cleave, Throw Glaive, and auto-attacks to deal an additional $s1% damage as Fire over $s2 sec
    demonic_intensity              = {  94901,  452415, 1 }, -- Activating Metamorphosis greatly empowers Fel Devastation, Immolation Aura, and Sigil of Flame$s$s2 Demonsurge damage is increased by $s3% for each time it previously triggered while your demon form is active
    demonsurge                     = {  94917,  452402, 1 }, -- Metamorphosis now also greatly empowers Soul Cleave and Spirit Bomb. While demon form is active, the first cast of each empowered ability induces a Demonsurge, causing you to explode with Fel energy, dealing $s$s2 Fire damage to nearby enemies. Deals reduced damage beyond $s3 targets
    enduring_torment               = {  94916,  452410, 1 }, -- The effects of your demon form persist outside of it in a weakened state, increasing maximum health by $s1% and Armor by $s2%
    flamebound                     = {  94902,  452413, 1 }, -- Immolation Aura has $s1 yd increased radius and $s2% increased critical strike damage bonus
    focused_hatred                 = {  94918,  452405, 1 }, -- Demonsurge deals $s1% increased damage when it strikes a single target. Each additional target reduces this bonus by $s2%
    improved_soul_rending          = {  94899,  452407, 1 }, -- Leech granted by Soul Rending increased by $s1% and an additional $s2% while Metamorphosis is active
    monster_rising                 = {  94909,  452414, 1 }, -- Agility increased by $s1% while not in demon form
    pursuit_of_angriness           = {  94913,  452404, 1 }, -- Movement speed increased by $s1% per $s2 Fury
    set_fire_to_the_pain           = {  94899,  452406, 1 }, -- $s2% of all non-Fire damage taken is instead taken as Fire damage over $s3 sec$s$s4 Fire damage taken reduced by $s5%
    student_of_suffering           = {  94902,  452412, 1 }, -- Sigil of Flame applies Student of Suffering to you, increasing Mastery by $s1% and granting $s2 Fury every $s3 sec, for $s4 sec
    untethered_fury                = {  94904,  452411, 1 }, -- Maximum Fury increased by $s1
    violent_transformation         = {  94912,  452409, 1 }, -- When you activate Metamorphosis, the cooldowns of your Sigil of Flame and Fel Devastation are immediately reset
    wave_of_debilitation           = {  94913,  452403, 1 }, -- Chaos Nova slows enemies by $s1% and reduces attack and cast speed by $s2% for $s3 sec after its stun fades
} )

-- PvP Talents
spec:RegisterPvpTalents( {
    blood_moon                     = 5434, -- (355995) Consume Magic now affects all enemies within $s1 yards of the target and generates a Lesser Soul Fragment. Each effect consumed has a $s2% chance to upgrade to a Greater Soul
    cleansed_by_flame              =  814, -- (205625) Immolation Aura dispels a magical effect on you when cast
    cover_of_darkness              = 5520, -- (357419) The radius of Darkness is increased by $s1 yds, and its duration by $s2 sec
    demonic_trample                = 3423, -- (205629) Transform to demon form, moving at $s2% increased speed for $s3 sec, knocking down all enemies in your path and dealing $s$s4 Physical damage. During Demonic Trample you are unaffected by snares but cannot cast spells or use your normal attacks. Shares charges with Infernal Strike
    detainment                     = 3430, -- (205596) Imprison's PvP duration is increased by $s1 sec, and targets become immune to damage and healing while imprisoned
    everlasting_hunt               =  815, -- (205626) Dealing damage increases your movement speed by $s1% for $s2 sec
    glimpse                        = 5522, -- (354489) Vengeful Retreat provides immunity to loss of control effects, and reduces damage taken by $s1% until you land
    illidans_grasp                 =  819, -- (205630) You strangle the target with demonic magic, stunning them in place and dealing $s$s2 Shadow damage over $s3 sec while the target is grasped. Can move while channeling. Use Illidan's Grasp again to toss the target to a location within $s4 yards
    jagged_spikes                  =  816, -- (205627) While Demon Spikes is active, melee attacks against you cause Physical damage equal to $s1% of the damage taken back to the attacker
    lay_in_wait                    = 5716, -- (1235091) Sigil of Misery has $s1 charges and now lays in wait for up to $s2 sec at your selected location until an enemy approaches
    rain_from_above                = 5521, -- (206803) You fly into the air out of harm's way. While floating, you gain access to Fel Lance allowing you to deal damage to enemies below
    reverse_magic                  = 3429, -- (205604) Removes all harmful magical effects from yourself and all nearby allies within $s1 yards, and sends them back to their original caster if possible
    sigil_mastery                  = 1948, -- (211489) Reduces the cooldown of your Sigils by an additional $s1%
    tormentor                      = 1220, -- (207029) You focus the assault on this target, increasing their damage taken by $s1% for $s2 sec. Each unique player that attacks the target increases the damage taken by an additional $s3%, stacking up to $s4 times. Your melee attacks refresh the duration of Focused Assault
    unending_hatred                = 3727, -- (213480) Taking damage causes you to gain Fury based on the damage dealt
} )

-- Auras
spec:RegisterAuras( {
    -- $w1 Soul Fragments consumed. At $?a212612[$442290s1~][$442290s2~], Reaver's Glaive is available to cast.
    art_of_the_glaive = {
        id = 444661,
        duration = 30.0,
        max_stack = 30,
    },
    -- Damage taken reduced by $s1%.
    blade_ward = {
        id = 442715,
        duration = 5.0,
        max_stack = 1,
    },
    -- Versatility increased by $w1%.
    -- https://wowhead.com/beta/spell=355894
    blind_faith = {
        id = 355894,
        duration = 20,
        max_stack = 1
    },
    -- Taking $w1 Chaos damage every $t1 seconds.  Damage taken from $@auracaster's Immolation Aura increased by $s2%.
    -- https://wowhead.com/beta/spell=391191
    burning_wound = {
        id = 391191,
        duration = 15,
        tick_time = 3,
        max_stack = 1
    },
    calcified_spikes = {
        id = 391171,
        duration = 12,
        max_stack = 1
    },
    -- https://www.wowhead.com/spell=1490
    chaos_brand = {
        id = 1490,
        duration = 3600,
        max_stack = 1,
    },
    -- Talent: Stunned.
    -- https://wowhead.com/beta/spell=179057
    chaos_nova = {
        id = 179057,
        duration = 2,
        type = "Magic",
        max_stack = 1
    },
    -- Talent:
    -- https://wowhead.com/beta/spell=196718
    darkness = {
        id = 196718,
        duration = function() return ( talent.long_night.enabled and 11 or 8 ) + ( talent.cover_of_darkness.enabled and 2 or 0 ) end,
        max_stack = 1
    },
    demon_soul = {
        id = 347765,
        duration = 15,
        max_stack = 1,
    },
    -- Armor increased by ${$W2*$AGI/100}.$?s321028[  Parry chance increased by $w1%.][]
    -- https://wowhead.com/beta/spell=203819
    demon_spikes = {
        id = 203819,
        duration = function() return 8 + talent.extended_spikes.rank end,
        max_stack = 1
    },
    -- https://www.wowhead.com/spell=452416
    -- Demonsurge Damage of your next Demonsurge is increased by 10%.
    demonsurge = {
        id = 452416,
        duration = 12,
        max_stack = 6,
    },
    -- Fake buffs for demonsurge damage procs
    demonsurge_hardcast = {},
    demonsurge_consuming_fire = {},
    demonsurge_fel_desolation = {},
    demonsurge_sigil_of_doom = {},
    demonsurge_soul_sunder = {},
    demonsurge_spirit_burst = {},
    -- Vengeful Retreat may be cast again.
    evasive_action = {
        id = 444929,
        duration = 3.0,
        max_stack = 1,
    },
    feast_of_souls = {
        id = 207693,
        duration = 6,
        max_stack = 1
    },
    -- Talent:
    -- https://wowhead.com/beta/spell=212084
    fel_devastation = {
        id = 212084,
        duration = 2,
        tick_time = 0.2,
        max_stack = 1
    },
    fel_flame_fortification = {
        id = 393009,
        duration = function () return class.auras.immolation_aura.duration end,
        max_stack = 1
    },
    -- Talent: Movement speed increased by $w1%.
    -- https://wowhead.com/beta/spell=389847
    felfire_haste = {
        id = 389847,
        duration = 8,
        max_stack = 1
    },
    -- Talent: Branded, taking $w3 Fire damage every $t3 sec, and dealing $204021s1% less damage to $@auracaster$?s389220[ and taking $w2% more Fire damage from them][].
    -- https://wowhead.com/beta/spell=207744
    fiery_brand = {
        id = 207771,
        duration = 12,
        type = "Magic",
        max_stack = 1,
        copy = "fiery_brand_dot"
    },
    -- Talent: Battling a demon from the Theater of Pain...
    -- https://wowhead.com/beta/spell=391430
    fodder_to_the_flame = {
        id = 391430,
        duration = 25,
        max_stack = 1,
        copy = 329554
    },
    -- Talent: $@auracaster is healed for $w1% of all damage they deal to you.$?$w3!=0[  Dealing $w3% reduced damage to $@auracaster.][]$?$w4!=0[  Suffering $w4% increased damage from $@auracaster.][]
    -- https://wowhead.com/beta/spell=247456
    frailty = {
        id = 247456,
        duration = 5,
        tick_time = 1,
        type = "Magic",
        max_stack = 1
    },
    glaive_flurry = {
        id = 442435,
        duration = 30,
        max_stack = 1
    },
    -- Falling speed reduced.
    -- https://wowhead.com/beta/spell=131347
    glide = {
        id = 131347,
        duration = 3600,
        max_stack = 1
    },
    -- Burning nearby enemies for $258922s1 $@spelldesc395020 damage every $t1 sec.$?a207548[    Movement speed increased by $w4%.][]$?a320331[    Armor increased by $w5%. Attackers suffer $@spelldesc395020 damage.][]
    -- https://wowhead.com/beta/spell=258920
    immolation_aura = {
        id = 258920,
        duration = function () return talent.agonizing_flames.enabled and 9 or 6 end,
        tick_time = 1,
        max_stack = 1
    },
    -- Talent: Incapacitated.
    -- https://wowhead.com/beta/spell=217832
    imprison = {
        id = 217832,
        duration = 60,
        mechanic = "sap",
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Movement speed reduced by $s1%.
    -- https://wowhead.com/beta/spell=213405
    master_of_the_glaive = {
        id = 213405,
        duration = 6,
        mechanic = "snare",
        max_stack = 1
    },
    -- Maximum health increased by $w2%.  Armor increased by $w8%.  $?s235893[Versatility increased by $w5%. ][]$?s263642[Fracture][Shear] generates $w4 additional Fury and one additional Lesser Soul Fragment.
    -- https://wowhead.com/beta/spell=187827
    metamorphosis = {
        id = 187827,
        duration = 15,
        max_stack = 1,
        -- This copy is for SIMC compatability while avoiding managing a virtual buff
        copy = "demonsurge_demonic"
    },
    -- Stunned.
    -- https://wowhead.com/beta/spell=200166
    metamorphosis_stun = {
        id = 200166,
        duration = 3,
        type = "Magic",
        max_stack = 1
    },
    -- Dazed.
    -- https://wowhead.com/beta/spell=247121
    metamorphosis_daze = {
        id = 247121,
        duration = 3,
        type = "Magic",
        max_stack = 1
    },
    -- Agility increased by $w1%.
    monster_rising = {
        id = 452550,
        duration = 3600,
        max_stack = 1
    },
    painbringer = {
        id = 212988,
        duration = 6,
        max_stack = 30
    },
    -- $w3
    pursuit_of_angriness = {
        id = 452404,
        duration = 0.0,
        tick_time = 1.0,
        max_stack = 1,
    },
    reavers_glaive = {
    },
    reavers_mark = {
        id = 442624,
        duration = 20,
        max_stack = function() return set_bonus.tww3 >=4 and 2 or 1 end
    },
    rending_strike = {
        id = 442442,
        duration = 30,
        max_stack = 1
    },
    ruinous_bulwark = {
        id = 326863,
        duration = 10,
        max_stack = 1
    },
    -- Taking $w1 Fire damage every $t1 sec.
    set_fire_to_the_pain = {
        id = 453286,
        duration = 6.0,
        tick_time = 1.0,
        max_stack = 1,
    },
    -- Talent: Movement slowed by $s1%.
    -- https://wowhead.com/beta/spell=204843
    sigil_of_chains = {
        id = 204843,
        duration = function () return 6 + ( 2 * talent.chains_of_anger.rank ) end,
        type = "Magic",
        max_stack = 1
    },
    sigil_of_doom = {
        id = 462030,
        duration = 8,
        max_stack = 1
    },
    sigil_of_doom_active = {
        id = 452490,
        duration = 2,
        max_stack = 1
    },
    -- Talent: Sigil of Flame is active.
    -- https://wowhead.com/beta/spell=204596
    sigil_of_flame_active = {
        id = 204596,
        duration = 2,
        max_stack = 1,
        copy = 389810
    },
    -- Talent: Suffering $w2 $@spelldesc395020 damage every $t2 sec.
    -- https://wowhead.com/beta/spell=204598
    sigil_of_flame = {
        id = 204598,
        duration = function () return 6 + ( 2 * talent.chains_of_anger.rank ) end,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Disoriented.
    -- https://wowhead.com/beta/spell=207685
    sigil_of_misery_debuff = {
        id = 207685,
        duration = function () return 15 + ( 2 * talent.chains_of_anger.rank ) end,
        mechanic = "flee",
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Silenced.
    -- https://wowhead.com/beta/spell=204490
    sigil_of_silence = {
        id = 204490,
        duration = function () return 4 + ( 2 * talent.chains_of_anger.rank ) end,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Absorbs $w1 damage.
    -- https://wowhead.com/beta/spell=263648
    soul_barrier = {
        id = 263648,
        duration = 15,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Suffering $s1 Fire damage every $t1 sec.
    -- TODO: Trigger more Lesser Soul Fragments...
    -- https://wowhead.com/beta/spell=207407
    soul_carver = {
        id = 207407,
        duration = 3,
        tick_time = 1,
        max_stack = 1
    },
    -- Consume to heal for $210042s1% of your maximum health.
    -- https://wowhead.com/beta/spell=203795
    soul_fragment = {
        id = 203795,
        duration = 20,
        max_stack = 5
    },
    soul_fragments = {
        id = 203981,
        duration = 3600,
        max_stack = 5,
    },
    -- Talent: $w1 Soul Fragments consumed. At $u, the damage of your next Soul Cleave is increased by $391172s1%.
    -- https://wowhead.com/beta/spell=391166
    soul_furnace_stack = {
        id = 391166,
        duration = 30,
        max_stack = 9,
        copy = 339424
    },
    soul_furnace = {
        id = 391172,
        duration = 30,
        max_stack = 1,
        copy = "soul_furnace_damage_amp"
    },
    -- Suffering $w1 Chaos damage every $t1 sec.
    -- https://wowhead.com/beta/spell=390181
    soulrend = {
        id = 390181,
        duration = 6,
        tick_time = 2,
        max_stack = 1
    },
    -- Can see invisible and stealthed enemies.  Can see enemies and treasures through physical barriers.
    -- https://wowhead.com/beta/spell=188501
    spectral_sight = {
        id = 188501,
        duration = 10,
        max_stack = 1
    },
    -- Talent:
    -- https://wowhead.com/beta/spell=247454
    spirit_bomb = {
        id = 247454,
        duration = 1.5,
        max_stack = 1
    },
    spirit_of_the_darkness_flame = {
        id = 337542,
        duration = 3600,
        max_stack = 15
    },
    -- Mastery increased by ${$w1*$mas}.1%. ; Generating $453236s1 Fury every $t2 sec.
    student_of_suffering = {
        id = 453239,
        duration = 6,
        max_stack = 1
    },
    -- Talent: Suffering $w1 $@spelldesc395042 damage every $t1 sec.
    -- https://wowhead.com/beta/spell=345335
    the_hunt_dot = {
        id = 370969,
        duration = 6,
        tick_time = 2,
        type = "Magic",
        max_stack = 1,
        copy = 345335
    },
    -- Talent: Marked by the Demon Hunter, converting $?c1[$345422s1%][$345422s2%] of the damage done to healing.
    -- https://wowhead.com/beta/spell=370966
    the_hunt = {
        id = 370966,
        duration = 30,
        max_stack = 1,
        copy = 323802
    },
    the_hunt_root = {
        id = 370970,
        duration = 1.5,
        max_stack = 1,
        copy = 323996
    },
    -- Attack Speed increased by $w1%
    thrill_of_the_fight = {
        id = 442695,
        duration = 20.0,
        max_stack = 1,
        copy = "thrill_of_the_fight_attack_speed"
    },
    thrill_of_the_fight_damage = {
        id = 1227062,
        duration = 10,
        max_stack = 1
    },
    -- Taunted.
    -- https://wowhead.com/beta/spell=185245
    torment = {
        id = 185245,
        duration = 3,
        max_stack = 1
    },
    -- Talent: Movement speed reduced by $s1%.
    -- https://wowhead.com/beta/spell=198813
    vengeful_retreat = {
        id = 198813,
        duration = 3,
        max_stack = 1
    },
    void_reaver = {
        id = 268178,
        duration = 12,
        max_stack = 1,
    },
    -- Your next $?a212612[Chaos Strike]?s263642[Fracture][Shear] will deal $442507s1 additional Physical damage.
    warblades_hunger = {
        id = 442503,
        duration = 30.0,
        max_stack = 1,
    },

    -- PvP Talents
    demonic_trample = {
        id = 205629,
        duration = 3,
        max_stack = 1,
    },
    everlasting_hunt = {
        id = 208769,
        duration = 3,
        max_stack = 1,
    },
    focused_assault = { -- Tormentor.
        id = 206891,
        duration = 6,
        max_stack = 5,
    },
    illidans_grasp = {
        id = 205630,
        duration = 6,
        type = "Magic",
        max_stack = 1,
    },
} )

spec:RegisterGear({
    -- The War Within
    tww3 = {
        items = { 237691, 237689, 237694, 237692, 237690 },
        auras = {
            -- Fel-Scarred
            -- Vengeance
            demon_soul = {
                id = 1238675,
                duration = 15,
                max_stack = 1
            },
        }
    },
    tww2 = {
        items = { 229316, 229314, 229319, 229317, 229315 }
    },
    -- Dragonflight
    tier31 = {
        items = { 207261, 207262, 207263, 207264, 207266, 217228, 217230, 217226, 217227, 217229 },
        auras = {
            fiery_resolve = {
                id = 425653,
                duration = 8,
                max_stack = 5
            }
        }
    },
    tier30 = {
        items = { 202527, 202525, 202524, 202523, 202522 },
        auras = {
            fires_of_fel = {
                id = 409645,
                duration = 6,
                max_stack = 1
            },
            recrimination = {
                id = 409877,
                duration = 30,
                max_stack = 1
            }
        }
    },
    tier29 = {
        items = { 200345, 200347, 200342, 200344, 200346 },
        auras = {
            decrepit_souls = {
                id = 394958,
                duration = 8,
                max_stack = 1
            }
        }
    },
    -- Legacy Tier Sets
    tier21 = { items = { 152121, 152123, 152119, 152118, 152120, 152122 } },
    tier20 = { items = { 147130, 147132, 147128, 147127, 147129, 147131 } },
    tier19 = { items = { 138375, 138376, 138377, 138378, 138379, 138380 } },

    -- Class Hall
    class = { items = { 139715, 139716, 139717, 139718, 139719, 139720, 139721, 139722 } },
    -- Notable Trinkets
    convergence_of_fates = { items = { 140806 } }
} )

-- Local table for real fragment storage (accessible by combat log)
local true_inactive_fragments = {}

-- To support SimC soul_fragments expressions
spec:RegisterStateTable( "soul_fragments", setmetatable( {

    activation_delay = 1.25, -- Maxiumum delay before fragments become active
    virtual_fragments = {}, -- Virtual table

    reset = setfenv( function()
        soul_fragments.active = buff.soul_fragments.stack or 0
        soul_fragments.inactive = #true_inactive_fragments
    end, state ),

    queueFragments = setfenv( function( count, timeStamp, extraTime )
        -- Add individual fragments to REAL table (for combat log events)
        count = count or 1
        extraTime = extraTime or 0
        timeStamp = timeStamp + soul_fragments.activation_delay + extraTime

        for i = 1, count do
            insert( true_inactive_fragments, timeStamp )
            timeStamp = timeStamp + 0.05 -- ensure unique timestamps
        end
    end, state ),

    activateFragment = setfenv( function()
        -- Activate a fragment from REAL storage (convert inactive to active)
        if #true_inactive_fragments > 0 then
            local earliest_index = 1
            local earliest_time = true_inactive_fragments[1]

            for i = 2, #true_inactive_fragments do
                if true_inactive_fragments[i] < earliest_time then
                    earliest_time = true_inactive_fragments[i]
                    earliest_index = i
                end
            end

            remove( true_inactive_fragments, earliest_index )
            addStack( "soul_fragments" )
        end
    end, state ),

    purgeQueued = setfenv( function()
        wipe( true_inactive_fragments )
        soul_fragments.virtual_fragments = {}
    end, state ),

    consumeFragments = setfenv( function( amt )
        if talent.soul_furnace.enabled then
            local overflow = buff.soul_furnace_stack.stack + amt
            if overflow >= 10 then
                applyBuff( "soul_furnace" )
                overflow = overflow - 10
                if overflow > 0 then -- stacks carry over past 10 to start a new stack
                    applyBuff( "soul_furnace_stack", nil, overflow )
                end
            else
                addStack( "soul_furnace_stack", nil, amt )
            end
        end
        -- Reaver Tree
        if talent.art_of_the_glaive.enabled then
            addStack( "art_of_the_glaive", nil, amt )
            if  buff.art_of_the_glaive.stack == 20 then
                removeBuff( "art_of_the_glaive" )
                applyBuff( "reavers_glaive" )
            end
        end
        if talent.warblades_hunger.enabled then
            addStack( "warblades_hunger", nil, amt )
        end

        gainChargeTime( "demon_spikes", ( 0.35 * talent.feed_the_demon.rank * amt ) )
        buff.soul_fragments.count = max( 0, buff.soul_fragments.stack - amt )
    end, state ),

}, {
    __index = function( t, k )
        if k == "total" then
            return ( rawget( t, "active" ) or 0 ) + ( rawget( t, "inactive" ) or 0 )
        elseif k == "active" then
            return rawget( t, "active" ) or 0
        elseif k == "inactive" then
            return rawget( t, "inactive" ) or 0
        elseif k == "time_to_next" then
            -- Find the earliest activation time from real fragments
            local earliest_time = nil
            local current_time = query_time

            for i, activation_time in ipairs( true_inactive_fragments ) do
                -- Convert real time to simulation time
                local sim_activation_time = activation_time - GetTime() + current_time
                if sim_activation_time > current_time then
                    if not earliest_time or sim_activation_time < earliest_time then
                        earliest_time = sim_activation_time
                    end
                end
            end

            return earliest_time and ( earliest_time - current_time ) or 0
        end

        return 0
    end
} ) )

spec:RegisterStateExpr( "last_infernal_strike", function ()
    return action.infernal_strike.lastCast
end )

spec:RegisterStateExpr( "activation_time", function()
    return talent.quickened_sigils.enabled and 1 or 2
end )

-- Variable to track the total bonus timed earned on fiery brand from immolation aura.
local bonus_time_from_immo_aura = 0
-- Variable to track the GUID of the initial target
local initial_fiery_brand_guid = ""

local sigilList = {
    sigil_of_flame = { 204596, 389810, 452490, 469991 },
    sigil_of_misery = { 207684, 389813 },
    sigil_of_spite = { 390163, 389815 },
    sigil_of_silence = { 202137, 389809 },
    sigil_of_chains = { 202138, 389807 }
}

local DemonsurgeHardcast = false

spec:RegisterHook( "COMBAT_LOG_EVENT_UNFILTERED", function( _ , subtype, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName )
    if sourceGUID ~= GUID then return end

    if spellID == 187827 and state.talent.demonic_intensity.enabled then
        if subtype == "SPELL_CAST_SUCCESS" then
            DemonsurgeHardcast = true
        elseif subtype == "SPELL_AURA_REMOVED" then
            DemonsurgeHardcast = false
        end
    end

    if state.talent.charred_flesh.enabled and subtype == "SPELL_DAMAGE" and spellID == 258922 and destGUID == initial_fiery_brand_guid then
        bonus_time_from_immo_aura = bonus_time_from_immo_aura + ( 0.25 * state.talent.charred_flesh.rank )

    elseif subtype == "SPELL_CAST_SUCCESS" then
        if state.talent.charred_flesh.enabled and spellID == 204021 then
            bonus_time_from_immo_aura = 0
            initial_fiery_brand_guid = destGUID
        end

        if spellID == 204255 then
            soul_fragments.activateFragment()
        elseif spellID == 263642 then
            -- Fracture:  Generate 2-3 frags
            local timeStamp = GetTime()
            local metaActive = GetPlayerAuraBySpellID( 187827 )
            local frags = 2 + ( metaActive and 1 or 0 )
            soul_fragments.queueFragments( frags, timeStamp )
        elseif spellID == 203782 then
            -- Shear:  Generate 1-2 frags
            local timeStamp = GetTime()
            local metaActive = GetPlayerAuraBySpellID( 187827 )
            local frags = 1 + ( metaActive and 1 or 0 )
            soul_fragments.queueFragments( frags, timeStamp )
        end

        -- Sigils: Generate 1 frag
        local foundSigil = false
        for _, spellIDs in pairs( sigilList ) do
            for _, id in ipairs( spellIDs ) do
                if spellID == id then
                    foundSigil = true
                    break
                end
            end
            if foundSigil then break end
        end
        if foundSigil then
            local timeStamp = GetTime()
            -- Pass in sigil activation time as additional delay to the spawning
            soul_fragments.queueFragments( 1, timeStamp, state.activation_time )
        end

        -- We consumed or generated a fragment for real, so let's purge the inactive queue.
    elseif spellID == 203981 and soul_fragments.inactive > 0 and ( subtype == "SPELL_AURA_APPLIED" or subtype == "SPELL_AURA_APPLIED_DOSE" ) then
        soul_fragments.inactive = max( 0, soul_fragments.inactive - 1 )
    end
end, false )

-- Abilities that may trigger Demonsurge.
local demonsurge = {
    demonic = { "soul_sunder", "spirit_burst" },
    hardcast = { "consuming_fire", "fel_desolation", "sigil_of_doom" },
}

-- Map old demonsurge names to current ability names due to SimC APL
local demonsurge_spell_map = {
    soul_sunder = "soul_cleave",
    spirit_burst = "spirit_bomb",
    fel_desolation = "fel_devastation",
    sigil_of_doom = "sigil_of_flame"
}

spec:RegisterHook( "reset_precast", function ()
    -- Call the reset function to sync with real game state and process activations
    soul_fragments.reset()

    -- Debug snapshot for soul_fragments
    if Hekili.ActiveDebug then

        local real_times = {}
        for i, activation_time in ipairs( true_inactive_fragments ) do
            insert( real_times, strformat( "%.2fs", activation_time - GetTime() ) )
        end
        local real_str = #real_times > 0 and table.concat( real_times, ", " ) or "none"

        Hekili:Debug( "Soul Fragments - Active: %d, Inactive: %d, Total: %d, Buff Stack: %d, Next: %.2fs, Real: [%s]",
            soul_fragments.active or 0,
            soul_fragments.inactive or 0,
            soul_fragments.total or 0,
            buff.soul_fragments.stack or 0,
            soul_fragments.time_to_next or 0,
            real_str
        )
    end

    if buff.demonic_trample.up then
        setCooldown( "global_cooldown", max( cooldown.global_cooldown.remains, buff.demonic_trample.remains ) )
    end

    if buff.illidans_grasp.up then
        setCooldown( "illidans_grasp", 0 )
    end


    if IsSpellKnownOrOverridesKnown( 442294 ) or IsSpellOverlayed( 442294 ) then
        applyBuff( "reavers_glaive" )
        if Hekili.ActiveDebug then Hekili:Debug( "Applied Reaver's Glaive." ) end
    end

    if talent.demonsurge.enabled and buff.metamorphosis.up then
        local metaRemains = buff.metamorphosis.remains

        for _, name in ipairs( demonsurge.demonic ) do
            local ability_name = demonsurge_spell_map[name] or name
            if class.abilities[ ability_name ] and IsSpellOverlayed( class.abilities[ ability_name ].id ) then
                applyBuff( "demonsurge_" .. name, metaRemains )
            end
        end
        if DemonsurgeHardcast then
            applyBuff( "demonsurge_hardcast", metaRemains )
            for _, name in ipairs( demonsurge.hardcast ) do
                local ability_name = demonsurge_spell_map[name] or name
                if class.abilities[ ability_name ] and IsSpellOverlayed( class.abilities[ ability_name ].id ) then
                    applyBuff( "demonsurge_" .. name, metaRemains )
                end
            end
        end

        if Hekili.ActiveDebug then
            Hekili:Debug( "Demonsurge status:\n" ..
                " - Hardcast " .. ( buff.demonsurge_hardcast.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Demonic " .. ( buff.demonsurge_demonic.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Consuming Fire " .. ( buff.demonsurge_consuming_fire.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Fel Desolation " .. ( buff.demonsurge_fel_desolation.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Sigil of Doom " .. ( buff.demonsurge_sigil_of_doom.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Soul Sunder " .. ( buff.demonsurge_soul_sunder.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Spirit Burst " .. ( buff.demonsurge_spirit_burst.up and "ACTIVE" or "INACTIVE" ) )
            end
        end

    fiery_brand_dot_primary_expires = nil
    fury_spent = nil
end )

spec:RegisterHook( "spend", function( amt, resource )
    if set_bonus.tier31_4pc == 0 or amt < 0 or resource ~= "fury" then return end

    fury_spent = fury_spent + amt
    if fury_spent > 40 then
        reduceCooldown( "sigil_of_flame", floor( fury_spent / 40 ) )
        fury_spent = fury_spent % 40
    end
end )

-- approach that actually calculated time remaining of fiery_brand via combat log. last modified 1/27/2023.
spec:RegisterStateExpr( "fiery_brand_dot_primary_expires", function()
    return action.fiery_brand.lastCast + bonus_time_from_immo_aura + class.auras.fiery_brand.duration
end )

spec:RegisterStateExpr( "fiery_brand_dot_primary_remains", function()
    return max( 0, fiery_brand_dot_primary_expires - query_time )
end )

spec:RegisterStateExpr( "fiery_brand_dot_primary_ticking", function()
    return fiery_brand_dot_primary_remains > 0
end )

local furySpent = 0

local FURY = Enum.PowerType.Fury
local lastFury = -1

spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( event, unit, powerType )
    if powerType == "FURY" and state.set_bonus.tier31_4pc > 0 then
        local current = UnitPower( "player", FURY )

        if current < lastFury - 3 then
            furySpent = ( furySpent + lastFury - current )
        end

        lastFury = current
    end
end )

spec:RegisterStateExpr( "fury_spent", function ()
    if set_bonus.tier31_4pc == 0 then return 0 end
    return furySpent
end )


local TriggerDemonic = setfenv( function()
    local demonicExtension = 7

    if buff.metamorphosis.up then
        buff.metamorphosis.expires = buff.metamorphosis.expires + demonicExtension
        -- Fel-Scarred
        if talent.demonsurge.enabled then
            local metaExpires = buff.metamorphosis.expires

            for _, name in ipairs( demonsurge.demonic ) do
                local aura = buff[ "demonsurge_" .. name ]
                if aura.up then aura.expires = metaExpires end
            end

            if talent.demonic_intensity.enabled and buff.demonsurge_hardcast.up then
                buff.demonsurge_hardcast.expires = metaExpires

                for _, name in ipairs( demonsurge.hardcast ) do
                    local aura = buff[ "demonsurge_" .. name ]
                    if aura.up then aura.expires = metaExpires end
                end
                if set_bonus.tww3 >= 4 then
                    addStack( "demonsurge" )
                    applyBuff( "demon_soul" )
                end
            end
        end
    else
        applyBuff( "metamorphosis", demonicExtension )
        if talent.inner_demon.enabled then applyBuff( "inner_demon" ) end
        -- Fel-Scarred
        if talent.demonsurge.enabled then
            local metaRemains = buff.metamorphosis.remains

            for _, name in ipairs( demonsurge.demonic ) do
                applyBuff( "demonsurge_" .. name, metaRemains )
            end
        end
    end
end, state )

-- Abilities
spec:RegisterAbilities( {
    -- Talent: Demolish the spirit of all those around you, dealing $s1 Fire damage to nearby enemies and extracting up to $s2 Lesser Soul Fragments, drawing them to you for immediate consumption.
    bulk_extraction = {
        id = 320341,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "fire",

        talent = "bulk_extraction",
        startsCombat = true,
        texture = 136194,

        toggle = "cooldowns",

        handler = function ()
        end,
    },

    -- Talent: Unleash an eruption of fel energy, dealing $s2 Chaos damage and stunning all nearby enemies for $d.$?s320412[    Each enemy stunned by Chaos Nova has a $s3% chance to generate a Lesser Soul Fragment.][]
    chaos_nova = {
        id = 179057,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "chromatic",

        spend = 25,
        spendType = "fury",

        talent = "chaos_nova",
        startsCombat = true,
        texture = 135795,

        handler = function ()
            applyDebuff( "target", "chaos_nova" )
        end,
    },

    -- Talent: Consume $m1 beneficial Magic effect removing it from the target$?s320313[ and granting you $s2 Fury][].
    consume_magic = {
        id = 278326,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "chromatic",

        talent = "consume_magic",
        startsCombat = false,

        toggle = "interrupts",
        buff = "dispellable_magic",

        handler = function ()
            removeBuff( "dispellable_magic" )
            if talent.swallowed_anger.enabled then gain( 20, "fury" ) end
        end,
    },

    -- Summons darkness around you in a$?a357419[ 12 yd][n 8 yd] radius, granting friendly targets a $209426s2% chance to avoid all damage from an attack. Lasts $d.; Chance to avoid damage increased by $s3% when not in a raid.
    darkness = {
        id = 196718,
        cast = 0,
        cooldown = function() return talent.pitch_black.enabled and 180 or 300 end,
        gcd = "spell",
        school = "physical",

        talent = "darkness",
        startsCombat = false,
        texture = 1305154,

        toggle = "defensives",

        handler = function ()
            last_darkness = query_time
            applyBuff( "darkness" )
        end,
    },

    -- Surge with fel power, increasing your Armor by ${$203819s2*$AGI/100}$?s321028[, and your Parry chance by $203819s1%, for $203819d][].
    demon_spikes = {
        id = 203720,
        cast = 0,
        charges = 2,
        cooldown = 20,
        recharge = 20,
        hasteCD = true,

        icd = 1.5,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        toggle = "defensives",
        defensive = true,

        handler = function ()
            if talent.calcified_spikes.enabled and buff.demon_spikes.up then applyBuff( "calcified_spikes" ) end
            applyBuff( "demon_spikes", buff.demon_spikes.remains + buff.demon_spikes.duration )
        end,
    },

    demonic_trample = {
        id = 205629,
        cast = 0,
        charges = 2,
        cooldown = 12,
        recharge = 12,
        gcd = "spell",
        icd = 0.8,

        pvptalent = "demonic_trample",
        nobuff = "demonic_trample",

        startsCombat = false,
        texture = 134294,
        nodebuff = "rooted",

        handler = function ()
            spendCharges( "infernal_strike", 1 )
            setCooldown( "global_cooldown", 3 )
            applyBuff( "demonic_trample" )
        end,
    },

    -- Interrupts the enemy's spellcasting and locks them from that school of magic for $d.|cFFFFFFFF$?s183782[    Generates $218903s1 Fury on a successful interrupt.][]|r
    disrupt = {
        id = 183752,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "chromatic",

        startsCombat = true,

        toggle = "interrupts",
        interrupt = true,

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function ()
            if talent.disrupting_fury.enabled then gain( 30, "fury" ) end
            interrupt()
        end,
    },

    -- Talent: Unleash the fel within you, damaging enemies directly in front of you for ${$212105s1*(2/$t1)} Fire damage over $d.$?s320639[ Causing damage also heals you for up to ${$212106s1*(2/$t1)} health.][]
    fel_devastation = {
		id = function() return buff.demonsurge_hardcast.up and 452486 or 212084 end,
        cast = 2,
        channeled = true,
        cooldown = 40,
        fixedCast = true,
        gcd = "spell",
        school = "fire",

        spend = 50,
        spendType = "fury",

        talent = "fel_devastation",
        startsCombat = true,
        texture = function() return buff.demonsurge_hardcast.up and 135798 or 1450143 end,

        start = function ()
            if buff.demonsurge_fel_desolation.up then
                removeBuff( "demonsurge_fel_desolation" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end
            applyBuff( "fel_devastation" )
            if talent.demonic.enabled then TriggerDemonic() end
        end,

        finish = function ()
            if talent.darkglare_boon.enabled then
                gain( 15, "fury" )
                reduceCooldown( "fel_devastation", 6 )
            end
            if talent.ruinous_bulwark.enabled then applyBuff( "ruinous_bulwark" ) end
        end,

        bind = "fel_desolation",
        copy = { 452486, 212084 }
    },

    -- Talent: Charge to your target and deal $213243sw2 $@spelldesc395020 damage.    $?s203513[Shear has a chance to reset the cooldown of Felblade.    |cFFFFFFFFGenerates $213243s3 Fury.|r]?a203555[Demon Blades has a chance to reset the cooldown of Felblade.    |cFFFFFFFFGenerates $213243s3 Fury.|r][Demon's Bite has a chance to reset the cooldown of Felblade.    |cFFFFFFFFGenerates $213243s3 Fury.|r]
    felblade = {
        id = 232893,
        cast = 0,
        cooldown = 15,
        hasteCD = true,
        gcd = "spell",
        school = "physical",

        spend = -40,
        spendType = "fury",

        talent = "felblade",
        startsCombat = true,
        nodebuff = "rooted",

        handler = function ()
            setDistance( 5 )
        end,
    },

    -- Talent: Brand an enemy with a demonic symbol, instantly dealing $sw2 Fire damage$?s320962[ and ${$207771s3*$207744d} Fire damage over $207744d][]. The enemy's damage done to you is reduced by $s1% for $207744d.
    fiery_brand = {
        id = 204021,
        cast = 0,
        charges = function() return talent.down_in_flames.enabled and 2 or nil end,
        cooldown = function() return ( talent.down_in_flames.enabled and 48 or 60 ) + ( conduit.fel_defender.mod * 0.001 ) end,
        recharge = function() return talent.down_in_flames.enabled and ( 48 + ( conduit.fel_defender.mod * 0.001 ) ) or nil end,
        gcd = "spell",
        school = "fire",

        talent = "fiery_brand",
        startsCombat = true,

        readyTime = function ()
            if ( settings.brand_charges or 1 ) == 0 then return end
            return ( ( 1 + ( settings.brand_charges or 1 ) ) - cooldown.fiery_brand.charges_fractional ) * cooldown.fiery_brand.recharge
        end,

        handler = function ()
            applyDebuff( "target", "fiery_brand_dot" )
            fiery_brand_dot_primary_expires = query_time + class.auras.fiery_brand.duration
            removeBuff( "spirit_of_the_darkness_flame" )

            if talent.charred_flesh.enabled then applyBuff( "charred_flesh" ) end
        end,
    },

    illidans_grasp = {
        id = function () return debuff.illidans_grasp.up and 208173 or 205630 end,
        known = 205630,
        cast = 0,
        channeled = true,
        cooldown = function () return buff.illidans_grasp.up and ( 54 + buff.illidans_grasp.remains ) or 0 end,
        gcd = "off",

        pvptalent = "illidans_grasp",
        aura = "illidans_grasp",
        breakable = true,

        startsCombat = true,
        texture = function () return buff.illidans_grasp.up and 252175 or 1380367 end,

        start = function ()
            if buff.illidans_grasp.up then removeBuff( "illidans_grasp" )
            else applyBuff( "illidans_grasp" ) end
        end,

        copy = { 205630, 208173 }
    },

    -- Engulf yourself in flames, $?a320364 [instantly causing $258921s1 $@spelldesc395020 damage to enemies within $258921A1 yards and ][]radiating ${$258922s1*$d} $@spelldesc395020 damage over $d.$?s320374[    |cFFFFFFFFGenerates $<havocTalentFury> Fury over $d.|r][]$?(s212612 & !s320374)[    |cFFFFFFFFGenerates $<havocFury> Fury.|r][]$?s212613[    |cFFFFFFFFGenerates $<vengeFury> Fury over $d.|r][]
    immolation_aura = {
        id = function() return buff.demonsurge_hardcast.up and 452487 or 258920 end,
        flash = { 452487, 258920 },
        cast = 0,
        cooldown = 15,
        hasteCD = true,

        gcd = "spell",
        school = "fire",
        texture = function() return buff.demonsurge_hardcast.up and 135794 or 1344649 end,
        -- nobuff = "demonsurge_hardcast",

        spend = -8,
        spendType = "fury",
        startsCombat = true,

        handler = function ()
            applyBuff( "immolation_aura" )
            if legendary.fel_flame_fortification.enabled then applyBuff( "fel_flame_fortification" ) end
            if pvptalent.cleansed_by_flame.enabled then
                removeDebuff( "player", "reversible_magic" )
            end

            if talent.fallout.enabled then
                addStack( "soul_fragments", nil, active_enemies < 3 and 1 or 2 )
            end

            -- Fel-Scarred
            if buff.demonsurge_consuming_fire.up then
                removeBuff( "demonsurge_consuming_fire" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end

        end,

        tick = function ()
            if talent.charred_flesh.enabled then
                if debuff.fiery_brand.up then applyDebuff( "target", debuff.fiery_brand.remains + 0.25 * talent.charred_flesh.rank ) end
                if debuff.sigil_of_flame.up then applyDebuff( "target", debuff.sigil_of_flame.remains + 0.25 * talent.charred_flesh.rank ) end
            end
        end,

        bind = "consuming_fire",
        copy = "consuming_fire"
    },

    --[[consuming_fire = {
        id = 452487,
        known = 258920,
        cast = 0,
        cooldown = 15,
        hasteCD = true,
        gcd = "spell",
        school = "fire",
        texture = 135794,

        spend = -8,
        spendType = "fury",
        startsCombat = true,
        talent = "demonic_intensity",
        buff = "demonsurge_hardcast",

        handler = function ()
            applyBuff( "immolation_aura" )
            if legendary.fel_flame_fortification.enabled then applyBuff( "fel_flame_fortification" ) end
            if pvptalent.cleansed_by_flame.enabled then
                removeDebuff( "player", "reversible_magic" )
            end

            if talent.fallout.enabled then
                addStack( "soul_fragments", nil, active_enemies < 3 and 1 or 2 )
            end
            if buff.demonsurge_consuming_fire.up then
                removeBuff( "demonsurge_consuming_fire" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end
        end,

        bind = "immolation_aura",
    },--]]

    -- Talent: Imprisons a demon, beast, or humanoid, incapacitating them for $d. Damage will cancel the effect. Limit 1.
    imprison = {
        id = 217832,
        cast = 0,
        cooldown = function () return pvptalent.detainment.enabled and 60 or 45 end,
        gcd = "spell",
        school = "shadow",

        talent = "imprison",
        startsCombat = false,

        handler = function ()
            applyDebuff( "target", "imprison" )
        end,
    },

    -- Leap through the air toward a targeted location, dealing $189112s1 Fire damage to all enemies within $189112a1 yards.
    infernal_strike = {
        id = 189110,
        cast = 0,
        charges = function() return talent.blazing_path.enabled and 2 or nil end,
        cooldown = function() return ( 20 - ( 10 * talent.meteoric_strikes.rank ) ) * ( 1 - 0.1 * talent.erratic_felheart.rank ) end,
        recharge = function() return talent.blazing_path.enabled and ( 20 - ( 10 * talent.meteoric_strikes.rank ) ) * ( 1 - 0.1 * talent.erratic_felheart.rank ) or nil end,

        gcd = "off",
        school = "physical",
        icd = function () return gcd.max + 0.1 end,

        startsCombat = false,
        nodebuff = "rooted",

        readyTime = function ()
            if ( settings.infernal_charges or 1 ) == 0 then return end
            return ( ( 1 + ( settings.infernal_charges or 1 ) ) - cooldown.infernal_strike.charges_fractional ) * cooldown.infernal_strike.recharge
        end,

        handler = function ()
            setDistance( 5 )
            spendCharges( "demonic_trample", 1 )

            if talent.felfire_haste.enabled or conduit.felfire_haste.enabled then applyBuff( "felfire_haste" ) end
        end,
    },

    -- Transform to demon form for $d, increasing current and maximum health by $s2% and Armor by $s8%$?s235893[. Versatility increased by $s5%][]$?s321067[. While transformed, Shear and Fracture generate one additional Lesser Soul Fragment][]$?s321068[ and $s4 additional Fury][].
    metamorphosis = {
        id = 187827,
        cast = 0,
        cooldown = function() return ( 180 - ( 30 * talent.rush_of_chaos.rank) ) end,
        gcd = "off",
        school = "chaos",

        startsCombat = false,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "metamorphosis", buff.metamorphosis.remains + 15 )
            gain( health.max * 0.4, "health" )

            if talent.demonsurge.enabled then
                local metaRemains = buff.metamorphosis.remains

                for _, name in ipairs( demonsurge.demonic ) do
                    applyBuff( "demonsurge_" .. name, metaRemains )
                end

                if talent.violent_transformation.enabled then
                    setCooldown( "sigil_of_flame", 0 )
                    setCooldown( "fel_devastation", 0 )
                end

                if talent.demonic_intensity.enabled then
                    removeBuff( "demonsurge" )
                    applyBuff( "demonsurge_hardcast", metaRemains )

                    for _, name in ipairs( demonsurge.hardcast ) do
                        applyBuff( "demonsurge_" .. name, metaRemains )
                    end
                    if set_bonus.tww3 >= 4 then
                        addStack( "demonsurge" )
                        applyBuff( "demon_soul" )
                    end
                end
            end
        end,
    },

    reverse_magic = {
        id = 205604,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        -- toggle = "cooldowns",
        pvptalent = "reverse_magic",

        startsCombat = false,
        texture = 1380372,

        buff = "reversible_magic",

        handler = function ()
            if debuff.reversible_magic.up then removeDebuff( "player", "reversible_magic" ) end
        end,
    },

    -- Shears an enemy for $s1 Physical damage, and shatters $?a187827[two Lesser Soul Fragments][a Lesser Soul Fragment] from your target.    |cFFFFFFFFGenerates $m2 Fury.|r
    shear = {
        id = function() return talent.fracture.enabled and 263642 or 203782 end,
        cast = 0,
        cooldown = function() return talent.fracture.enabled and ( 4.5 * haste ) or 0 end,
        charges  = function() return talent.fracture.enabled and 2 or nil end,
        recharge = function() return talent.fracture.enabled and ( 4.5 * haste ) or nil end,
        gcd = "spell",
        school = "physical",

        spend = function () return -1 * ( 10 + ( 10 * talent.shear_fury.rank ) + ( 15 * talent.fracture.rank ) + ( buff.metamorphosis.up and 20 or 0 ) ) end,

        startsCombat = true,

        texture = function() return talent.fracture.enabled and 1388065 or 1344648 end,

        handler = function ()
            if buff.rending_strike.up then -- Reaver stuff
                local cleaved = talent.fury_of_the_aldrachi.enabled and buff.glaive_flurry.down
                applyDebuff( "target", "reavers_mark", nil, cleaved and ( set_bonus.tww3 >=4 and 3 or 2 ) or 1 )
                removeBuff( "rending_strike" )
                if talent.thrill_of_the_fight.enabled and cleaved then
                    applyBuff( "thrill_of_the_fight" )
                    applyBuff( "thrill_of_the_fight_damage" )
                end
            end

            -- Legacy
            if buff.recrimination.up then
                applyDebuff( "target", "fiery_brand", 6 )
                removeBuff( "recrimination" )
            end
            local frags = 1 + ( buff.metamorphosis.up and 1 or 0 ) + ( talent.fracture.enabled and 1 or 0 )
            addStack( "soul_fragments", nil, frags )
        end,

        bind = "shear",
        copy = { 263642, 203782 }
    },

    -- Talent: Place a Sigil of Chains at the target location that activates after $d.    All enemies affected by the sigil are pulled to its center and are snared, reducing movement speed by $204843s1% for $204843d.
    sigil_of_chains = {
        id = function() return talent.precise_sigils.enabled and 389807 or 202138 end,
        known = 202138,
        cast = 0,
        cooldown = function () return ( pvptalent.sigil_mastery.enabled and 0.75 or 1 ) * 90 end,
        gcd = "spell",
        school = "physical",

        talent = "sigil_of_chains",
        startsCombat = false,

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_chains.lastCast + activation_time end,
        impact = function ()
            applyDebuff( "target", "sigil_of_chains" )
        end,

        copy = { 202138, 389807 }
    },

    -- Talent: Place a Sigil of Flame at your location that activates after $d.    Deals $204598s1 Fire damage, and an additional $204598o3 Fire damage over $204598d, to all enemies affected by the sigil.    |CFFffffffGenerates $389787s1 Fury.|R
    sigil_of_flame = {
        id = function()
            if buff.demonsurge_hardcast.up then
                return talent.precise_sigils.enabled and 469991 or 452490
            else
                return talent.precise_sigils.enabled and 389810 or 204596
            end
        end,
        known = 204596,
        cast = 0,
        cooldown = function() return ( pvptalent.sigil_of_mastery.enabled and 0.75 or 1 ) * 30 - ( talent.illuminated_sigils.enabled and 5 or 0 ) end,
        charges = function () return talent.illuminated_sigils.enabled and 2 or 1 end,
        recharge = function() return ( pvptalent.sigil_of_mastery.enabled and 0.75 or 1 ) * 30 - ( talent.illuminated_sigils.enabled and 5 or 0 ) end,
        gcd = "spell",
        icd = function() return 0.25 + activation_time end,
        school = function() return buff.demonsurge_hardcast.up and "chaos" or "fire" end,

        spend = -30,
        spendType = "fury",

        startsCombat = false,
        texture = function() return buff.demonsurge_hardcast.up and 1121022 or 1344652 end,

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_flame.lastCast + activation_time end,

        handler = function ()
            if buff.demonsurge_sigil_of_doom.up then
                removeBuff( "demonsurge_sigil_of_doom" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end
            if talent.cycle_of_binding.enabled then
                for sigil, _ in pairs( sigilList ) do
                    reduceCooldown( sigil, 5 )
                end
            end
        end,

        impact = function()
            if buff.demonsurge_hardcast.up then
                applyDebuff( "target", "sigil_of_doom" )
                active_dot.sigil_of_doom = active_enemies
            else
                applyDebuff( "target", "sigil_of_flame" )
                active_dot.sigil_of_flame = active_enemies
            end
            if talent.soul_sigils.enabled then addStack( "soul_fragments", nil, 1 ) end
            if talent.student_of_suffering.enabled then applyBuff( "student_of_suffering" ) end
            if talent.flames_of_fury.enabled then gain( talent.flames_of_fury.rank * active_enemies, "fury" ) end
            if talent.frailty.enabled then
                if talent.soulcrush.enabled and debuff.frailty.up then
                    -- Soulcrush allows for multiple applications of Frailty.
                    applyDebuff( "target", "frailty", nil, debuff.frailty.stack + 1 )
                else
                    applyDebuff( "target", "frailty" )
                end
                active_dot.frailty = active_enemies
            end
        end,

        bind = "sigil_of_doom",
        copy = { 204596, 389810, 452490, 469991, "sigil_of_doom" }
    },


    -- Talent: Place a Sigil of Misery at your location that activates after $d.    Causes all enemies affected by the sigil to cower in fear. Targets are disoriented for $207685d.
    sigil_of_misery = {
        id = function () return talent.precise_sigils.enabled and 389813 or 207684 end,
        known = 207684,
        cast = 0,
        cooldown = function () return ( pvptalent.sigil_mastery.enabled and 0.75 or 1 ) * 120 - ( talent.improved_sigil_of_misery.enabled and 30 or 0 ) end,
        gcd = "spell",
        school = "physical",

        talent = "sigil_of_misery",
        startsCombat = false,

        toggle = "interrupts",

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_misery.lastCast + activation_time end,

        impact = function ()
            applyDebuff( "target", "sigil_of_misery_debuff" )
        end,

        copy = { 207684, 389813 }
    },

    sigil_of_silence = {
        id = function () return talent.precise_sigils.enabled and 389809 or 202137 end,
        known = 202137,
        cast = 0,
        cooldown = function () return ( pvptalent.sigil_mastery.enabled and 0.75 or 1 ) * 60 end,
        gcd = "spell",

        startsCombat = true,
        texture = 1418288,

        toggle = "interrupts",

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_silence.lastCast + activation_time end,

        usable = function () return debuff.casting.remains > activation_time end,

        impact = function()
            interrupt()
            applyDebuff( "target", "sigil_of_silence" )
        end,

        copy = { 202137, 389809 },

        auras = {
            -- Conduit, applies after SoS expires.
            demon_muzzle = {
                id = 339589,
                duration = 6,
                max_stack = 1
            }
        }
    },

    -- Place a demonic sigil at the target location that activates after $d.; Detonates to deal $389860s1 Chaos damage and shatter up to $s3 Lesser Soul Fragments from enemies affected by the sigil. Deals reduced damage beyond $s1 targets.
    sigil_of_spite = {
        id = function () return talent.precise_sigils.enabled and 389815 or 390163 end,
        known = 390163,
        cast = 0.0,
        cooldown = function () return ( pvptalent.sigil_mastery.enabled and 0.75 or 1 ) * 60 end,
        gcd = "spell",

        talent = "sigil_of_spite",
        startsCombat = false,

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_spite.lastCast + activation_time end,

        impact = function()
            addStack( "soul_fragments", nil, talent.soul_sigils.enabled and 4 or 3 )
        end,

        copy = { 390163, 389815 }
    },

    -- Talent: Shield yourself for $d, absorbing $<baseAbsorb> damage.    Consumes all Soul Fragments within 25 yds to add $<fragmentAbsorb> to the shield per fragment.
    soul_barrier = {
        id = 263648,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "shadow",

        talent = "soul_barrier",
        startsCombat = false,


        toggle = "defensives",

        handler = function ()

            soul_fragments.consumeFragments( buff.soul_fragments.stack )
            applyBuff( "soul_barrier" )

        end,
    },

    -- Talent: Carve into the soul of your target, dealing ${$s2+$214743s1} Fire damage and an additional $o1 Fire damage over $d.  Immediately shatters $s3 Lesser Soul Fragments from the target and $s4 additional Lesser Soul Fragment every $t1 sec.
    soul_carver = {
        id = 207407,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "fire",

        talent = "soul_carver",
        startsCombat = true,

        handler = function ()
            addStack( "soul_fragments", nil, 3 )
            applyBuff( "soul_carver" )
        end,
    },

    -- Viciously strike up to $228478s2 enemies in front of you for $228478s1 Physical damage and heal yourself for $s4.    Consumes up to $s3 available Soul Fragments$?s321021[ and heals you for an additional $s5 for each Soul Fragment consumed][].
    soul_cleave = {
		id = function() return buff.demonsurge_demonic.up and 452436 or 228477 end,
        known = 228477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 30,
        spendType = "fury",

        startsCombat = true,
        texture = function() return buff.demonsurge_demonic.up and 1355117 or 1344653 end,

        handler = function ()
            removeBuff( "soul_furnace" )
            if buff.demonsurge_soul_sunder.up then
                removeBuff( "demonsurge_soul_sunder" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end

            --
            if buff.glaive_flurry.up then -- Reaver stuff
                removeBuff( "glaive_flurry" )
                if talent.thrill_of_the_fight.enabled and buff.rending_strike.down then
                    applyBuff( "thrill_of_the_fight" )
                    applyBuff( "thrill_of_the_fight_damage" )
                end
            end

            if talent.feast_of_souls.enabled then applyBuff( "feast_of_souls" ) end
            if talent.soulcrush.enabled then
                if debuff.frailty.up then
                    -- Soulcrush allows for multiple applications of Frailty.
                    applyDebuff( "target", "frailty", 8, debuff.frailty.stack + 1 )
                else
                    applyDebuff( "target", "frailty", 8 )
                end
            end
            if talent.void_reaver.enabled then active_dot.frailty = true_active_enemies end

            soul_fragments.consumeFragments( min( 2, buff.soul_fragments.stack ) )

            if legendary.fiery_soul.enabled then reduceCooldown( "fiery_brand", 2 * min( 2, buff.soul_fragments.stack ) ) end
        end,

        bind = "soul_cleave",
        copy = { 228477, 452436 },
    },

    -- Allows you to see enemies and treasures through physical barriers, as well as enemies that are stealthed and invisible. Lasts $d.    Attacking or taking damage disrupts the sight.
    spectral_sight = {
        id = 188501,
        cast = 0,
        cooldown = function() return 30 - ( 5 * talent.lost_in_darkness.rank ) end,
        gcd = "spell",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyBuff( "spectral_sight" )
        end,
    },

    -- Talent: Consume up to $s2 available Soul Fragments then explode, damaging nearby enemies for $247455s1 Fire damage per fragment consumed, and afflicting them with Frailty for $247456d, causing you to heal for $247456s1% of damage you deal to them. Deals reduced damage beyond $s3 targets.
    spirit_bomb = {
		id = function() return talent.demonsurge.enabled and buff.metamorphosis.up and 452437 or 247454 end,
        known = 247454,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "fire",

        spend = 40,
        spendType = "fury",

        talent = "spirit_bomb",
        startsCombat = false,
        buff = function() if soul_fragments.inactive == 0 then return "soul_fragments" end end,

        handler = function ()
            if buff.demonsurge_spirit_burst.up then
                removeBuff( "demonsurge_spirit_burst" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end
            if talent.soulcrush.enabled and debuff.frailty.up then
                -- Soulcrush allows for multiple applications of Frailty.
                applyDebuff( "target", "frailty", nil, debuff.frailty.stack + 1 )
            else
                applyDebuff( "target", "frailty" )
            end
            active_dot.frailty = active_enemies
            removeBuff( "soul_furnace" )
            soul_fragments.consumeFragments( min( 5, buff.soul_fragments.stack ) )
        end,


        bind = "spirit_bomb",
        copy = { 247454, 452437 }
    },

    -- Talent / Covenant (Night Fae): Charge to your target, striking them for $370966s1 $@spelldesc395042 damage, rooting them in place for $370970d and inflicting $370969o1 $@spelldesc395042 damage over $370969d to up to $370967s2 enemies in your path.     The pursuit invigorates your soul, healing you for $?c1[$370968s1%][$370968s2%] of the damage you deal to your Hunt target for $370966d.
    the_hunt = {
        id = function() return talent.the_hunt.enabled and 370965 or 323639 end,
        cast = 1,
        cooldown = function() return talent.the_hunt.enabled and 90 or 180 end,
        gcd = "spell",
        school = "nature",

        startsCombat = true,
        toggle = "cooldowns",
        nodebuff = "rooted",

        handler = function ()
            applyDebuff( "target", "the_hunt" )
            applyDebuff( "target", "the_hunt_dot" )
            setDistance( 5 )

            if legendary.blazing_slaughter.enabled then
                applyBuff( "immolation_aura" )
                applyBuff( "blazing_slaughter" )
            end
            -- Hero Talents
            if talent.art_of_the_glaive.enabled then applyBuff( "reavers_glaive" ) end

        end,

        copy = { 370965, 323639 }
    },

    reavers_glaive = {
        id = 442294,
        cast = 0,
        charges = function() return 1 + talent.champion_of_the_glaive.rank + talent.master_of_the_glaive.rank end,
        cooldown = function() return talent.perfectly_balanced_glaive.enabled and 3 or 9 end,
        recharge = function() if ( talent.champion_of_the_glaive.rank + talent.master_of_the_glaive.rank ) > 0 then
            return ( talent.perfectly_balanced_glaive.enabled and 3 or 9 ) end
            end,
        gcd = "spell",
        school = "physical",
        known = 442290,

        spend = function() return talent.keen_engagement.enabled and -20 or nil end,
        spendType = function() return talent.keen_engagement.enabled and "fury" or nil end,

        startsCombat = true,
        buff = "reavers_glaive",

        handler = function ()
            removeBuff( "reavers_glaive" )
            if talent.master_of_the_glaive.enabled then applyDebuff( "target", "master_of_the_glaive" ) end
            applyBuff( "rending_strike" )
            applyBuff( "glaive_flurry" )
        end,

        bind = "throw_glaive"
    },

    -- Throw a demonic glaive at the target, dealing $337819s1 Physical damage. The glaive can ricochet to $?$s320386[${$337819x1-1} additional enemies][an additional enemy] within 10 yards.
    throw_glaive = {
        id = 204157,
        cast = 0,
        charges = function() return 1 + talent.champion_of_the_glaive.rank + talent.master_of_the_glaive.rank end,
        cooldown = function() return talent.perfectly_balanced_glaive.enabled and 3 or 9 end,
        recharge = function() if ( talent.champion_of_the_glaive.rank + talent.master_of_the_glaive.rank ) > 0 then
            return ( talent.perfectly_balanced_glaive.enabled and 3 or 9 ) end
            end,
        gcd = "spell",
        school = "physical",

        -- spend = function() return talent.furious_throws.enabled and 25 or nil end,
        -- spendType = function() return talent.furious_throws.enabled and "fury" or nil end,

        startsCombat = true,
        nobuff = "reavers_glaive",

        handler = function ()
            if talent.master_of_the_glaive.enabled then applyDebuff( "target", "master_of_the_glaive" ) end
            if set_bonus.tier31_4pc > 0 then reduceCooldown( "the_hunt", 2 ) end
        end,

        bind = "reavers_glaive"
    },

    -- Taunts the target to attack you.
    torment = {
        id = 185245,
        cast = 0,
        cooldown = 8,
        gcd = "off",
        school = "shadow",

        startsCombat = false,
        nopvptalent = "tormentor",

        handler = function ()
            applyDebuff( "target", "torment" )
        end,
    },

    tormentor = {
        id = 207029,
        cast = 0,
        cooldown = 20,
        gcd = "spell",

        startsCombat = true,
        texture = 1344654,

        pvptalent = "tormentor",

        handler = function ()
            applyDebuff( "target", "focused_assault" )
        end,
    },

    -- Talent: Remove all snares and vault away. Nearby enemies take $198813s2 Physical damage$?s320635[ and have their movement speed reduced by $198813s1% for $198813d][].$?a203551[    |cFFFFFFFFGenerates ${($203650s1/5)*$203650d} Fury over $203650d if you damage an enemy.|r][]
    vengeful_retreat = {
        id = 198793,
        cast = 0,
        cooldown = 25,
        gcd = "spell",

        startsCombat = true,
        nodebuff = "rooted",
        talent = "vengeful_retreat",

        readyTime = function ()
            if settings.recommend_movement then return 0 end
            return 3600
        end,

        handler = function ()
            if talent.evasive_action.enabled and buff.evasive_action.down then
                applyBuff( "evasive_action" )
                setCooldown( "vengeful_retreat", 0 )
            end
            if talent.vengeful_bonds.enabled and action.chaos_strike.in_range then -- 20231116: and target.within8 then
                applyDebuff( "target", "vengeful_retreat" )
            end

            if talent.unhindered_assault.enabled then setCooldown( "felblade", 0 ) end
            if pvptalent.glimpse.enabled then applyBuff( "glimpse" ) end
        end,
    }
} )

spec:RegisterRanges( "disrupt", "fiery_brand", "torment", "throw_glaive", "the_hunt" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    potion = "tempered_potion",

    package = "Vengeance",
} )


spec:RegisterSetting( "infernal_charges", 1, {
    name = strformat( "Reserve %s Charges", Hekili:GetSpellLinkWithTexture( 189110 ) ),
    desc = strformat( "If set above zero, %s will not be recommended if it would leave you with fewer charges.", Hekili:GetSpellLinkWithTexture( 189110 ) ),
    type = "range",
    min = 0,
    max = 2,
    step = 0.1,
    width = "full"
} )


spec:RegisterSetting( "brand_charges", 0, {
    name = strformat( "Reserve %s Charges", Hekili:GetSpellLinkWithTexture( spec.abilities.fiery_brand.id ) ),
    desc = strformat( "If set above zero, %s will not be recommended if it would leave you with fewer charges.", Hekili:GetSpellLinkWithTexture( spec.abilities.fiery_brand.id ) ),
    type = "range",
    min = 0,
    max = 2,
    step = 0.1,
    width = "full"
} )

spec:RegisterPack( "Vengeance", 20250913, [[Hekili:T3ZFVnoUX(zjO45vkjRxBL4D37qCkU39ExXD461IM(E)PLLTLtewBlxj5KBbc8N9oKu)GKAgskBNDZ2wG3R3DMudNz48BoKzYWj)9j3TiQiEYVfmiy0GVB4v9hE9OrdVEYDfFEB8K72gn)tr3d)lBIwd)V))XBUpoAZC(iFEvA0cgeYt3LX(P)WFy)0hkk2M)9V7D3Nu8WUz9NNU(D5jR3TkQijDZ8SOLfS)75VB2Q0zVR4H4NIYEcMAYM39dZzt5VMLKMLu85FnjVi)DlIxgTBvb8pxNU5HDBkIZcFSch6Za0K7MTlzvXpVzYmuszqaGFBJNp53g9XHtU7HKflIfZnoh(y2CF7Gp(2GHF)(P)VlxMmpjEd8)NV)x2)lvdoKn4pVjPijA1(P)WF9xbQplDzYQsA()BBErwC06V)lp5V)xyiWD1lXpYwI9t)X01RtG)5DFEZCaRE)OfFy07NjM8)dWKGFRH4yKAeF1Z7VnlgW5zrfxm(DpgLLenBv8LS9(X5jBUFvCyru29Xfx(y0QDXJzF1JXHXBIxdSSXdDcoRJwTkmkngfg3ooON6VCZ4rUa2zj3BaOV3fquKLS5tXfHddNTB5Y8sqv(R9h2)HO8WD5X8rF(zp1by)y)O7twbBEp)mYyRJYHTp8XEmolh2(i)2hyFl6iZbHf)UqCbOexafXfyG4cmqCbwiUasIlWjIlkBE0gqAmnllEtb(CYtamomDz4Yvah4YKLJFiolneuvJ7hTArw08hscb9wabbkUzSLXRYNhbaErVIOva47NxSdSAuWGvoGyXaQEpbILSEDQqvmmAxwKKUfm4IK8SDBlu(jMQDy(2KpfNFjBdiD5YW7NVy8qgcFgNpipN(722ZRiAZNauayAjRJVzKVmav323SBn8HrpTH9tHGH6v5xMUDCwCoOexAEz8Go)9RJ(9sjioAwXMGHd5C98EZttxTi9Pn9v3fa0)iwSaPfBjS)vSllUzLQ(L(ZFGzKkpK)dWkfT62Xd7j4LRJlIwNMT9H08K8JdBU6yWMtdYeTyb1(aibdc298A2iA(1(zXRJs2KFl(OlabxgA82R8veTs2aI(a(hcU7azrvXv5joNBIN)FgUc8KjOHOSlzF48IszBmno7qbSDjdfCG0OBgLbqIHOjfXRVmFvArLrpbs0ytf2bksxZOiy1U)HI8WfXpMYGspVZQ2n6R5KamCqnuppp0nzF4BqhOr2rDKYnRBgoG9PMN0Tn0t9eR2o9Xq2s)b9Am)w)DvRR5v03xsiXa7oqHDh0r2Dan7o41a7oWr29qn29Wtj7w4OhNPY4(C2qYMnquKGdaWJCmlmsjZoc4Tv8bTCgjyJG)2fGVNsBam(i)NVFvelIRLR2LL9zbBhCl(i7RbIu4LnpumlrCOkRjUUE8VxWn4KFIxELLwHnt5cM0sTagGThgNgIKjcN3DgbYFgk2dmiipJvpf95CigEWYmer)kgnSFAYY9t)BcWadXHd8J5BEdeTp8HtJ2Sy)0)KGoN(tCaYgxdFfw75G0e2rJC)8sDeJVWTWSOSybELSz)urke7NwMdb8dBJzFLkGwMKLdedKCe8jpb)aePhqkLUtnti16BkzR0RZK3DceRf5KMTF69qwfGgoJ9UJXCxY(X41BtFkM57rLA0W2hIbNGirn81dtoZrur5Rv1Noe5BfWbB1HSSBLbK8cWJ5L)7rz8GWzFq5qGg38pDbxmaiH7xd0cZXcqv(3emqxnnbssjCwgiRkVlW)vii7K84ENTiT6x4ZRFrYCwS2OYD8WLu4IsGILffYcqaFDJ61HndH9xel05QtTamoWYTGPxpnDdtAauht3b7(ZIz6oLcgPz5cdg)eyDnDxH4deiLuOwIfulXfz(t5xRo)z7w9PqWaDzuTS5Z(3KZ6(Qoj(BXeRAEeCgYFgK5HOR3CFC)9t)lBwb)NBZssb7kSfsq6rZ4eErkZoYw(8zrJZ(aqkk7jylbmenhwMDRzgFafPlftp6X0Kf8VAlxZJnKReKyw95JJNaq)r6WABcKUB4mirsmE5WGEAc5IzC74RPnj6i6AwsOTRUzRIwO)r8YsTew5SywTWkKwMDBEizZcMjPWO8CwgNT0)ZsFc35mPDk5y8l9(2Mj2K9C(oyliSA4DGhgUrLA)fGpgyu(ap)mfJgpsYQ428yXAazhEEGsiAsiNQVQwihp75Dmofh3oZc2FSyJIbgEawv845FgWs2qZs42ZLddw9ZQd29glbkFXWpc4rppmd13moONfA1a)S2gmfOptkqqvS32QIUOuQ8hiLHTgvQyoic)8ZMfJ6ejC0RvRvle49BVGoLcPTgjFIKGPDf9AYu8bq8dqiyS0SW6kY1JycLv0JAyWjnjs4qqeEEmNfxud7Aia2)4bcbJgcoP9z21h4tzhc7xbumDtltuCPnWcLFvXZ1IYy8aaNSKVRx8VhpFxbe0CY64lk9GPLytFL5OyJrcDLw4Wzq4zHZIbMACiBDBRjxZx1YHIzr6RgF0Ui4RaZMdHv4Sthn3Zt3j7ZpBjqMBgI5DPMxPAG2aJYsvw47TVQ5bM8Y0muqF9W6P1fQ9aC2RrTakxiNWTINFURuUv2zNPh1kvP9rpfLuCzE88Xd6lQp2xvI)qeDVfq9p4Sfzl651b22feFKHDn10cKMw7JhHDsHHBNxWotK86JN2RI8vpcQQjFrv(5SSCydVfm2C(799)VgoyGuoymFPQG42bvNm4J8mLwfl(9zRstxyerRiX84)Xow1x5osvX6Gl8coV0ZQ)HbSMJfQeoubQ0CAvsvKqjQXJDvPphqjR(AJvfrsljiLL8Laj1s9vfl1h8eIM6QgQsedoyy0qTb9hD(sq8mR8ysWos7A)T)rZKKVVK8ekGI5Nt5IEoSwdvQuVQKGBI)Mj8RgW0NQlfhdS58faMT)5LQ4LLzHtxibT1fXYtbo)rJcLUHhNa0iqrIHanCtyXiegEcW1paY3n(zlTWF6WFAZ99EXjTa52Eyru2NaxIq2uZsz5Jju0mUkqehqUWHG704CwwULgxswE58ui(B23H6CGOs1voxRzBkN1Y5J8VqAOQM9s9NlBwRZV2xaSW4v5NkiAoobraySYdsZeKlIOGwjkiydsPZHLOkZgVBqiEaHhdwvg74PfPs3eZSm3j8cntTMWbrALf)tcAxfz9)rqVElKXp60ENds6A8yN3E0t(5yWlez9tbA9vrA)qrCwPs4PkHKdrx)YgNnLPmjRoixZVtzIeoGgArGjJjNtKCNijxJl8I0nfHYjTISFJEKKTQqoSylMhXRoEjIBTg6oEOnq28Djp6Gb8sgup3JT(d(QgSA2EvljqBm)QV(yU5qUmuBAd69mIpmzJqiRQ7PlL1UL1tOHL)hSI(I2WNOAil3TIDIPIVGlwFdpV0QY)klW7tcApVHVfzO3o03)C0LTUf1UzSLUnJqkabwwbLXTfLtFXYErYQv7wNSjQiErz3gxzk(iypAMrQ5q32bgKnGzbwUZGk1NE9XJimpCGCjcO5oFQSWdM8NJuAIsofzvjQSHBSSgEx)2YL4FSdcNmEt9gHQPvZEQ1pusdusu(8YUVsC4OLbciVwMOO2f50jsXDSV(izReejLu7XTd6f48Q(QQ9UnfJaDVi3QzpK(QtAJk)vQVWP3N(A1x4VY3N(k1q5Q7thFdLZHhwRfYuXV2(8oJIFbSB6Yg37S669k6DXETtFt7AgE74RiLu6AWPSMHWdVVXBdlavAdQQ6b5ZpA5dqawJZI04mgCaAORyOgQ26U9f2ca6vfgIwu1hCJ8qneJFsnwzKhT0m069NsriKMTHOHG9qtNOhwIeo3qn64i11MkSmzcgIVKPlhwzGiqpiecqug1P46xfwP)RlxEj1aMnE61kZzLMldP5ZOBrqAAqbNuUizDwhZP1t(iT5s)gzbKr(YlCGT4IVzSuw4okwuxdg1t(c3bwtzRulDdyIYaMByWgpJTLn0AhwBDdRg1wDLc01FL6RgpYUZQcTKZ(w(0QBARj0P63ZkbR2RDvh2FpwDrUrTLi4grj6JkvJlDOY2(GRUZA7suYIJsHP9BUkdYoqn0YtE4vf9QBgpItK3o(AEWqyZcmFkMYWriXM81P)7qzwEc08Jd6StDckhuGRt6ri(ZZ3PpS19jeoHAVUJfnsVoit07m7gyKTV0nSHjV8fezuBijCPAjF)6feUB0gNtFKiSDU3XTaQg(42zUEWR0aEBXC4nNxtuhvYrLD52LT)PEV2jrY8lrx)YJLYagGTwvFLjrbgxcCQYE2Bky2KnRh5UcJ1lAuPtAQg8Rkw1lmE9Cj(cmF)sdRMscXKWVncOGrVtEvMuJNBQfsvxwMnuhKLzUGsVcHFAy3mehQoDvg6uklSvblJiFCea7EHGpt9Dn1oZvH9m2YLjxDbQ)S2BgePfGyU1iiv02GW7650rac2WPJJuoEx9vKS3SRwEL4X5ixt(xVyivR6ayO8V4HZ1dPUa0li5Ly0oMzS0iE4LBNzAgFe8WKfdPw19fPPRBy5gk6UVb5nsgnEHEOXntOnxuX0XFye97cYBsO0WjeCrvrKQBKAZQO6A9OTbZnSseQnci5ox0Imb49Xk37GJ2h(MiJ0w7zejNQMQevi42kQdlMhQKj9Vz879RtN0q6OUiXvNozxt1ZL4g7EYEgWyhsgX5ALyrvGEITJXcxUW1B7SnbbPK1qIm(44wD5zAqANUSt88XE9cQp60Mg6Xnta1PT0vXmK6NQ35rhhzAlGJoLF2HsMedvLQZ3wmbtKIdusBbrflG8Nadx1opIkKCiACNAng8uyTqZ0eN8TySK52zjvlbCODDeDog(wBXtUJ9q5aaP(DVnyYDpfLTb2iZNC3F)b2Zd16TPzfLVpqVzz(B2pnlgIzI)ibLNYE3tI2vKUMfeE1lQsE)9)YVMWEBzyp(T)y6gyz4dNUnwu70CXJ60BoKBzx19wO6229gXtUYrdR3XGvnMFLgQ)gx6gKkuPAUfwMS3WF33LvS1X5JSqyZ5Lf(2HC7g)OfGrNIB49Hb9g4gqc3oSdBzYQuc9kAFhaFoVSW3oKB3YiMeDO2HpTqVpRcpigVQBtGUzd7AsKt(DpgbX0gwHKnduUpUY3mzcaRnLtlWpcSU81C2ew3mLtlWpcS(XM3zAtyU60o9lYrqb8xcBt4E1eoLa(iWxMBztOB54NqWsHSJinAAu)U1WDaOgvbrNYPf4hbwtPcIoLtlWpcS2KQh50o9lYrqb4QHit4uc4JaFrveBp(jeSTrwEmaltxTk9Pe2RWilY)C27cl)HLnNTgSSqkyttK8W(PSZ8z)0zS39rX82KYdGy3gLzVybBYlIkIMfLh)9qehtFle6aGDebFeL9Mof1Xx80po1zh8cdERa(WYoWrS(WaEny)IN5XPoXGxyWBfWhwIboI1hgW7Zu8)zUopdAFNQjfMI9K74)BS)QhTK9)(B8)ekvwbIj)3tUlD7K7YJlMCN4lNCxvfIy)BR2b)dVkOsvLJ9tVaOY9tnuRJ9tpF)03VFQp))7DGq(GbtUJbGyy1elo6lx0(P3UF6G9t7vdEKN0IQvHJ8HSdpxaBgYnPyYVf0zAoOIMc4yEzn(aKxEjwI98BWwVRqwpW6TH1RCbKzjif(THB2J9eaxkmOEdMDcbV(uGG1iGMyb71t)5NLqqTXlfE3p9M9tRlhjoQ6cTm6KslTFqL0igIhoLtf18(olQoadU6xCzgO)qNzub9hXf)5VknC1bpwyklnFw6Gk7F0gVqyjarC30RZexS3rmaSWi24i7kacLzmo3h7mN7QbQgqASokAhjowWoiGAsZNpVs7GL3XhnwK3PqNQdK931zY(JoPt5oY6kMoCqNr1acjBsK9qeQTarqi1zkeZVTzk8dLAVnh5tT)6xEk3UZAU28jKbH5K3IiqacgJ)Ev5mwG56NFbOXXJkyMR9ic1Labion4sYKFtQ52oEe9mt5cdJ4BGcdwntR6b9HEkLh2iFcxxAzPkMXVelhJJJflJdC8MgpgZluZzcllb0WohutPODEfi6owM003Dz4nwClDcV5hB7jf5595Jl4orukDa3lBBGJd99y10aJcUqIaqEqJ4Yw2PsSaMCGkZ1FIK(pkZoTCmwowKwoWYLAMHJtIYrTzT9xgMJfSu3W8Vy6ZTX(aS4N6i2)6tJgHo7E1pusVI12lnxJuoe7EyhLftrwlxUxw7I1chQback39YtGx)hzSUo7fYx4mli1b6gxVvOAf9TAxBXsNVkSt8l1CllTn8y8orMNgJNunIagXvC5rr2QNvfKnlorvbzQijRLMhgmG)VZsK9mvZNsQEIXXgHBsrmmTPHRRklxJfFD(JE)4YHyvEdO9fhgxj4BuUct88aJwZ0dHawYhPY3zjCJLEeQ9vfYg48JLMcXUtZED1ntHt1YxvLQn52VYwLBd0MGA)mXjWQ7BEQ4475Qwq8DCjfcod5N(fXKFlFCXg45wzy(UYZyschySVTEkpq2(BF3IWfbOQcudfDRnQr2J7lg3Me98DadR43hyu4yppkFXy5eUkEvX0jDNjy7hyK4yV1nDSmVuXgAOsUYUJSwyypUX93wxrw9lJLsnzfmJdm4E9x2hegH2LVdNhyNYPFn8oesUj2x2HzrKBGHWf9QxiA1lXr6j8mWrWGUHGO846UTKJ46b7xHVLNO6q5TdiocN6GbP4xQdTO8dREAZQ3uONqTg(bfIQSNsAaCMfy0ZUb4ByNtRIFzlFWTkCXwNXUmOAXCcKyogAObowzdp8BcE7o2B3N0EotWqpNnnbJakbdtD)GjbJaBcgb)7KGbsZxyuWyiMGr7MH44emc4cg6zgxlyGVN3(OEA)0co5oHDkkqWww9CFL8suzG86gKr74s4qqp9ef5x69NYTBtNrALitJn9YNOqvd5Kv6HpSOoAnhRjlqNRCsA37atUZxwK6SoUca6JVavvDxwqsIbDOkTM3B1t4q12K94PQqWAIrpSeZtOXNAnwQkKWrs9O0vqslaUABOoXtIerjHuj1FKekBJZ8mkdzUYaIb2HE0ZnSJsvbT68ZP5bs(qmw5Vs(rJkjEDdeMYjtV3xtg3uTk0jzP5YPx9aKBOxLxUrUPSGbnWr)Lpr0UAvfpP(DNHTgxRhhQlf6ZbFDETNI6D9wWMSwsmFtuv99SLazvP7YSvzeTEmSUq0gRUPaty9bOBBckRahL0JEsrv3bUnzgOsfw0EwQSc24Hv1vFlBfTz08krZjnD))nKMdX4CJ8XpOwHBj3egPEltrp(lCbCDPxIzPk)6ihRMS4SlECl1Xiv(cliZaztIo0ep1TA8NqeoXQwNq1MlS9tjcYN4RgwRLs5R(Txi3)NC4iQznm3rduTkwEpP50nTBBhTWB7WFioQ4kK0tZvcASzkoa0oB3M4NSeD3z4rqkENXAqfYd27kHUZijElVc8kzyG)11EnB(SHJudZV2lDJGcF)HoIff2M(R6ulVWuYVs1J3PuKagXWpQgvPB7FEYu)hhC0b1AKHxA2vPyn6VgmymFfEdN)thIeEa)9ocnI6i0D1caIBfjIPzNGtj0b)GUh8QLqgrhHfLncTOLBFASQAFIFKTu0X1qU7)cs40H0qTd(cImgdcXtY7Z1dKSU2PeCF1LcnHt0r6vgPMNjEkrA3PeLV7ikAt)RlBZAT(qXZQhHkxXtmCrgg(k53qStW3oPJfu(vXPY9pHmHX6HCaMIOdeGIu0edza5JQHc38oXQgoCrt2Di3flTK7mLTPnbudnY21MKBS2(ggTDrBh1HKu8CjpLtjURkhy0S7RM4bPJklGpfRSpZbLrYdSTUwZbW58p1ItN2KHjt(2qx3XMknCARowz5OLpsr(h3sxNnm5cP1n0PI8lKt93OLlQ(qOUSJ3WVuhvlGA5LUt6HvMTignPyliAHd(tqfsfgpPkzRHQIYqDnkQEUBlpbjzVd)Msbv0kRSUFevoNDVjoBR8k9WXKJS18wIsHr6Da2PVsYANHkLHRVqBb3K(IooRvaUQ3B6Vq0tT9gdNjOBTwHn3v9ipWfsrWkZXvdRFAvQcZNKZTQrdMOtzKdH12mP9tvEANIfK8rUUAhUd9stRGoAXrTAL3kpYknzDcvY1M7DQot8MiB6Y)yxdZRlDlK4ANulQFUA1CnIJ0f2Hi86BKpxBT5u9YBl8ZeiKBneZKzBWTUXR)Bsz1BDpyjct3u1snxmlRXpPK6TNHOYVOY(ptS49QuzvbUTg6mDfSBDJxrnWEKvnU7L84yRBSP8tAD9ADOSHUhQVAUSdvcgtxfu1v3WrQP)JEsyTU1KDk7yxKm7Pwnw0BNfr2VTUSJoWz9oIczRirvFva9B2XOBKmV2P2tVjs7MbPEGhQWVKhuBjEDQzyewj19CPgEzxJm(i5qKdlxeXVQ8q3kFzRBj5bXvnZj6aBGs9rZFIa3CKcD4yzorNauRloPdgCoHggADjipKsr36sl6wPORyAEy7HhHEMXYBgmsZDMGkuDr16Yn5MinQeNEgTG7qGPgTBvrDXkQMYIK8SDB19x6yFgXuo(uS8HQuaXsuRVx3bTJu4oYFkwzNWUJSzXKx7HQBJaYvtUHSf3NcSl6k)1OcdU8RtXqSKcLIDsERGQ8BQxkym0Sa)P0YmQH9cQGkI0KJq1OMVauuhiLdub2f0ZmvC1lfvCOKq3FQUiLrkZHtMk8SLN3T0ZP5umER0rzBLG4HHrvk0Knl5)HUlK5K6t62KOtchKrEiolnSilMFRHZbCmdMuN7Xrrf3mKs9PzzwMlmd20r1h07XiBa5MPFS2RKKIdAmdPDFjUT(Gt0hH34wkRE1l)bLv0UVYVxg(LokPSKAg6sxFe5xV36Cxno(x6bv0R0UmmuwRDK8dSq(yJ)LEquYpOH8FVCeerzq4qGmFkOz2kXB6uBB0RJwTaSG)qsyglGPSAwcMMpxrWPIZAVcO12anvk9cTwv24H9ifjM85rvVsvh8uxoQn5OznChoiNMRxqdtSl7NUJ5dc8iEOjoIyYzdJxrSMhzIE2oIXAAWwpdquNvbtTv5zBnpKeOKlUxdJZ8nfrknd1deLoDPx3Brk5nPxjEJ93(3a9nYWAm4SxsEyfI0WrAhHndkLYQ8SgrJU(gP39aJfl2XgW38gJnU9TS7Z0)6ZNXsZVDp(ipHaTjOxyI6JXW4nh8Bi7c1vfIUKZwQHYlhIkMZXZpBxvhr6zTydQbGziZkQIr2EHgouBLmDEm0HYC4CaTtLu)auUsg9m2bOa9Gebx9NM9A)1PO5S(iMqp72nV5yEbbE9(0s8T7llXx9n1xXpleuBQVOVkegdwMd3SYUCsu2S(Y3(xHLhi5PDzzFwE)vYbUit38ARu2tq04RmbrToRGQ1g90y7IzGEpJGKn4RO9IRhecMr(7weNdi1wXi)WQNI(mi6ChmJ9t)XYd2jz5(P)nbAcdXXt4hZ38gWlodF5j19N4y6(P)ehvzJ7o1ItQirDyNc(5L6yph7AH(r8)YvTv8xIkrXfzXwYQU4LWpSnM9vQaAzcpULIhy(pFc(biOfGElDY74XkEiCblN7Tc9FNaZBrVSNfFWXp7VAWSnjEKc8)EAfVEBk7VpxAKRdHZygPBfE0xAS2uUcgrC6QqDS6SAgNmhtxZIj)r6nTBugVmDSUZPCcGbH5FIhgiE4Z(CNhYVxf1T2tHXMrYwfPoZWd9DeETtA9o3JU9z65cXgsrFFYjZDtTVN0t4tnKCD77vFvRkFQAKQE09t)byyM1sqyN9NsRuW(v6oqcFwmZytPWFAwUWm8pjEMIeFGG2JrFk2vFoJ44kDoPmSU1lzudXmB3Qpfg)7fL5rZb2HLpOf3PnPf9DOBbi3zaR9VIcJ)p)59L)9bS)(P)LnR(ml2HKuqvH)hQFoloAgNbZ(Zu28OT1nzl7dafLSNajSlzbFTjFhRcJSuQUum9OhttwW)QTCrm2qUYzISv5cE2A9hXjzAluy7KdfhYLM1aXmlZMwIRP1rjbkBeYUDv3fSB2WEYWbknNO5(W)e15h728qcRHeJxecPiZAOH243JXG8YYDS3(3cWyS40h)GBjg3(jh1fhuT5nfkpCqvjAtD2ZAHLQIqQioAtDELZAFQTtQ8jZOmn3TO((2YBcdZQt7dA7(0LnruCIDfpKcWaeQ(r(Vm5Fc]] )
