/**
 * xl-to-json.js — Reusable converter for monthly "Sales of <Month> <Year>.xls" files.
 *
 * Each workbook sheet represents one branch (its tab name is used as the branch's
 * short/nickname, e.g. "Kingfisher", "Magpie-1"). The "Zone-…" line inside the
 * sheet holds the formal zone/area description, which is stored as the branch's
 * `zoneCode`. This mapping is intentional — see scripts/README-import.md.
 *
 * Usage:
 *   node scripts/xl-to-json.js "xldata/Sales-2026/Sales of May 2026.xls"
 *   node scripts/xl-to-json.js                (auto-detects newest "Sales of * .xls" in xldata/**)
 *
 * Output: writes data/imports/<year>-<month>-sales.json (also returns the object
 * when required as a module) which json-to-mongo.js then consumes.
 */
'use strict';

const path = require('path');
const fs = require('fs');
const XLSX = require('xlsx');

const MONTH_MAP = {
  january: 1, february: 2, febuary: 2, march: 3, april: 4, may: 5, june: 6,
  july: 7, august: 8, september: 9, october: 10, november: 11, december: 12,
};

function findLatestXlsFile() {
  const root = path.join(__dirname, '..', 'xldata');
  if (!fs.existsSync(root)) return null;
  let candidates = [];
  const walk = (dir) => {
    for (const f of fs.readdirSync(dir)) {
      const full = path.join(dir, f);
      if (fs.statSync(full).isDirectory()) walk(full);
      else if (/^sales of .+\.(xls|xlsx)$/i.test(f) && !f.startsWith('~$')) candidates.push(full);
    }
  };
  walk(root);
  if (!candidates.length) return null;
  candidates.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  return candidates[0];
}

function parseMonthYearFromFilename(filename) {
  const base = path.basename(filename, path.extname(filename)).toLowerCase();
  const yearMatch = base.match(/\b(20\d{2})\b/);
  const year = yearMatch ? parseInt(yearMatch[1], 10) : null;
  let month = null;
  for (const [name, num] of Object.entries(MONTH_MAP)) {
    if (base.includes(name)) { month = num; break; }
  }
  return { month, year };
}

function toNum(v) {
  if (v === '' || v === null || v === undefined) return 0;
  const n = parseFloat(String(v).replace(/,/g, ''));
  return isNaN(n) ? 0 : n;
}

// Handles messy Bangladeshi-lakh formatted target strings like
// "5,50,000.00", "3,50.000.00", "3,50,000/-", "2,00,000.00 "
function toTargetAmount(raw) {
  if (!raw) return 0;
  let s = String(raw).trim();
  s = s.replace(/\/-\s*$/, '');
  s = s.replace(/\.\d{2}\s*$/, '');
  s = s.replace(/[^\d]/g, '');
  return s ? parseInt(s, 10) : 0;
}

function cellText(row, i) {
  return String((row && row[i]) || '').trim();
}

function rowText(row) {
  return (row || []).map(c => String(c || '')).join(' | ');
}

// Search a set of header rows (joined) for "Assigned/Assinged Officer[ Name]: <name>"
function extractAssignedOfficer(rows, uptoRow) {
  for (let i = 0; i <= uptoRow; i++) {
    const text = rowText(rows[i]);
    const m = text.match(/Ass\w*\s+Officer(?:\s*Name)?\s*:\s*([^|]+)/i);
    if (m) {
      let name = m[1].trim();
      name = name.replace(/\s{2,}/g, ' ').trim();
      return name;
    }
  }
  return '';
}

function extractZoneLine(rows) {
  for (let i = 0; i < Math.min(8, rows.length); i++) {
    const text = cellText(rows[i], 0);
    if (/^zone/i.test(text)) return text.replace(/^zone\s*-?\s*/i, '').trim();
  }
  return '';
}

function extractTarget(rows) {
  for (let i = 0; i < Math.min(8, rows.length); i++) {
    const text = cellText(rows[i], 0);
    const m = text.match(/target\s*:?\s*([\d.,\/\-\s]+)/i);
    if (m) return toTargetAmount(m[1]);
  }
  return 0;
}

// Party count text: "Total Party-30 , Previous Party- 29, New Party-01"
function extractPartyCounts(rows) {
  for (let i = 0; i < Math.min(8, rows.length); i++) {
    const text = cellText(rows[i], 0);
    if (/total party/i.test(text)) {
      const total = text.match(/total party\s*-?\s*(\d+)/i);
      const prev = text.match(/previous party\s*-?\s*(\d+)/i);
      const neu = text.match(/new party\s*-?\s*(\d+)/i);
      return {
        totalParty: total ? parseInt(total[1], 10) : undefined,
        previousParty: prev ? parseInt(prev[1], 10) : undefined,
        newParty: neu ? parseInt(neu[1], 10) : undefined,
      };
    }
  }
  return {};
}

const HEADER_MATCHERS = [
  { key: 'partyName', re: /party\s*name/i },
  { key: 'invoiceNos', re: /inv(oice)?\.?\s*no/i },
  { key: 'previousDue', re: /previous\s*due/i },
  { key: 'totalSales', re: /total\s*sales/i },
  { key: 'commission', re: /comm/i },
  { key: 'collectionAmount', re: /collection/i },
  { key: 'mrNo', re: /mr\.?\s*no|bad\s*debt/i },
  { key: 'cheque', re: /cheque/i },
  { key: 'returnGoods', re: /ret\.?\s*go/i },
  { key: 'totalDues', re: /total\s*du/i },
];

function findHeaderRow(rows) {
  for (let i = 0; i < Math.min(10, rows.length); i++) {
    if (/party\s*name/i.test(cellText(rows[i], 0))) return i;
  }
  return -1;
}

function buildColumnMap(headerRow) {
  const map = {};
  headerRow.forEach((cell, idx) => {
    const text = String(cell || '').trim();
    if (!text) return;
    for (const { key, re } of HEADER_MATCHERS) {
      if (!map[key] && re.test(text)) { map[key] = idx; break; }
    }
  });
  return map;
}

function isDataDone(row) {
  const first = cellText(row, 0);
  if (!first) return false;
  return /^total\s*-?$/i.test(first)
    || /^[.\-–—*]+$/.test(first)
    || /accounts\s*dept/i.test(first)
    || /deputy manager/i.test(first)
    || /manager,\s*marketing/i.test(first);
}

function parseSheet(ws, sheetName, month, year) {
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });
  const headerRowIdx = findHeaderRow(rows);
  if (headerRowIdx === -1) return null;

  const colMap = buildColumnMap(rows[headerRowIdx]);
  const zoneLine = extractZoneLine(rows);
  const target = extractTarget(rows);
  const assignedOfficer = extractAssignedOfficer(rows, headerRowIdx);
  const partyCounts = extractPartyCounts(rows);

  const parties = [];
  for (let i = headerRowIdx + 1; i < rows.length; i++) {
    const row = rows[i];
    if (isDataDone(row)) break;
    const name = cellText(row, colMap.partyName ?? 0);
    if (!name) continue;

    const get = (key) => (colMap[key] !== undefined ? row[colMap[key]] : '');
    parties.push({
      partyName: name,
      invoiceNos: String(get('invoiceNos') || '').trim(),
      previousDue: toNum(get('previousDue')),
      totalSales: toNum(get('totalSales')),
      commission: toNum(get('commission')),
      collectionAmount: toNum(get('collectionAmount')),
      mrNo: String(get('mrNo') || '').trim(),
      cheque: String(get('cheque') || '').trim(),
      returnGoods: toNum(get('returnGoods')),
      totalDues: toNum(get('totalDues')),
    });
  }

  return {
    month,
    year,
    branchNickname: sheetName.trim(),
    zoneCode: zoneLine,
    target,
    assignedOfficer,
    ...partyCounts,
    parties,
  };
}

function convertWorkbook(filePath) {
  const { month, year } = parseMonthYearFromFilename(filePath);
  if (!month || !year) throw new Error(`Could not detect month/year from filename: ${path.basename(filePath)}`);

  const wb = XLSX.readFile(filePath);
  const branches = [];
  for (const sheetName of wb.SheetNames) {
    const ws = wb.Sheets[sheetName];
    let parsed;
    try { parsed = parseSheet(ws, sheetName, month, year); }
    catch (e) { console.log(`  ✗ Skipping sheet "${sheetName}": ${e.message}`); continue; }
    if (!parsed) { console.log(`  ⚠ Skipping sheet "${sheetName}" (no header row found)`); continue; }
    branches.push(parsed);
  }

  return {
    sourceFile: path.basename(filePath),
    month,
    year,
    generatedAt: new Date().toISOString(),
    branches,
  };
}

function main() {
  const inputArg = process.argv[2];
  const filePath = inputArg ? path.resolve(inputArg) : findLatestXlsFile();
  if (!filePath || !fs.existsSync(filePath)) {
    console.error('No xls file found. Pass a path: node scripts/xl-to-json.js "xldata/Sales-2026/Sales of May 2026.xls"');
    process.exit(1);
  }

  console.log(`Converting: ${filePath}`);
  const result = convertWorkbook(filePath);

  const outDir = path.join(__dirname, '..', 'data', 'imports');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `${result.year}-${String(result.month).padStart(2, '0')}-sales.json`);
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2));

  const totalParties = result.branches.reduce((a, b) => a + b.parties.length, 0);
  console.log(`✓ Parsed ${result.branches.length} branches, ${totalParties} party rows`);
  console.log(`✓ Wrote ${outPath}`);
}

if (require.main === module) main();

module.exports = { convertWorkbook, parseMonthYearFromFilename, toTargetAmount, toNum };
