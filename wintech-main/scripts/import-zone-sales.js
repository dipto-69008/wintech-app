/**
 * Imports Monthly-Sales-Summary Excel files → zonesalesreports collection
 * Run: node scripts/import-zone-sales.js
 */
'use strict';

const path     = require('path');
const fs       = require('fs');
const XLSX     = require('xlsx');
const mongoose = require('mongoose');

// ── Load .env.local ───────────────────────────────────────────────────────────
function loadEnv() {
  const envPath = path.join(__dirname, '..', '.env.local');
  if (!fs.existsSync(envPath)) return;
  fs.readFileSync(envPath, 'utf-8').split('\n').forEach(line => {
    const t = line.trim();
    if (!t || t.startsWith('#')) return;
    const eq = t.indexOf('=');
    if (eq < 0) return;
    const k = t.slice(0, eq).trim(), v = t.slice(eq + 1).trim();
    if (!process.env[k]) process.env[k] = v;
  });
}
loadEnv();

// ── Mongoose schema (inline) ──────────────────────────────────────────────────
const Schema = mongoose.Schema;
const ZoneSalesReportSchema = new Schema({
  year: Number, month: Number, zone: String,
  target: Number, previousDues: Number, totalSales: Number,
  returnGoods: Number, netSales: Number, commission: Number,
  collectionAmount: Number, badDebt: Number, totalDues: Number,
  targetAchievement: Number, salesPercent: Number,
}, { timestamps: true });
ZoneSalesReportSchema.index({ year: 1, month: 1, zone: 1 }, { unique: true });
const ZoneSalesReport = mongoose.models.ZoneSalesReport ||
  mongoose.model('ZoneSalesReport', ZoneSalesReportSchema);

// ── Month name → number ───────────────────────────────────────────────────────
const MONTH_MAP = {
  january:1, february:2, febuary:2, march:3, april:4, may:5, june:6,
  july:7, august:8, september:9, october:10, november:11, december:12,
};

function parseMonthYear(filename) {
  const base = path.basename(filename, path.extname(filename)).toLowerCase();
  const yearMatch = base.match(/\b(20\d{2})\b/);
  const year = yearMatch ? parseInt(yearMatch[1]) : new Date().getFullYear();
  let month = 0;
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

function isZoneRow(row) {
  const name = String(row[0] ?? '').trim();
  if (!name || /^total/i.test(name) || /^area/i.test(name)) return false;
  // Must have at least a target or sales value
  return toNum(row[1]) > 0 || toNum(row[3]) > 0;
}

// ── Parse one Company Sales Summary file ──────────────────────────────────────
function parseSummaryFile(filePath, month, year) {
  const wb = XLSX.readFile(filePath);
  const ws = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });

  // Find header row (contains "Area" or "Target")
  let dataStart = 5;
  for (let i = 0; i < Math.min(10, rows.length); i++) {
    const r = rows[i];
    if (String(r[0] ?? '').match(/area/i) || String(r[1] ?? '').match(/target/i)) {
      dataStart = i + 2; // skip header + sub-header
      break;
    }
  }

  const records = [];
  for (let i = dataStart; i < rows.length; i++) {
    const row = rows[i];
    if (!isZoneRow(row)) continue;

    records.push({
      year,
      month,
      zone:              String(row[0]).trim(),
      target:            toNum(row[1]),
      previousDues:      toNum(row[2]),
      totalSales:        toNum(row[3]),
      returnGoods:       toNum(row[4]),
      netSales:          toNum(row[5]),
      commission:        toNum(row[6]),
      collectionAmount:  toNum(row[7]),
      badDebt:           toNum(row[8]),
      totalDues:         toNum(row[9]),
      targetAchievement: toNum(row[10]),
      salesPercent:      toNum(row[11]),
    });
  }
  return records;
}

// ── Gather all Summary files ──────────────────────────────────────────────────
function getSummaryFiles() {
  const dirs = [
    path.join(__dirname, '..', 'xldata', 'Sales-2025', 'Monthly-Sales-Summary -2025'),
    path.join(__dirname, '..', 'xldata', 'Sales-2026', 'Company Sales Summary 2026'),
  ];
  const files = [];
  for (const dir of dirs) {
    if (!fs.existsSync(dir)) continue;
    fs.readdirSync(dir).forEach(f => {
      if (/\.(xlsx|xls)$/i.test(f) && !f.startsWith('~$')) {
        files.push(path.join(dir, f));
      }
    });
  }
  return files;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('✓ Connected to MongoDB');

  const files = getSummaryFiles();
  console.log(`Processing ${files.length} Monthly-Sales-Summary files…`);

  let totalInserted = 0, totalUpdated = 0;

  for (const filePath of files) {
    const fname = path.basename(filePath);
    const { month, year } = parseMonthYear(fname);
    if (!month || !year) { console.log(`  ⚠ Skipping (no date): ${fname}`); continue; }

    let records;
    try { records = parseSummaryFile(filePath, month, year); }
    catch (e) { console.log(`  ✗ Parse error ${fname}:`, e.message); continue; }

    if (records.length === 0) { console.log(`  ⚠ No rows: ${fname}`); continue; }

    for (const rec of records) {
      const res = await ZoneSalesReport.updateOne(
        { year: rec.year, month: rec.month, zone: rec.zone },
        { $set: rec },
        { upsert: true }
      );
      if (res.upsertedCount) totalInserted++;
      else if (res.modifiedCount) totalUpdated++;
    }
    console.log(`  ✓ ${fname} → ${records.length} zones (${month}/${year})`);
  }

  console.log(`\nDone. Inserted: ${totalInserted}, Updated: ${totalUpdated}`);
  process.exit(0);
}

main().catch(e => { console.error(e.message); process.exit(1); });
