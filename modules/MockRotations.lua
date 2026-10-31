local _, NS = ...
-- modules/MockRotations.lua — the sample rotations (data only): one table per class, each row one
-- spell, feeding BOTH a sample run's casts and its damage (modules/MockRuns.lua builds them together,
-- as a real fight makes both). Names and icons come from C_Spell, as for a real run.
--
-- A ROW: { id, hit (a hit's size, relative to the other rows), from (the first cast, seconds; negative
-- is a pre-pull cast, heard while armed), every (seconds between casts), cd (the base cooldown, ms),
-- ticks + gap (a damage-over-time spell: this many hits, `gap` seconds apart, after each cast),
-- pet (the pet's cast), passive (damage with no cast of its own, Ignite), major (a long cooldown a
-- sample run may have missed), alt (the talent only loadout b runs), main (the talent it replaces),
-- none (a cast that deals no damage of its own, Combustion) }.

NS.MockRotations = {
    WARRIOR = {
        { id = 167105, hit = 2.2, from = 0.6, every = 45, cd = 45000, major = true },  -- Colossus Smash
        { id = 12294, hit = 3.1, from = 1.2, every = 6, cd = 6000 },                   -- Mortal Strike
        { id = 7384, hit = 1.6, from = 2.0, every = 8, cd = 12000 },                   -- Overpower
        { id = 1464, hit = 1.1, from = 2.8, every = 3, cd = 0, main = true },          -- Slam
        { id = 163201, hit = 2.6, from = 9.0, every = 11, cd = 0, alt = true },        -- Execute
        { id = 262115, hit = 0.2, from = 4.0, every = 12, cd = 0, ticks = 8, gap = 1.5 }, -- Deep Wounds
    },
    PALADIN = {
        { id = 31884, from = 0.3, every = 120, cd = 120000, none = true },             -- Avenging Wrath
        { id = 255937, hit = 3.4, from = 1.2, every = 30, cd = 30000, major = true },  -- Wake of Ashes
        { id = 184575, hit = 1.8, from = 0.8, every = 7, cd = 12000 },                 -- Blade of Justice
        { id = 20271, hit = 1.4, from = 2.0, every = 6, cd = 0 },                      -- Judgment
        { id = 35395, hit = 0.8, from = 1.5, every = 4, cd = 0 },                      -- Crusader Strike
        { id = 85256, hit = 2.7, from = 2.6, every = 3.5, cd = 0, main = true },       -- Templar's Verdict
        { id = 53385, hit = 2.3, from = 5.0, every = 7, cd = 0, alt = true },          -- Divine Storm
    },
    HUNTER = {
        { id = 288613, from = 0.4, every = 120, cd = 120000, none = true },            -- Trueshot
        { id = 19434, hit = 3.0, from = 1.0, every = 7, cd = 12000 },                  -- Aimed Shot
        { id = 257044, hit = 1.9, from = 2.4, every = 20, cd = 20000, major = true },  -- Rapid Fire
        { id = 185358, hit = 1.2, from = 1.8, every = 4, cd = 0 },                     -- Arcane Shot
        { id = 56641, hit = 0.7, from = 2.6, every = 2.5, cd = 0, main = true },       -- Steady Shot
        { id = 53351, hit = 2.8, from = 8.0, every = 10, cd = 0, alt = true },         -- Kill Shot
    },
    ROGUE = {
        { id = 13750, from = 0.3, every = 180, cd = 180000, none = true },             -- Adrenaline Rush
        { id = 315341, hit = 2.6, from = 1.0, every = 45, cd = 45000, major = true },  -- Between the Eyes
        { id = 1752, hit = 1.0, from = 0.8, every = 2.2, cd = 0, main = true },        -- Sinister Strike
        { id = 8676, hit = 1.7, from = 4.0, every = 6, cd = 0, alt = true },           -- Ambush
        { id = 2098, hit = 2.4, from = 2.4, every = 4.5, cd = 0 },                     -- Dispatch
        { id = 13877, hit = 1.6, from = 3.6, every = 15, cd = 15000 },                 -- Blade Flurry
    },
    PRIEST = {
        { id = 34433, hit = 0.4, from = 0.5, every = 180, cd = 180000, major = true, ticks = 12, gap = 1.5 }, -- Shadowfiend
        { id = 589, hit = 0.3, from = 0.8, every = 16, cd = 0, ticks = 7, gap = 2 },   -- Shadow Word: Pain
        { id = 34914, hit = 0.4, from = 1.6, every = 16, cd = 0, ticks = 7, gap = 2 }, -- Vampiric Touch
        { id = 8092, hit = 2.2, from = 2.2, every = 7.5, cd = 7500 },                  -- Mind Blast
        { id = 335467, hit = 2.8, from = 4.0, every = 8, cd = 0 },                     -- Devouring Plague
        { id = 15407, hit = 0.8, from = 3.0, every = 3, cd = 0, main = true },         -- Mind Flay
        { id = 73510, hit = 1.3, from = 3.4, every = 4, cd = 0, alt = true },          -- Mind Spike
    },
    DEATHKNIGHT = {
        { id = 51271, from = 0.3, every = 60, cd = 60000, none = true },               -- Pillar of Frost
        { id = 196770, hit = 0.4, from = 0.8, every = 20, cd = 20000, major = true, ticks = 8, gap = 1 }, -- Remorseless Winter
        { id = 49020, hit = 2.6, from = 1.4, every = 5, cd = 0 },                      -- Obliterate
        { id = 49143, hit = 1.7, from = 2.2, every = 3.5, cd = 0, main = true },       -- Frost Strike
        { id = 47541, hit = 1.9, from = 2.6, every = 5, cd = 0, alt = true },          -- Death Coil
        { id = 49184, hit = 1.2, from = 3.0, every = 8, cd = 0 },                      -- Howling Blast
    },
    SHAMAN = {
        { id = 191634, from = 0.4, every = 60, cd = 60000, none = true },              -- Stormkeeper
        { id = 188389, hit = 0.4, from = 0.9, every = 18, cd = 6000, ticks = 6, gap = 3 }, -- Flame Shock
        { id = 51505, hit = 2.2, from = 1.8, every = 8, cd = 8000 },                   -- Lava Burst
        { id = 188196, hit = 1.0, from = 2.6, every = 2.5, cd = 0, main = true },      -- Lightning Bolt
        { id = 188443, hit = 1.1, from = 3.0, every = 3, cd = 0, alt = true },         -- Chain Lightning
        { id = 8042, hit = 2.4, from = 4.0, every = 6, cd = 0 },                       -- Earth Shock
        { id = 192249, hit = 0.5, from = 0.5, every = 150, cd = 150000, major = true, ticks = 12, gap = 1.5 }, -- Storm Elemental
    },
    MAGE = {
        { id = 190319, from = 0.5, every = 120, cd = 120000, none = true },            -- Combustion
        { id = 133, hit = 1.2, from = -2.0, every = 2.6, cd = 0, main = true },        -- Fireball
        { id = 2948, hit = 0.9, from = -1.6, every = 2.2, cd = 0, alt = true },        -- Scorch
        { id = 257541, hit = 1.8, from = 6.0, every = 25, cd = 25000, major = true },  -- Phoenix Flames
        { id = 108853, hit = 1.5, from = 1.0, every = 10, cd = 12000 },                -- Fire Blast
        { id = 11366, hit = 3.2, from = 3.2, every = 4, cd = 0 },                      -- Pyroblast
        { id = 2120, hit = 1.0, from = 7.0, every = 11, cd = 0 },                      -- Flamestrike
        { id = 12654, hit = 0.5, from = 2.0, every = 2, cd = 0, passive = true },      -- Ignite
    },
    WARLOCK = {
        { id = 6353, hit = 2.0, from = -1.6, every = 45, cd = 45000 },                 -- Soul Fire
        { id = 1122, hit = 0.5, from = 0.4, every = 120, cd = 120000, major = true, ticks = 14, gap = 2 }, -- Summon Infernal
        { id = 445468, hit = 0.5, from = 0.9, every = 12, cd = 0, ticks = 6, gap = 2 }, -- Wither
        { id = 29722, hit = 1.0, from = 1.8, every = 2.5, cd = 0 },                    -- Incinerate
        { id = 17962, hit = 1.4, from = 2.2, every = 10, cd = 13000 },                 -- Conflagrate
        { id = 116858, hit = 2.9, from = 3.1, every = 6, cd = 0, main = true },        -- Chaos Bolt
        { id = 5740, hit = 0.6, from = 4.4, every = 9, cd = 0, alt = true, ticks = 6, gap = 1 }, -- Rain of Fire
        { id = 17877, hit = 2.1, from = 7.5, every = 14, cd = 12000 },                 -- Shadowburn
        { id = 3110, hit = 0.2, from = 0.6, every = 2, cd = 0, pet = true },           -- Firebolt (the imp)
    },
    MONK = {
        { id = 123904, hit = 0.5, from = 0.4, every = 120, cd = 120000, major = true, ticks = 15, gap = 1.3 }, -- Invoke Xuen
        { id = 100780, hit = 0.7, from = 0.8, every = 3, cd = 0 },                     -- Tiger Palm
        { id = 100784, hit = 1.1, from = 1.6, every = 3.5, cd = 0, main = true },      -- Blackout Kick
        { id = 101546, hit = 1.3, from = 4.2, every = 5, cd = 0, alt = true },         -- Spinning Crane Kick
        { id = 107428, hit = 2.4, from = 2.4, every = 8, cd = 10000 },                 -- Rising Sun Kick
        { id = 113656, hit = 0.9, from = 3.2, every = 16, cd = 24000, ticks = 4, gap = 0.8 }, -- Fists of Fury
    },
    DRUID = {
        { id = 194223, from = 0.3, every = 180, cd = 180000, none = true },            -- Celestial Alignment
        { id = 8921, hit = 0.3, from = 0.6, every = 16, cd = 0, ticks = 7, gap = 2 },  -- Moonfire
        { id = 93402, hit = 0.3, from = 1.4, every = 12, cd = 0, ticks = 6, gap = 2 }, -- Sunfire
        { id = 190984, hit = 1.0, from = 2.2, every = 2.5, cd = 0, main = true },      -- Wrath
        { id = 194153, hit = 1.5, from = 2.8, every = 3.2, cd = 0, alt = true },       -- Starfire
        { id = 78674, hit = 2.6, from = 3.6, every = 6, cd = 0 },                      -- Starsurge
        { id = 191034, hit = 0.5, from = 5.0, every = 30, cd = 0, major = true, ticks = 8, gap = 1 }, -- Starfall
    },
    DEMONHUNTER = {
        { id = 191427, from = 0.3, every = 120, cd = 120000, none = true },            -- Metamorphosis
        { id = 198013, hit = 0.9, from = 0.9, every = 30, cd = 30000, major = true, ticks = 5, gap = 0.4 }, -- Eye Beam
        { id = 258920, hit = 0.3, from = 1.4, every = 15, cd = 15000, ticks = 6, gap = 1 }, -- Immolation Aura
        { id = 162794, hit = 2.0, from = 2.2, every = 3.5, cd = 0 },                   -- Chaos Strike
        { id = 188499, hit = 1.7, from = 3.0, every = 9, cd = 9000, main = true },     -- Blade Dance
        { id = 232893, hit = 1.2, from = 4.0, every = 12, cd = 12000, alt = true },    -- Felblade
        { id = 162243, hit = 0.6, from = 1.8, every = 2.4, cd = 0 },                   -- Demon's Bite
    },
    EVOKER = {
        { id = 375087, from = 0.3, every = 120, cd = 120000, none = true },            -- Dragonrage
        { id = 357208, hit = 0.6, from = 0.8, every = 30, cd = 30000, major = true, ticks = 6, gap = 2 }, -- Fire Breath
        { id = 359073, hit = 3.0, from = 2.4, every = 30, cd = 30000 },                -- Eternity Surge
        { id = 356995, hit = 0.9, from = 3.0, every = 8, cd = 0, ticks = 4, gap = 0.75 }, -- Disintegrate
        { id = 361469, hit = 1.1, from = 1.6, every = 2.5, cd = 0, main = true },      -- Living Flame
        { id = 362969, hit = 0.8, from = 2.0, every = 2.2, cd = 0, alt = true },       -- Azure Strike
    },
}
