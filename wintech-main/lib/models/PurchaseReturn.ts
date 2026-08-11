import mongoose, { Schema, Document } from 'mongoose';

export interface IPurchaseReturn extends Document {
  legacyId?: number;
  returnNo: string;
  purchaseMasterId?: mongoose.Types.ObjectId;
  purchaseInvoiceNo?: string;
  supplierId?: mongoose.Types.ObjectId;
  supplierName?: string;
  returnDate: Date;
  totalAmount: number;
  discountAmount: number;
  subTotal: number;
  reason?: string;
  status: string;
  addBy?: string;
  addTime?: Date;
}

const PurchaseReturnSchema = new Schema<IPurchaseReturn>({
  legacyId: { type: Number, index: true },
  returnNo: { type: String, required: true, trim: true },
  purchaseMasterId: { type: Schema.Types.ObjectId, ref: 'PurchaseMaster' },
  purchaseInvoiceNo: String,
  supplierId: { type: Schema.Types.ObjectId, ref: 'Supplier' },
  supplierName: String,
  returnDate: { type: Date, required: true },
  totalAmount: { type: Number, default: 0 },
  discountAmount: { type: Number, default: 0 },
  subTotal: { type: Number, default: 0 },
  reason: String,
  status: { type: String, default: 'a' },
  addBy: String,
  addTime: Date,
}, { timestamps: true });

PurchaseReturnSchema.index({ returnNo: 1 });
PurchaseReturnSchema.index({ returnDate: -1 });

export default mongoose.models.PurchaseReturn || mongoose.model<IPurchaseReturn>('PurchaseReturn', PurchaseReturnSchema);
