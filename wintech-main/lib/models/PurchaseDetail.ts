import mongoose, { Schema, Document } from 'mongoose';

export interface IPurchaseDetail extends Document {
  legacyId?: number;
  purchaseMasterId: mongoose.Types.ObjectId;
  purchaseMasterLegacyId?: number;
  productId?: mongoose.Types.ObjectId;
  productLegacyId?: number;
  productName?: string;
  quantity: number;
  rate: number;
  discount?: number;
  tax?: number;
  totalAmount: number;
  status: string;
  branchId?: number;
}

const PurchaseDetailSchema = new Schema<IPurchaseDetail>({
  legacyId: { type: Number, index: true },
  purchaseMasterId: { type: Schema.Types.ObjectId, ref: 'PurchaseMaster', required: true },
  purchaseMasterLegacyId: Number,
  productId: { type: Schema.Types.ObjectId, ref: 'Product' },
  productLegacyId: Number,
  productName: String,
  quantity: { type: Number, required: true },
  rate: { type: Number, required: true },
  discount: { type: Number, default: 0 },
  tax: { type: Number, default: 0 },
  totalAmount: { type: Number, required: true },
  status: { type: String, default: 'a' },
  branchId: Number,
}, { timestamps: true });

PurchaseDetailSchema.index({ purchaseMasterId: 1 });
PurchaseDetailSchema.index({ purchaseMasterLegacyId: 1 });

export default mongoose.models.PurchaseDetail || mongoose.model<IPurchaseDetail>('PurchaseDetail', PurchaseDetailSchema);
