import mongoose, { Schema, Document } from 'mongoose';

export interface IPurchaseMaster extends Document {
  legacyId?: number;
  supplierId?: mongoose.Types.ObjectId;
  supplierLegacyId?: number;
  supplierName?: string;
  employeeId?: number;
  invoiceNo: string;
  orderDate: Date;
  purchaseFor?: string;
  description?: string;
  totalAmount: number;
  discountAmount: number;
  tax: number;
  freight: number;
  subTotal: number;
  paidAmount: number;
  dueAmount: number;
  previousDue?: number;
  status: string;
  branchId?: number;
  addBy?: string;
  addTime?: Date;
}

const PurchaseMasterSchema = new Schema<IPurchaseMaster>({
  legacyId: { type: Number, index: true },
  supplierId: { type: Schema.Types.ObjectId, ref: 'Supplier' },
  supplierLegacyId: Number,
  supplierName: String,
  employeeId: Number,
  invoiceNo: { type: String, required: true, trim: true },
  orderDate: { type: Date, required: true },
  purchaseFor: String,
  description: String,
  totalAmount: { type: Number, required: true, default: 0 },
  discountAmount: { type: Number, default: 0 },
  tax: { type: Number, default: 0 },
  freight: { type: Number, default: 0 },
  subTotal: { type: Number, required: true, default: 0 },
  paidAmount: { type: Number, default: 0 },
  dueAmount: { type: Number, default: 0 },
  previousDue: Number,
  status: { type: String, default: 'a' },
  branchId: Number,
  addBy: String,
  addTime: Date,
}, { timestamps: true });

PurchaseMasterSchema.index({ invoiceNo: 1 });
PurchaseMasterSchema.index({ orderDate: -1 });

export default mongoose.models.PurchaseMaster || mongoose.model<IPurchaseMaster>('PurchaseMaster', PurchaseMasterSchema);
