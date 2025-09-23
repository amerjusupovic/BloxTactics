-- AnimationConstants.luau
-- Stores animation asset IDs for each unit type

local AnimationConstants = {
    Knight = {
        Attack = "rbxassetid://123508326000264",
        Move = "rbxassetid://81143734854964"    -- Example asset ID for Knight move
    },
    Archer = {
        Attack = "rbxassetid://123508326000264", -- Using same asset ID as Knight for demonstration
        Move = "rbxassetid://81143734854964"
    },
    Wizard = {
        Attack = "rbxassetid://123508326000264", -- Using same asset ID as Knight for demonstration
        Move = "rbxassetid://81143734854964"
    },
    Paladin = {
        Attack = "rbxassetid://123508326000264", -- Using same asset ID as Knight for demonstration
        Move = "rbxassetid://81143734854964"
    },
    Bomber = {
        Attack = "rbxassetid://110712693403986", -- grenade throw test animation
        Move = "rbxassetid://81143734854964"
    }
    -- Add more units as needed
}

return AnimationConstants
