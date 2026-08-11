import mongoose, { Schema, Document } from 'mongoose';

export interface IProductionReport extends Document {
  month: number;
  year: number;
  zone: string;
  productName: string;
  packSize: string;
  previousBalanceKg: number;
  receivedKg: number;
  totalKg: number;
  totalProductPcs: number;
  pcsTransfer: number;
  convertKg: number;
  totalConvertKg: number;
  wastageKg: number;
  presentBalanceKg: number;
  remarks?: string;
}

const ProductionReportSchema = new Schema<IProductionReport>({
  month:              { type: Number, required: true },
  year:               { type: Number, required: true },
  zone:               { type: String, default: 'Cumilla' },
  productName:        { type: String, required: true, trim: true },
  packSize:           { type: String, trim: true, default: '' },
  previousBalanceKg:  { type: Number, default: 0 },
  receivedKg:         { type: Number, default: 0 },
  totalKg:            { type: Number, default: 0 },
  totalProductPcs:    { type: Number, default: 0 },
  pcsTransfer:        { type: Number, default: 0 },
  convertKg:          { type: Number, default: 0 },
  totalConvertKg:     { type: Number, default: 0 },
  wastageKg:          { type: Number, default: 0 },
  presentBalanceKg:   { type: Number, default: 0 },
  remarks:            String,
}, { timestamps: true });

ProductionReportSchema.index({ year: 1, month: 1, zone: 1, productName: 1, packSize: 1 }, { unique: true });

export default mongoose.models.ProductionReport || mongoose.model<IProductionReport>('ProductionReport', ProductionReportSchema);
