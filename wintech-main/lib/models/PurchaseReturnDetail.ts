import mongoose, { Schema, Document } from 'mongoose';

export interface IPurchaseReturnDetail extends Document {
  purchaseReturnId: mongoose.Types.ObjectId;
  productId?: mongoose.Types.ObjectId;
  productName: string;
  productCode?: string;
  quantity: number;
  rate: number;
  discount: number;
  totalAmount: number;
  status: string;
}

const PurchaseReturnDetailSchema = new Schema<IPurchaseReturnDetail>({
  purchaseReturnId: { type: Schema.Types.ObjectId, ref: 'PurchaseReturn', required: true, index: true },
  productId: { type: Schema.Types.ObjectId, ref: 'Product' },
  productName: { type: String, required: true },
  productCode: String,
  quantity: { type: Number, default: 1 },
  rate: { type: Number, default: 0 },
  discount: { type: Number, default: 0 },
  totalAmount: { type: Number, default: 0 },
  status: { type: String, default: 'a' },
}, { timestamps: true });

export default mongoose.models.PurchaseReturnDetail || mongoose.model<IPurchaseReturnDetail>('PurchaseReturnDetail', PurchaseReturnDetailSchema);
