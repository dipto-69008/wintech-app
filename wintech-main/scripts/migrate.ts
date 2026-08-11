import fs from 'fs';
import path from 'path';
import readline from 'readline';
import Product from '@/models/Product';
import Party from '@/models/Party';
import Supplier from '@/models/Supplier';
import Employee from '@/models/Employee';
import SaleMaster from '@/models/SaleMaster';
import SaleDetail from '@/models/SaleDetail';
import PurchaseMaster from '@/models/PurchaseMaster';
import PurchaseDetail from '@/models/PurchaseDetail';
import Account from '@/models/Account';
import Category from '@/models/Category';
import Brand from '@/models/Brand';
import Unit from '@/models/Unit';
import Department from '@/models/Department';
import Designation from '@/models/Designation';
import Branch from '@/models/Branch';

const SQL_FILE = path.join(process.cwd(), 'my_db_backup.sql');

type Row = Record<string, string | null>;

function parseInsertLine(line: string): { table: string; rows: Row[] } | null {
  const match = line.match(/^INSERT INTO `(\w+)` \(`([^`]+(?:`, `[^`]+)*)`\) VALUES (.+);/i);
  if (!match) return null;
  const table = match[1];
  const cols = match[2].split('`, `');
  const valuesPart = match[3];

  const rows: Row[] = [];
  const rowRegex = /\(([^)]*(?:\([^)]*\)[^)]*)*)\)/g;
  let m: RegExpExecArray | null;
  while ((m = rowRegex.exec(valuesPart)) !== null) {
    const rawVals = splitValues(m[1]);
    const row: Row = {};
    cols.forEach((col, i) => {
      const v = rawVals[i] ?? null;
      row[col] = v === 'NULL' ? null : v?.replace(/^'(.*)'$/s, '$1').replace(/\\'/g, "'").replace(/\\\\/g, '\\') ?? null;
    });
    rows.push(row);
  }
  return { table, rows };
}

function splitValues(str: string): string[] {
  const vals: string[] = [];
  let cur = '';
  let inStr = false;
  let i = 0;
  while (i < str.length) {
    const ch = str[i];
    if (ch === "'" && !inStr) { inStr = true; cur += ch; i++; continue; }
    if (ch === "'" && inStr && str[i - 1] !== '\\') { inStr = false; cur += ch; i++; continue; }
    if (ch === ',' && !inStr) { vals.push(cur.trim()); cur = ''; i++; continue; }
    cur += ch; i++;
  }
  if (cur.trim()) vals.push(cur.trim());
  return vals;
}

function toNum(v: string | null): number { return v ? parseFloat(v) || 0 : 0; }
function toDate(v: string | null): Date | undefined { if (!v) return undefined; const d = new Date(v); return isNaN(d.getTime()) ? undefined : d; }
function toInt(v: string | null): number | undefined { if (!v) return undefined; const n = parseInt(v); return isNaN(n) ? undefined : n; }

const BATCH = 200;
async function batchInsert<T>(Model: { insertMany: (docs: T[], opts?: Record<string, unknown>) => Promise<unknown> }, docs: T[]) {
  for (let i = 0; i < docs.length; i += BATCH) {
    await Model.insertMany(docs.slice(i, i + BATCH), { ordered: false });
  }
}

type MigrateResult = Record<string, { inserted: number; skipped: number; error?: string }>;

async function processTable(table: string, rows: Row[], result: MigrateResult) {
  try {
    if (table === 'tbl_product') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Product_SlNo']),
        code: r['Product_Code'] || `P${r['Product_SlNo']}`,
        name: r['Product_Name'] || 'Unknown',
        categoryName: undefined,
        color: r['color'] || undefined,
        brand: r['brand'] || undefined,
        size: r['size'] !== 'na' ? r['size'] || undefined : undefined,
        vat: toNum(r['vat']),
        reorderLevel: toInt(r['Product_ReOrederLevel']),
        purchaseRate: toNum(r['Product_Purchase_Rate']),
        sellingPrice: toNum(r['Product_SellingPrice']),
        minSellingPrice: toNum(r['Product_MinimumSellingPrice']),
        wholesaleRate: toNum(r['Product_WholesaleRate']),
        oneCartonEqual: r['one_cartun_equal'] || undefined,
        isService: r['is_service'] === 'true',
        status: r['status'] || 'a',
        branchId: toInt(r['product_branchid']),
        addBy: r['AddBy'] || undefined,
        addTime: toDate(r['AddTime']),
      }));
      await batchInsert(Product, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_party') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Party_SlNo']),
        code: r['Party_Code'] || `C${r['Party_SlNo']}`,
        name: r['Party_Name'] || 'Unknown',
        type: r['Party_Type'] || undefined,
        phone: r['Party_Phone'] || undefined,
        mobile: r['Party_Mobile'] || undefined,
        contactPerson: r['contact_person'] || undefined,
        email: r['Party_Email'] || undefined,
        officePhone: r['Party_OfficePhone'] || undefined,
        address: r['Party_Address'] || undefined,
        ownerName: r['owner_name'] || undefined,
        web: r['Party_Web'] || undefined,
        creditLimit: toNum(r['Party_Credit_Limit']),
        previousDue: toNum(r['previous_due']),
        status: r['status'] || 'a',
        branchId: toInt(r['Party_branchid']),
        employeeId: toInt(r['Employee_SlNo']),
        addBy: r['AddBy'] || undefined,
        addTime: toDate(r['AddTime']),
      }));
      await batchInsert(Party, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_supplier') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Supplier_SlNo']),
        code: r['Supplier_Code'] || `S${r['Supplier_SlNo']}`,
        name: r['Supplier_Name'] || 'Unknown',
        type: r['Supplier_Type'] || undefined,
        phone: r['Supplier_Phone'] || undefined,
        mobile: r['Supplier_Mobile'] || undefined,
        email: r['Supplier_Email'] || undefined,
        officePhone: r['Supplier_OfficePhone'] || undefined,
        address: r['Supplier_Address'] || undefined,
        contactPerson: r['contact_person'] || undefined,
        web: r['Supplier_Web'] || undefined,
        previousDue: toNum(r['previous_due']),
        status: r['status'] || 'a',
        addBy: r['AddBy'] || undefined,
        addTime: toDate(r['AddTime']),
      }));
      await batchInsert(Supplier, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_employee') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Employee_SlNo']),
        designationId: toInt(r['Designation_ID']),
        departmentId: toInt(r['Department_ID']),
        employeeCode: r['Employee_ID'] || `EMP${r['Employee_SlNo']}`,
        name: r['Employee_Name'] || 'Unknown',
        joinDate: toDate(r['Employee_JoinDate']),
        gender: r['Employee_Gender'] || undefined,
        birthDate: toDate(r['Employee_BirthDate']),
        nid: r['Employee_NID'] || undefined,
        contactNo: r['Employee_ContactNo'] || undefined,
        email: r['Employee_Email'] || undefined,
        maritalStatus: r['Employee_MaritalStatus'] || undefined,
        fatherName: r['Employee_FatherName'] || undefined,
        motherName: r['Employee_MotherName'] || undefined,
        presentAddress: r['Employee_PrasentAddress'] || undefined,
        permanentAddress: r['Employee_PermanentAddress'] || undefined,
        salary: toNum(r['Salary']),
        bankAccountNo: r['Bank_Account_No'] || undefined,
        bankName: r['Bank_Name'] || undefined,
        status: r['status'] || 'a',
        branchId: toInt(r['employee_branchid']),
        addBy: r['AddBy'] || undefined,
        addTime: toDate(r['AddTime']),
      }));
      await batchInsert(Employee, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_salesmaster') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['SaleMaster_SlNo']),
        invoiceNo: r['SaleMaster_InvoiceNo'] || `INV${r['SaleMaster_SlNo']}`,
        partyLegacyId: toInt(r['SalseParty_IDNo']),
        employeeId: toInt(r['employee_id']),
        saleDate: toDate(r['SaleMaster_SaleDate']) || new Date(),
        description: r['SaleMaster_Description'] || undefined,
        saleType: r['SaleMaster_SaleType'] || undefined,
        paymentType: r['payment_type'] || 'Cash',
        totalAmount: toNum(r['SaleMaster_TotalSaleAmount']),
        discountAmount: toNum(r['SaleMaster_TotalDiscountAmount']),
        taxAmount: toNum(r['SaleMaster_TaxAmount']),
        freight: toNum(r['SaleMaster_Freight']),
        subTotal: toNum(r['SaleMaster_SubTotalAmount']),
        paidAmount: toNum(r['SaleMaster_PaidAmount']),
        dueAmount: toNum(r['SaleMaster_DueAmount']),
        previousDue: toNum(r['SaleMaster_Previous_Due']),
        status: r['Status'] || 'a',
        isService: r['is_service'] === 'true',
        isOrder: r['is_order'] || undefined,
        branchId: toInt(r['SaleMaster_branchid']),
        addBy: r['AddBy'] || undefined,
        addTime: toDate(r['AddTime']),
      }));
      await batchInsert(SaleMaster, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_saledetails') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['SaleDetails_SlNo']),
        saleMasterLegacyId: toInt(r['SaleMaster_IDNo']),
        productLegacyId: toInt(r['Product_IDNo']),
        quantity: toNum(r['SaleDetails_TotalQuantity']),
        purchaseRate: toNum(r['Purchase_Rate']),
        rate: toNum(r['SaleDetails_Rate']),
        discount: toNum(r['SaleDetails_Discount']),
        discountAmount: toNum(r['Discount_amount']),
        tax: toNum(r['SaleDetails_Tax']),
        totalAmount: toNum(r['SaleDetails_TotalAmount']),
        note: r['note'] || undefined,
        status: r['Status'] || 'a',
        branchId: toInt(r['SaleDetails_BranchId']),
        saleMasterId: new (require('mongoose').Types.ObjectId)(),
      }));
      await batchInsert(SaleDetail, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_purchasemaster') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['PurchaseMaster_SlNo']),
        supplierLegacyId: toInt(r['Supplier_SlNo']),
        employeeId: toInt(r['Employee_SlNo']),
        invoiceNo: r['PurchaseMaster_InvoiceNo'] || `PO${r['PurchaseMaster_SlNo']}`,
        orderDate: toDate(r['PurchaseMaster_OrderDate']) || new Date(),
        purchaseFor: r['PurchaseMaster_PurchaseFor'] || undefined,
        description: r['PurchaseMaster_Description'] || undefined,
        totalAmount: toNum(r['PurchaseMaster_TotalAmount']),
        discountAmount: toNum(r['PurchaseMaster_DiscountAmount']),
        tax: toNum(r['PurchaseMaster_Tax']),
        freight: toNum(r['PurchaseMaster_Freight']),
        subTotal: toNum(r['PurchaseMaster_SubTotalAmount']),
        paidAmount: toNum(r['PurchaseMaster_PaidAmount']),
        dueAmount: toNum(r['PurchaseMaster_DueAmount']),
        previousDue: toNum(r['previous_due']),
        status: r['status'] || 'a',
        addBy: r['AddBy'] || undefined,
        addTime: toDate(r['AddTime']),
      }));
      await batchInsert(PurchaseMaster, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_purchasedetails') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['PurchaseDetails_SlNo']),
        purchaseMasterLegacyId: toInt(r['PurchaseMaster_IDNo']),
        productLegacyId: toInt(r['Product_IDNo']),
        quantity: toNum(r['PurchaseDetails_TotalQuantity']),
        rate: toNum(r['PurchaseDetails_Rate']),
        discount: toNum(r['PurchaseDetails_Discount']),
        tax: toNum(r['PurchaseDetails_Tax']),
        totalAmount: toNum(r['PurchaseDetails_TotalAmount']),
        status: r['Status'] || 'a',
        branchId: toInt(r['PurchaseDetails_BranchId']),
        purchaseMasterId: new (require('mongoose').Types.ObjectId)(),
      }));
      await batchInsert(PurchaseDetail, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_account') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Acc_SlNo']),
        branchId: toInt(r['branch_id']),
        code: r['Acc_Code'] || `A${r['Acc_SlNo']}`,
        transactionType: r['Acc_Tr_Type'] || undefined,
        name: r['Acc_Name'] || 'Unknown',
        type: r['Acc_Type'] || undefined,
        description: r['Acc_Description'] || undefined,
        status: r['status'] || 'a',
        addBy: r['AddBy'] || undefined,
        addTime: toDate(r['AddTime']),
      }));
      await batchInsert(Account, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_productcategory') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['ProductCategory_SlNo']),
        groupId: toInt(r['group_id']),
        name: r['ProductCategory_Name'] || 'Unknown',
        description: r['ProductCategory_Description'] || undefined,
        status: r['status'] || 'a',
        branchId: toInt(r['category_branchid']),
        addBy: r['AddBy'] || undefined,
      }));
      await batchInsert(Category, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_brand') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Brand_SlNo']),
        name: r['Brand_Name'] || 'Unknown',
        status: r['status'] || 'a',
        branchId: toInt(r['brand_branchid']),
        addBy: r['AddBy'] || undefined,
      }));
      await batchInsert(Brand, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_unit') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Unit_SlNo']),
        name: r['Unit_Name'] || 'Unknown',
        status: r['status'] || 'a',
        addBy: r['AddBy'] || undefined,
      }));
      await batchInsert(Unit, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_department') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Department_SlNo']),
        name: r['Department_Name'] || 'Unknown',
        status: r['status'] || 'a',
        addBy: r['AddBy'] || undefined,
      }));
      await batchInsert(Department, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_designation') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Designation_SlNo']),
        name: r['Designation_Name'] || 'Unknown',
        status: r['status'] || 'a',
        addBy: r['AddBy'] || undefined,
      }));
      await batchInsert(Designation, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    } else if (table === 'tbl_brunch') {
      const docs = rows.map(r => ({
        legacyId: toInt(r['Branch_SlNo']),
        name: r['Branch_Name'] || 'Unknown',
        address: r['Branch_Address'] || undefined,
        phone: r['Branch_Phone'] || undefined,
        status: r['status'] || 'a',
        addBy: r['AddBy'] || undefined,
      }));
      await batchInsert(Branch, docs);
      result[table] = { inserted: docs.length, skipped: 0 };
    }
  } catch (err: unknown) {
    result[table] = { inserted: 0, skipped: 0, error: err instanceof Error ? err.message : String(err) };
  }
}

const SUPPORTED_TABLES = [
  'tbl_product', 'tbl_party', 'tbl_supplier', 'tbl_employee',
  'tbl_salesmaster', 'tbl_saledetails', 'tbl_purchasemaster', 'tbl_purchasedetails',
  'tbl_account', 'tbl_productcategory', 'tbl_brand', 'tbl_unit',
  'tbl_department', 'tbl_designation', 'tbl_brunch',
];

export async function runMigration(tables: string[] = []): Promise<MigrateResult> {
  const tablesToRun = (tables.length === 0 || tables.includes('all')) ? SUPPORTED_TABLES : tables;
  const result: MigrateResult = {};
  const buffers: Record<string, Row[]> = {};
  let currentTable = '';

  if (!fs.existsSync(SQL_FILE)) {
    throw new Error(`SQL file not found: ${SQL_FILE}`);
  }

  const rl = readline.createInterface({ input: fs.createReadStream(SQL_FILE), crlfDelay: Infinity });

  for await (const line of rl) {
    const trimmed = line.trim();
    if (trimmed.startsWith('# TABLE STRUCTURE FOR:')) {
      currentTable = trimmed.replace('# TABLE STRUCTURE FOR:', '').trim();
    }
    if (!currentTable || !tablesToRun.includes(currentTable)) continue;
    if (!trimmed.toUpperCase().startsWith('INSERT INTO')) continue;

    const parsed = parseInsertLine(trimmed);
    if (!parsed) continue;
    if (!buffers[parsed.table]) buffers[parsed.table] = [];
    buffers[parsed.table].push(...parsed.rows);
  }

  for (const [table, rows] of Object.entries(buffers)) {
    await processTable(table, rows, result);
  }

  return result;
}
