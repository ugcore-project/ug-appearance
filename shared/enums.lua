--[[

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Every magic value of this resource. Code and config samples MUST use these.
---@class UgAp.Enums
UgAp.Enums = {}

---Ped components the editor changes, by name, with their native id. Head (0) and hair (2) are edited elsewhere.
---@enum UgApComponent
UgAp.Enums.Component = {
    Mask = 1,
    Arms = 3,
    Legs = 4,
    Bag = 5,
    Shoes = 6,
    Accessory = 7,
    Undershirt = 8,
    Armor = 9,
    Decals = 10,
    Top = 11,
}

---Ped props by name, with their native id.
---@enum UgApProp
UgAp.Enums.Prop = {
    Hat = 0,
    Glasses = 1,
    Ears = 2,
    Watch = 6,
    Bracelet = 7,
}

---Head overlays by name, with their native id.
---@enum UgApOverlay
UgAp.Enums.Overlay = {
    Blemishes = 0,
    Beard = 1,
    Eyebrows = 2,
    Ageing = 3,
    Makeup = 4,
    Blush = 5,
    Complexion = 6,
    SunDamage = 7,
    Lipstick = 8,
    Moles = 9,
    ChestHair = 10,
    BodyBlemishes = 11,
    AddBodyBlemishes = 12,
}

---Face features by name, with their native id.
---@enum UgApFaceFeature
UgAp.Enums.FaceFeature = {
    NoseWidth = 0,
    NosePeakHeight = 1,
    NosePeakLength = 2,
    NoseBoneHeight = 3,
    NosePeakLowering = 4,
    NoseBoneTwist = 5,
    EyebrowHeight = 6,
    EyebrowDepth = 7,
    CheekBoneHeight = 8,
    CheekBoneWidth = 9,
    CheekWidth = 10,
    EyeOpening = 11,
    LipThickness = 12,
    JawBoneWidth = 13,
    JawBoneLength = 14,
    ChinBoneHeight = 15,
    ChinBoneLength = 16,
    ChinBoneWidth = 17,
    ChinCleft = 18,
    NeckThickness = 19,
}

---The unit of permission and price. MUST match web/src/types/protocol.ts.
---@enum UgApCategory
UgAp.Enums.Category = {
    Model = 'model',
    Heritage = 'heritage',
    Features = 'features',
    Eyes = 'eyes',
    Skin = 'skin',
    Hair = 'hair',
    FacialHair = 'facialHair',
    Makeup = 'makeup',
    Clothing = 'clothing',
    Accessories = 'accessories',
    Tattoos = 'tattoos',
}

---What an editor session MAY change. MUST match web/src/types/protocol.ts.
---@enum UgApStoreKind
UgAp.Enums.StoreKind = {
    Clothing = 'clothing',
    Barber = 'barber',
    Tattoo = 'tattoo',
    Surgeon = 'surgeon',
    Wardrobe = 'wardrobe',
    Creator = 'creator',
    Admin = 'admin',
}

---How players open stores: the interact key and a prompt, or ug-target's third eye.
---@enum UgApInteraction
UgAp.Enums.Interaction = {
    Key = 'key',
    Target = 'target',
}

---Camera presets of the studio. MUST match web/src/types/protocol.ts.
---@enum UgApCamera
UgAp.Enums.Camera = {
    Face = 'face',
    Upper = 'upper',
    Lower = 'lower',
    Feet = 'feet',
    Full = 'full',
}

---Camera easing.
---@enum UgApEase
UgAp.Enums.Ease = {
    Linear = 'linear',
    InOut = 'inOut',
    In = 'in',
    Out = 'out',
}

---Light presets of the studio. MUST match web/src/types/protocol.ts.
---@enum UgApLight
UgAp.Enums.Light = {
    Natural = 'natural',
    Studio = 'studio',
    Day = 'day',
    Night = 'night',
}

---Where the editor panel sits. MUST match web/src/types/protocol.ts.
---@enum UgApSide
UgAp.Enums.Side = {
    Left = 'left',
    Right = 'right',
}

---Where the toolbar floats. MUST match web/src/types/protocol.ts.
---@enum UgApPlace
UgAp.Enums.Place = {
    Top = 'top',
    Bottom = 'bottom',
}

---Editor tools owners MAY turn off. MUST match web/src/types/protocol.ts.
---@enum UgApFeature
UgAp.Enums.Feature = {
    Undo = 'undo',
    Randomize = 'randomize',
    Compare = 'compare',
    Favorites = 'favorites',
    Search = 'search',
    Cameras = 'cameras',
    Rotate = 'rotate',
    Zoom = 'zoom',
    Poses = 'poses',
}

---Sounds the editor plays.
---@enum UgApSound
UgAp.Enums.Sound = {
    Save = 'save',
    Error = 'error',
}

---Messages Lua sends to the page. MUST match web/src/types/protocol.ts.
---@enum UgApNuiAction
UgAp.Enums.NuiAction = {
    Config = 'config',
    Open = 'open',
    Catalog = 'catalog',
    Appearance = 'appearance',
    Outfits = 'outfits',
    Bill = 'bill',
    Result = 'result',
    Close = 'close',
}

---Callbacks the page posts. MUST match web/src/types/protocol.ts.
---@enum UgApNuiCallback
UgAp.Enums.NuiCallback = {
    Ready = 'ready',
    Change = 'change',
    Camera = 'camera',
    Rotate = 'rotate',
    Zoom = 'zoom',
    Pose = 'pose',
    Light = 'light',
    Compare = 'compare',
    Save = 'save',
    Cancel = 'cancel',
    OutfitSave = 'outfitSave',
    OutfitWear = 'outfitWear',
    OutfitDelete = 'outfitDelete',
    OutfitReplace = 'outfitReplace',
    OutfitRename = 'outfitRename',
    UniformWear = 'uniformWear',
}

---What a result message reports. MUST match web/src/types/protocol.ts.
---@enum UgApResultKind
UgAp.Enums.ResultKind = {
    Save = 'save',
    Outfit = 'outfit',
}
