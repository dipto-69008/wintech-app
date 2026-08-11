import mongoose, { Schema, Document } from 'mongoose';

export interface IStockTransfer extends Document {
  productId?: mongoose.Types.ObjectId;
  productName: string;
  packSize?: string;
  fromBranch: string;
  toBranch: string;
  quantity: number;
  weightGram?: number;
  weightUnit?: 'g' | 'ml';
  pcsCount?: number;
  transferredBy?: string;
  notes?: string;
  date: Date;
  time?: string;
  tags?: string[];
}

const StockTransferSchema = new Schema<IStockTransfer>({
  productId:     { type: Schema.Types.ObjectId, ref: 'Product' },
  productName:   { type: String, required: true, trim: true },
  packSize:      { type: String, trim: true, default: '' },
  fromBranch:    { type: String, required: true, trim: true },
  toBranch:      { type: String, required: true, trim: true },
  quantity:      { type: Number, required: true },
  weightGram:    { type: Number },
  weightUnit:    { type: String, enum: ['g', 'ml'] },
  pcsCount:      { type: Number },
  transferredBy: { type: String, trim: true },
  notes:         { type: String, trim: true },
  date:          { type: Date, default: Date.now },
  time:          { type: String, trim: true },
  tags:          [{ type: String, trim: true }],
}, { timestamps: true });

StockTransferSchema.index({ productName: 1, date: -1 });
StockTransferSchema.index({ fromBranch: 1 });
StockTransferSchema.index({ toBranch: 1 });

export default mongoose.models.StockTransfer
  || mongoose.model<IStockTransfer>('StockTransfer', StockTransferSchema);
