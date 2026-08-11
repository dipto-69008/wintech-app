import mongoose from 'mongoose';
import { readFileSync } from 'fs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const XLSX = require('xlsx');

const env = readFileSync('.env.local', 'utf8');
const MONGODB_URI = env.match(/MONGODB_URI=(.+)/)?.[1]?.trim();
if (!MONGODB_URI) { console.error('No MONGODB_URI'); process.exit(1); }

const ProductSchema = new mongoose.Schema({
  code: String, name: String, packSize: String,
  purchaseRate: { type: Number, default: 0 },
  sellingPrice: { type: Number, default: 0 },
  unit: String, status: { type: String, default: 'a' },
}, { timestamps: true });
const Product = mongoose.models.Product || mongoose.model('Product', ProductSchema);

// Read price list
const wb = XLSX.readFile('attached_assets/Price_List-1_1784956770910.xlsx');
const ws = wb.Sheets[wb.SheetNames[0]];
const rows = XLSX.utils.sheet_to_json(ws, { header: 1 });

// Parse valid rows (SL NO is a number, product name exists, TP > 0)
const priceList = rows
  .filter(r => typeof r[0] === 'number' && r[1] && r[3] > 0)
  .map(r => ({
    name: String(r[1]).trim(),
    packSize: String(r[2]).trim(),
    tp: Number(r[3]),
  }));

console.log(`\nPrice list loaded: ${priceList.length} products`);
priceList.forEach(p => console.log(`  ${p.name} ${p.packSize} → ৳${p.tp}`));

await mongoose.connect(MONGODB_URI);
console.log('\nConnected to MongoDB');

// Fetch all products from DB
const allProducts = await Product.find({}).lean();
console.log(`\nDB has ${allProducts.length} products`);

let updated = 0, notFound = 0;
const missed = [];

for (const pl of priceList) {
  // Normalise strings for fuzzy matching
  const normName = (s) => s.toLowerCase().replace(/[\s\-\(\)\.]/g, '');
  const normSize = (s) => s.toLowerCase().replace(/[\s]/g, '').replace('kg','kg').replace('gm','gm').replace('ml','ml');

  const match = allProducts.find(p => {
    const nameMatch = normName(p.name || '') === normName(pl.name);
    const sizeMatch = normSize(p.packSize || '') === normSize(pl.packSize);
    return nameMatch && sizeMatch;
  });

  if (match) {
    await Product.updateOne({ _id: match._id }, { $set: { sellingPrice: pl.tp } });
    console.log(`✓ Updated: ${pl.name} ${pl.packSize} → ৳${pl.tp}  (was ৳${match.sellingPrice})`);
    updated++;
  } else {
    // Try name-only match (ignore packSize difference in casing/format)
    const nameOnly = allProducts.filter(p => normName(p.name || '') === normName(pl.name));
    if (nameOnly.length > 0) {
      console.log(`⚠ Name matched but packSize mismatch for "${pl.name}" "${pl.packSize}" — DB has: ${nameOnly.map(p => `"${p.packSize}"`).join(', ')}`);
    }
    missed.push(`${pl.name} ${pl.packSize}`);
    notFound++;
  }
}

console.log(`\n✅ Updated: ${updated}`);
if (missed.length) {
  console.log(`❌ Not found in DB (${notFound}):`);
  missed.forEach(m => console.log(`   - ${m}`));
}

// Show all DB products with their current sellingPrice
console.log('\n── All DB products after update ──');
const refreshed = await Product.find({}).sort({ name: 1 }).lean();
refreshed.forEach(p => {
  const flag = p.sellingPrice > 0 ? '✓' : '✗';
  console.log(`  ${flag} ${p.name} ${p.packSize || ''} → ৳${p.sellingPrice}`);
});

await mongoose.disconnect();
console.log('\nDone.');
