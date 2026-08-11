/**
 * json-to-mongo.js — Loads a normalized monthly-sales JSON (produced by xl-to-json.js)
 * and upserts it into MongoDB across four collections:
 *   - branches   (one per sheet; nickname = sheet tab name, zoneCode = raw "Zone-…" text)
 *   - employees  (Assigned Officer → Employee with designation "SR"; skipped if blank/"Mr.")
 *   - targets    (one per branch per month, module "sales")
 *   - parties + salesdueureports (one Party per unique party name, one dues row per branch/month/party)
 *
 * Safe to re-run: every write is an upsert keyed on natural business keys, so running
 * the same month twice (or re-importing a corrected file) will not create duplicates.
 *
 * Usage:
 *   node scripts/json-to-mongo.js data/imports/2026-05-sales.json
 *   node scripts/json-to-mongo.js                (uses the newest file in data/imports/)
 */
'use strict';

const path = require('path');
const fs = require('fs');
const mongoose = require('mongoose');

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

const Schema = mongoose.Schema;

const BranchSchema = new Schema({
  legacyId: Number, name: { type: String, required: true, trim: true },
  nickname: String, zoneCode: String, address: String, phone: String,
  manager: String, status: { type: String, default: 'a' }, addBy: String,
}, { timestamps: true });
const Branch = mongoose.models.Branch || mongoose.model('Branch', BranchSchema);

const EmployeeSchema = new Schema({
  legacyId: Number, designationId: Number, departmentId: Number,
  employeeCode: { type: String, required: true, trim: true },
  name: { type: String, required: true, trim: true },
  joinDate: Date, gender: String, birthDate: Date, nid: String, contactNo: String,
  email: String, maritalStatus: String, fatherName: String, motherName: String,
  presentAddress: String, permanentAddress: String, salary: { type: Number, default: 0 },
  bankAccountNo: String, bankName: String, status: { type: String, default: 'a' },
  branchId: Number, designation: String, department: String, addBy: String, addTime: Date,
}, { timestamps: true });
const Employee = mongoose.models.Employee || mongoose.model('Employee', EmployeeSchema);

const TargetSchema = new Schema({
  title: { type: String, required: true }, module: { type: String, required: true },
  assignedTo: String, targetValue: { type: Number, default: 0 }, currentValue: { type: Number, default: 0 },
  unit: { type: String, default: 'BDT' }, deadline: String,
  status: { type: String, enum: ['on-track', 'at-risk', 'completed', 'overdue'], default: 'on-track' },
}, { timestamps: true });
const Target = mongoose.models.Target || mongoose.model('Target', TargetSchema);

const PartySchema = new Schema({
  legacyId: Number, code: { type: String, required: true, trim: true },
  name: { type: String, required: true, trim: true }, type: String, phone: String, mobile: String,
  contactPerson: String, email: String, officePhone: String, address: String, ownerName: String,
  area: String, web: String, creditLimit: { type: Number, default: 0 }, previousDue: { type: Number, default: 0 },
  status: { type: String, default: 'a' }, branchId: Number, employeeId: Number, addBy: String, addTime: Date,
}, { timestamps: true });
const Party = mongoose.models.Party || mongoose.model('Party', PartySchema, 'parties');

const SalesDuesReportSchema = new Schema({
  month: { type: Number, required: true }, year: { type: Number, required: true },
  zone: { type: String, required: true, trim: true }, partyName: { type: String, required: true, trim: true },
  invoiceNos: String, previousDue: { type: Number, default: 0 }, totalSales: { type: Number, default: 0 },
  commission: { type: Number, default: 0 }, collectionAmount: { type: Number, default: 0 },
  mrNo: String, cheque: String, returnGoods: { type: Number, default: 0 }, totalDues: { type: Number, default: 0 },
}, { timestamps: true });
SalesDuesReportSchema.index({ year: 1, month: 1, zone: 1, partyName: 1 }, { unique: true });
const SalesDuesReport = mongoose.models.SalesDuesReport || mongoose.model('SalesDuesReport', SalesDuesReportSchema);

function findLatestJsonFile() {
  const dir = path.join(__dirname, '..', 'data', 'imports');
  if (!fs.existsSync(dir)) return null;
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.json')).map(f => path.join(dir, f));
  if (!files.length) return null;
  files.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
  return files[0];
}

function slugCode(name) {
  return String(name).toUpperCase().replace(/[^A-Z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 30) || 'PARTY';
}

function isPlaceholderOfficer(name) {
  if (!name) return true;
  const t = name.trim().replace(/\.$/, '').trim();
  return !t || /^(mr|mrs|ms|md)$/i.test(t);
}

function monthEndDate(year, month) {
  return new Date(Date.UTC(year, month, 0)).toISOString().slice(0, 10);
}

async function upsertBranch(b) {
  const name = b.branchNickname;
  const doc = await Branch.findOneAndUpdate(
    { name },
    { $set: { name, nickname: b.zoneCode ? b.zoneCode.split(',')[0].replace(/\(.*/, '').trim() || name : name, zoneCode: b.zoneCode, status: 'a' } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  return doc;
}

async function upsertOfficer(officerName) {
  if (isPlaceholderOfficer(officerName)) return null;
  const name = officerName.trim();
  const employeeCode = 'OFF-' + slugCode(name).slice(0, 20);
  const doc = await Employee.findOneAndUpdate(
    { name },
    { $setOnInsert: { employeeCode, status: 'a' }, $set: { designation: 'SR' } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  return doc;
}

async function upsertTarget(branch, b, officerDoc) {
  const title = `${branch.name} Sales Target - ${b.month}/${b.year}`;
  await Target.findOneAndUpdate(
    { title, module: 'sales' },
    {
      $set: {
        assignedTo: officerDoc ? officerDoc.name : (b.assignedOfficer || ''),
        targetValue: b.target,
        currentValue: b.parties.reduce((a, p) => a + (p.totalSales || 0), 0),
        unit: 'BDT',
        deadline: monthEndDate(b.year, b.month),
      },
    },
    { upsert: true }
  );
}

async function upsertPartyAndDues(branch, b, party) {
  const name = party.partyName.trim();
  const partyDoc = await Party.findOneAndUpdate(
    { name },
    {
      $setOnInsert: { code: slugCode(name), status: 'a' },
      $set: { previousDue: party.totalDues, branchId: branch.legacyId },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  await SalesDuesReport.updateOne(
    { year: b.year, month: b.month, zone: branch.name, partyName: name },
    {
      $set: {
        invoiceNos: party.invoiceNos,
        previousDue: party.previousDue,
        totalSales: party.totalSales,
        commission: party.commission,
        collectionAmount: party.collectionAmount,
        mrNo: party.mrNo,
        cheque: party.cheque,
        returnGoods: party.returnGoods,
        totalDues: party.totalDues,
      },
    },
    { upsert: true }
  );

  return partyDoc;
}

async function importData(data) {
  let branchCount = 0, officerCount = 0, partyCount = 0, duesCount = 0;

  for (const b of data.branches) {
    const branch = await upsertBranch(b);
    branchCount++;

    const officerDoc = await upsertOfficer(b.assignedOfficer);
    if (officerDoc) officerCount++;

    await upsertTarget(branch, b, officerDoc);

    for (const party of b.parties) {
      await upsertPartyAndDues(branch, b, party);
      partyCount++;
      duesCount++;
    }

    console.log(`  ✓ ${b.branchNickname} — ${b.parties.length} parties, target ৳${b.target.toLocaleString()}, officer: ${b.assignedOfficer || '(none)'}`);
  }

  return { branchCount, officerCount, partyCount, duesCount };
}

async function main() {
  if (!process.env.MONGODB_URI) {
    console.error('MONGODB_URI not set. Add it to .env.local or Replit Secrets.');
    process.exit(1);
  }

  const inputArg = process.argv[2];
  const jsonPath = inputArg ? path.resolve(inputArg) : findLatestJsonFile();
  if (!jsonPath || !fs.existsSync(jsonPath)) {
    console.error('No JSON file found. Run xl-to-json.js first, or pass a path.');
    process.exit(1);
  }

  const data = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
  console.log(`Importing: ${jsonPath} (${data.month}/${data.year}, ${data.branches.length} branches)`);

  await mongoose.connect(process.env.MONGODB_URI);
  console.log('✓ Connected to MongoDB');

  const stats = await importData(data);

  console.log(`\nDone. Branches: ${stats.branchCount}, Officers: ${stats.officerCount}, Party rows: ${stats.partyCount}, Dues records: ${stats.duesCount}`);
  process.exit(0);
}

if (require.main === module) main().catch(e => { console.error(e); process.exit(1); });

module.exports = { importData };
