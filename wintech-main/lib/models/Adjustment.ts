import mongoose, { Schema, Document } from 'mongoose';

export interface IAdjustment extends Document {
  productId: mongoose.Types.ObjectId;
  productName: string;
  productCode?: string;
  type: 'add' | 'remove';
  quantity: number;
  reason: string;
  previousStock: number;
  newStock: number;
  adjustedBy?: string;
  date: Date;
}

const AdjustmentSchema = new Schema<IAdjustment>({
  productId: { type: Schema.Types.ObjectId, ref: 'Product', required: true },
  productName: { type: String, required: true },
  productCode: String,
  type: { type: String, enum: ['add', 'remove'], required: true },
  quantity: { type: Number, required: true },
  reason: { type: String, required: true },
  previousStock: { type: Number, required: true },
  newStock: { type: Number, required: true },
  adjustedBy: String,
  date: { type: Date, default: Date.now },
}, { timestamps: true });

export default mongoose.models.Adjustment || mongoose.model<IAdjustment>('Adjustment', AdjustmentSchema);
