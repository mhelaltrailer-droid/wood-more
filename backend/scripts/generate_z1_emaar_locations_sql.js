/**
 * توليد seed_z1_emaar_f_project_locations.sql من DDD.xlsx (ورقة Z1_EMAAR_F).
 * One-time: cd backend && npm install
 * Usage: node scripts/generate_z1_emaar_locations_sql.js [path/to/DDD.xlsx]
 */
const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');
const { parseRowsToStructure, buildLocationsSeedSql } = require('./lib/xlsx_project_locations');

const defaultXlsx = path.join('C:', 'Users', 'home', 'Downloads', 'DDD.xlsx');
const xlsxPath = process.argv[2] || defaultXlsx;
const outSql = path.join(__dirname, 'seed_z1_emaar_f_project_locations.sql');

const PROJECT = 'Z1_EMAAR_F';
const SHEET = 'Z1_EMAAR_F';

function main() {
  const wb = XLSX.readFile(xlsxPath);
  const sh = wb.Sheets[SHEET];
  if (!sh) throw new Error(`Sheet ${SHEET} not found`);
  const rows = XLSX.utils.sheet_to_json(sh, { header: 1, defval: '' });
  const parsed = parseRowsToStructure(rows);
  const sql = buildLocationsSeedSql(PROJECT, parsed);
  fs.writeFileSync(outSql, sql, 'utf8');
  console.log('Wrote', outSql);
  console.log('Folders:', parsed.folderNames.length, 'Work sites:', parsed.pairs.length);
}

main();
