/**
 * Excel → MongoDB importer
 * Run: node scripts/import-xlsx.js
 * Or called via API route POST /api/import-xlsx
 */
'use strict';

const path   = require('path');
const fs     = require('fs');
const XLSX   = require('xlsx');
const mongoose = require('mongoose');

// ── Load env from .env.local ─────────────────────────────────────────────────
function loadEnv() {
  const envPath = path.join(__dirname, '..', '.env.local');
  if (!fs.existsSync(envPath)) return;
  const lines = fs.readFileSync(envPath, 'utf-8').split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx < 0) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const val = trimmed.slice(eqIdx + 1).trim();
    if (!process.env[key]) process.env[key] = val;
  }
}
loadEnv();

// ── Helpers ───────────────────────────────────────────────────────────────────
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

function cleanStr(v) {
  return String(v ?? '').trim();
}

function isDataRow(row) {
  const name = cleanStr(row[0]);
  if (!name) return false;
  if (/^total/i.test(name)) return false;
  if (/^accounts\s+dept/i.test(name)) return false;
  if (/^assigned\s+officer/i.test(name)) return false;
  if (/^zone\s+in.?charge/i.test(name)) return false;
  return true;
}

function glob(dir, exts) {
  const results = [];
  if (!fs.existsSync(dir)) return results;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) results.push(...glob(full, exts));
    else if (exts.includes(path.extname(entry.name).toLowerCase())) results.push(full);
  }
  return results.filter(f => !path.basename(f).startsWith('~$'));
}

// ── Mongoose Schemas (inline, so no TS compilation needed) ───────────────────
const { Schema } = mongoose;

const StockReportSchema = new Schema({
  month: Number, year: Number,
  reportType: { type: String, enum: ['company','branch'], default: 'company' },
  zone: String, productName: String, packSize: String,
  cumillaStock: Number, mymensinghStock: Number, bograStock: Number,
  jessoreStock: Number, feniStock: Number, totalQuantity: Number,
  previousStock: Number, receivedQty: Number, returnQty: Number,
  transferQty: Number, salesQty: Number, bonusQty: Number,
  presentBalance: Number, remarks: String,
}, { timestamps: true });
StockReportSchema.index({ year:1, month:1, reportType:1, zone:1, productName:1, packSize:1 }, { unique:true });

const ProductionReportSchema = new Schema({
  month: Number, year: Number, zone: { type: String, default: 'Cumilla' },
  productName: String, packSize: String,
  previousBalanceKg: Number, receivedKg: Number, totalKg: Number,
  totalProductPcs: Number, convertKg: Number, totalConvertKg: Number,
  wastageKg: Number, presentBalanceKg: Number, remarks: String,
}, { timestamps: true });
ProductionReportSchema.index({ year:1, month:1, zone:1, productName:1, packSize:1 }, { unique:true });

const SalesDuesReportSchema = new Schema({
  month: Number, year: Number, zone: String,
  partyName: String, invoiceNos: String,
  previousDue: Number, totalSales: Number, commission: Number,
  collectionAmount: Number, mrNo: String, cheque: String,
  returnGoods: Number, totalDues: Number,
}, { timestamps: true });
SalesDuesReportSchema.index({ year:1, month:1, zone:1, partyName:1 }, { unique:true });

function getModels() {
  const SR  = mongoose.models.StockReport      || mongoose.model('StockReport',      StockReportSchema);
  const PR  = mongoose.models.ProductionReport || mongoose.model('ProductionReport', ProductionReportSchema);
  const SDR = mongoose.models.SalesDuesReport  || mongoose.model('SalesDuesReport',  SalesDuesReportSchema);
  return { SR, PR, SDR };
}

// ── Parsers ───────────────────────────────────────────────────────────────────

/** Parse a stock xlsx file, returns array of docs for SR model */
function parseStockFile(filepath) {
  const { month, year } = parseMonthYear(filepath);
  if (!month) return [];
  const wb = XLSX.readFile(filepath);
  const docs = [];

  for (const sheetName of wb.SheetNames) {
    const ws   = wb.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });

    const cleanSheet = sheetName.trim();

    // ── Company Stock sheet ────────────────────────────────────────────────
    if (/^company\s+stock/i.test(cleanSheet)) {
      // Headers at row 4, data from row 6
      for (let i = 5; i < rows.length; i++) {
        const row = rows[i];
        if (!isDataRow(row)) continue;
        docs.push({
          month, year,
          reportType: 'company',
          zone: null,
          productName:     cleanStr(row[0]),
          packSize:        cleanStr(row[1]),
          cumillaStock:    toNum(row[2]),
          mymensinghStock: toNum(row[3]),
          bograStock:      toNum(row[4]),
          jessoreStock:    toNum(row[5]),
          feniStock:       toNum(row[6]),
          totalQuantity:   toNum(row[7]),
          remarks:         cleanStr(row[8]),
        });
      }
    } else {
      // ── Branch zone sheets (Cumilla, Mymensing, Jessore, Bogura, Feni) ──
      // Find header row (has "Name Of Product" or "Pack")
      let headerRow = -1;
      for (let i = 0; i < Math.min(rows.length, 10); i++) {
        const r = rows[i];
        if (r.some(c => /name of product/i.test(String(c)))) { headerRow = i; break; }
        if (r.some(c => /name of\s*$/i.test(String(c))) && r.some(c => /pack/i.test(String(c)))) { headerRow = i; break; }
      }
      const dataStart = headerRow >= 0 ? headerRow + 2 : 6; // skip sub-header row
      for (let i = dataStart; i < rows.length; i++) {
        const row = rows[i];
        if (!isDataRow(row)) continue;
        docs.push({
          month, year,
          reportType: 'branch',
          zone:          cleanSheet,
          productName:   cleanStr(row[0]),
          packSize:      cleanStr(row[1]),
          previousStock: toNum(row[2]),
          receivedQty:   toNum(row[3]),
          returnQty:     toNum(row[4]),
          totalQuantity: toNum(row[5]),
          transferQty:   toNum(row[6]),
          salesQty:      toNum(row[7]),
          bonusQty:      toNum(row[8]),
          presentBalance:toNum(row[9]),
          remarks:       cleanStr(row[10]),
        });
      }
    }
  }
  return docs;
}

/** Parse a production xlsx file, returns array of docs for PR model */
function parseProductionFile(filepath) {
  const { month, year } = parseMonthYear(filepath);
  if (!month) return [];
  const wb = XLSX.readFile(filepath);
  const docs = [];

  for (const sheetName of wb.SheetNames) {
    const ws   = wb.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });
    const zone = sheetName.trim();

    // Headers at row 4-5, data from row 6
    for (let i = 6; i < rows.length; i++) {
      const row = rows[i];
      if (!isDataRow(row)) continue;
      docs.push({
        month, year, zone,
        productName:       cleanStr(row[0]),
        packSize:          cleanStr(row[4]),
        previousBalanceKg: toNum(row[1]),
        receivedKg:        toNum(row[2]),
        totalKg:           toNum(row[3]),
        totalProductPcs:   toNum(row[5]),
        convertKg:         toNum(row[6]),
        totalConvertKg:    toNum(row[7]),
        wastageKg:         toNum(row[8]),
        presentBalanceKg:  toNum(row[9]),
        remarks:           cleanStr(row[10]),
      });
    }
  }
  return docs;
}

/** Parse a sales dues xls/xlsx file, returns array of docs for SDR model */
function parseSalesFile(filepath) {
  const { month: fileMonth, year: fileYear } = parseMonthYear(filepath);
  const wb = XLSX.readFile(filepath);
  const docs = [];

  for (const sheetName of wb.SheetNames) {
    if (/^~/.test(sheetName)) continue;
    const ws   = wb.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json(ws, { header: 1, defval: '' });

    // Extract month/year from inside the sheet (row 3: "Month Of May'26")
    let month = fileMonth, year = fileYear;
    for (let i = 0; i < Math.min(rows.length, 7); i++) {
      const cell = cleanStr(rows[i][0]);
      const mMatch = cell.toLowerCase();
      for (const [name, num] of Object.entries(MONTH_MAP)) {
        if (mMatch.includes(name)) { month = num; break; }
      }
      const yMatch = cell.match(/\b(20\d{2})\b/) || cell.match(/'(\d{2})\b/);
      if (yMatch) {
        year = yMatch[1].length === 2 ? 2000 + parseInt(yMatch[1]) : parseInt(yMatch[1]);
      }
    }

    // Find data header row (has "Party Name" or "Party")
    let headerRow = -1;
    for (let i = 0; i < Math.min(rows.length, 12); i++) {
      if (rows[i].some(c => /party\s*name/i.test(String(c)))) { headerRow = i; break; }
    }
    if (headerRow < 0) continue;

    const zone = sheetName.trim();
    for (let i = headerRow + 1; i < rows.length; i++) {
      const row = rows[i];
      const name = cleanStr(row[0]);
      if (!name) continue;
      if (/^total/i.test(name)) break;
      if (/^accounts\s+dept/i.test(name)) break;
      docs.push({
        month, year, zone,
        partyName:   name,
        invoiceNos:  cleanStr(row[1]),
        previousDue: toNum(row[2]),
        totalSales:  toNum(row[3]),
        commission:  toNum(row[4]),
        collectionAmount: toNum(row[5]),
        mrNo:        cleanStr(row[6]),
        cheque:      cleanStr(row[7]),
        returnGoods: toNum(row[8]),
        totalDues:   toNum(row[9]),
      });
    }
  }
  return docs;
}

// ── Upsert helper ─────────────────────────────────────────────────────────────
async function upsertMany(Model, docs, filterKeys) {
  let inserted = 0, updated = 0;
  for (const doc of docs) {
    const filter = Object.fromEntries(filterKeys.map(k => [k, doc[k]]));
    const res = await Model.updateOne(filter, { $set: doc }, { upsert: true });
    if (res.upsertedCount) inserted++;
    else if (res.modifiedCount) updated++;
  }
  return { inserted, updated };
}

// ── Main export ───────────────────────────────────────────────────────────────
async function runImport(onProgress) {
  const log = onProgress || console.log;
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI not set');

  await mongoose.connect(uri, { bufferCommands: false });
  log('✓ Connected to MongoDB');

  const { SR, PR, SDR } = getModels();
  const xlRoot = path.join(__dirname, '..', 'xldata');
  const summary = [];

  // ── Stock files ─────────────────────────────────────────────────────────
  const stockFiles = [
    ...glob(path.join(xlRoot, 'Inventory-Stock'), ['.xlsx', '.xls']),
  ];
  log(`Processing ${stockFiles.length} stock files…`);
  let stockTotal = { inserted: 0, updated: 0 };
  for (const f of stockFiles) {
    const docs = parseStockFile(f);
    const res  = await upsertMany(SR, docs, ['year','month','reportType','zone','productName','packSize']);
    stockTotal.inserted += res.inserted;
    stockTotal.updated  += res.updated;
    log(`  Stock: ${path.basename(f)} → ${docs.length} rows`);
  }
  summary.push(`Stock: ${stockTotal.inserted} inserted, ${stockTotal.updated} updated`);

  // ── Production files ─────────────────────────────────────────────────────
  const prodFiles = glob(path.join(xlRoot, 'Production'), ['.xlsx', '.xls']);
  log(`Processing ${prodFiles.length} production files…`);
  let prodTotal = { inserted: 0, updated: 0 };
  for (const f of prodFiles) {
    const docs = parseProductionFile(f);
    const res  = await upsertMany(PR, docs, ['year','month','zone','productName','packSize']);
    prodTotal.inserted += res.inserted;
    prodTotal.updated  += res.updated;
    log(`  Production: ${path.basename(f)} → ${docs.length} rows`);
  }
  summary.push(`Production: ${prodTotal.inserted} inserted, ${prodTotal.updated} updated`);

  // ── Sales dues files ─────────────────────────────────────────────────────
  const salesFiles = [
    ...glob(path.join(xlRoot, 'Sales-2025'), ['.xlsx', '.xls']),
    ...glob(path.join(xlRoot, 'Sales-2026'), ['.xlsx', '.xls']),
  ].filter(f => /^sales of /i.test(path.basename(f)));
  log(`Processing ${salesFiles.length} sales dues files…`);
  let salesTotal = { inserted: 0, updated: 0 };
  for (const f of salesFiles) {
    const docs = parseSalesFile(f);
    const res  = await upsertMany(SDR, docs, ['year','month','zone','partyName']);
    salesTotal.inserted += res.inserted;
    salesTotal.updated  += res.updated;
    log(`  Sales: ${path.basename(f)} → ${docs.length} rows`);
  }
  summary.push(`Sales Dues: ${salesTotal.inserted} inserted, ${salesTotal.updated} updated`);

  log('─'.repeat(50));
  summary.forEach(l => log(l));
  log('✓ Import complete');

  return { summary, stockTotal, prodTotal, salesTotal };
}

// Run directly
if (require.main === module) {
  runImport().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
}

module.exports = { runImport };
