import mongoose, { Schema, Document } from 'mongoose';

export interface IZoneSalesReport extends Document {
  year: number;
  month: number;
  zone: string;
  target: number;
  previousDues: number;
  totalSales: number;
  returnGoods: number;
  netSales: number;
  commission: number;
  collectionAmount: number;
  badDebt: number;
  totalDues: number;
  targetAchievement: number;
  salesPercent: number;
}

const ZoneSalesReportSchema = new Schema<IZoneSalesReport>({
  year:              { type: Number, required: true },
  month:             { type: Number, required: true },
  zone:              { type: String, required: true, trim: true },
  target:            { type: Number, default: 0 },
  previousDues:      { type: Number, default: 0 },
  totalSales:        { type: Number, default: 0 },
  returnGoods:       { type: Number, default: 0 },
  netSales:          { type: Number, default: 0 },
  commission:        { type: Number, default: 0 },
  collectionAmount:  { type: Number, default: 0 },
  badDebt:           { type: Number, default: 0 },
  totalDues:         { type: Number, default: 0 },
  targetAchievement: { type: Number, default: 0 },
  salesPercent:      { type: Number, default: 0 },
}, { timestamps: true });

ZoneSalesReportSchema.index({ year: 1, month: 1, zone: 1 }, { unique: true });

export default mongoose.models.ZoneSalesReport ||
  mongoose.model<IZoneSalesReport>('ZoneSalesReport', ZoneSalesReportSchema);
