/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

/** `$1,500`. Prices are whole numbers from the server. */
export function money(amount: number, locale = "en"): string {
  try {
    return `$${Math.round(amount).toLocaleString(locale)}`;
  } catch {
    return `$${Math.round(amount)}`;
  }
}
