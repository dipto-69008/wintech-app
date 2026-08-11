import mongoose, { Schema, Document } from 'mongoose';

export interface ISaleDetail extends Document {
  legacyId?: number;
  saleMasterId: mongoose.Types.ObjectId;
  saleMasterLegacyId?: number;
  productId?: mongoose.Types.ObjectId;
  productLegacyId?: number;
  productName?: string;
  quantity: number;
  purchaseRate?: number;
  rate: number;
  discount?: number;
  discountAmount?: number;
  tax?: number;
  totalAmount: number;
  note?: string;
  status: string;
  branchId?: number;
  isBonus?: boolean;
}

const SaleDetailSchema = new Schema<ISaleDetail>({
  legacyId: { type: Number, index: true },
  saleMasterId: { type: Schema.Types.ObjectId, ref: 'SaleMaster', required: true },
  saleMasterLegacyId: Number,
  productId: { type: Schema.Types.ObjectId, ref: 'Product' },
  productLegacyId: Number,
  productName: String,
  quantity: { type: Number, required: true },
  purchaseRate: Number,
  rate: { type: Number, required: true },
  discount: { type: Number, default: 0 },
  discountAmount: { type: Number, default: 0 },
  tax: { type: Number, default: 0 },
  totalAmount: { type: Number, required: true },
  note: String,
  status: { type: String, default: 'a' },
  branchId: Number,
  isBonus: { type: Boolean, default: false },
}, { timestamps: true });

SaleDetailSchema.index({ saleMasterId: 1 });
SaleDetailSchema.index({ saleMasterLegacyId: 1 });

export default mongoose.models.SaleDetail || mongoose.model<ISaleDetail>('SaleDetail', SaleDetailSchema);
