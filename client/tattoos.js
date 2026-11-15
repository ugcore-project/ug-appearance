/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// The tattoo catalog from the game. JS because Lua cannot read native structs: GET_TATTOO_SHOP_DLC_ITEM_DATA fills an
// sTattooShopItemValues, eight script-aligned fields of 8 bytes (LockHash, Index, CollectionHash, PresetHash, Cost,
// eFacing, UpdateGroup, NameTextLabel). Read as 32-bit integers, field n is at index 2n. MUST be verified live.

const ITEM_DATA = "0xFF56381874F82086";
const ITEM_BYTES = 64;
const COLLECTION = 4;
const PRESET = 6;
const MAX_ITEMS = 4096;

/** @type {Map<number, { collection: number, overlay: number, zone: number }[]>} */
const cache = new Map();

/**
 * Tattoos of a character type: 3 for the freemode male, 4 for the female. Read once, then cached.
 * @param {number} characterType
 */
function catalog(characterType) {
  if (characterType !== 3 && characterType !== 4) {
    return [];
  }

  const cached = cache.get(characterType);

  if (cached) {
    return cached;
  }

  const list = [];
  const count = Math.min(GetNumTattooShopDlcItems(characterType), MAX_ITEMS);
  const seen = new Set();

  for (let index = 0; index < count; index++) {
    const buffer = new Int32Array(ITEM_BYTES / 4);

    if (!Citizen.invokeNative(ITEM_DATA, characterType, index, buffer)) {
      continue;
    }

    const collection = buffer[COLLECTION];
    const overlay = buffer[PRESET];
    const key = `${collection}:${overlay}`;

    if (collection === 0 || overlay === 0 || seen.has(key)) {
      continue;
    }

    seen.add(key);
    list.push({ collection, overlay, zone: GetPedDecorationZoneFromHashes(collection, overlay) });
  }

  cache.set(characterType, list);

  return list;
}

exports("TattooCatalog", catalog);
