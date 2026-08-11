import mongoose, { Schema, Document } from 'mongoose';

export interface IStockReport extends Document {
  month: number;
  year: number;
  reportType: 'company' | 'branch';
  zone?: string;
  productName: string;
  packSize: string;
  // company-wide columns
  cumillaStock?: number;
  mymensinghStock?: number;
  bograStock?: number;
  jessoreStock?: number;
  feniStock?: number;
  totalQuantity?: number;
  // branch-level columns
  previousStock?: number;
  receivedQty?: number;
  returnQty?: number;
  transferQty?: number;
  salesQty?: number;
  bonusQty?: number;
  presentBalance?: number;
  remarks?: string;
  // new fields
  expiryDate?: Date;
  damageQty?: number;
}

const StockReportSchema = new Schema<IStockReport>({
  month:           { type: Number, required: true },
  year:            { type: Number, required: true },
  reportType:      { type: String, enum: ['company', 'branch'], default: 'company' },
  zone:            String,
  productName:     { type: String, required: true, trim: true },
  packSize:        { type: String, trim: true, default: '' },
  cumillaStock:    Number,
  mymensinghStock: Number,
  bograStock:      Number,
  jessoreStock:    Number,
  feniStock:       Number,
  totalQuantity:   Number,
  previousStock:   Number,
  receivedQty:     Number,
  returnQty:       Number,
  transferQty:     Number,
  salesQty:        Number,
  bonusQty:        Number,
  presentBalance:  Number,
  remarks:         String,
  expiryDate:      { type: Date },
  damageQty:       { type: Number, default: 0 },
}, { timestamps: true });

StockReportSchema.index({ year: 1, month: 1, reportType: 1, zone: 1, productName: 1, packSize: 1 }, { unique: true });

export default mongoose.models.StockReport || mongoose.model<IStockReport>('StockReport', StockReportSchema);
