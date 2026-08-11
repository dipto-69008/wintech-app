import mongoose, { Schema, Document } from 'mongoose';

export interface ISalesDuesReport extends Document {
  month: number;
  year: number;
  zone: string;
  partyName: string;
  invoiceNos?: string;
  previousDue: number;
  totalSales: number;
  commission: number;
  collectionAmount: number;
  mrNo?: string;
  cheque?: string;
  returnGoods: number;
  totalDues: number;
}

const SalesDuesReportSchema = new Schema<ISalesDuesReport>({
  month:       { type: Number, required: true },
  year:        { type: Number, required: true },
  zone:        { type: String, required: true, trim: true },
  partyName:   { type: String, required: true, trim: true },
  invoiceNos:  String,
  previousDue: { type: Number, default: 0 },
  totalSales:  { type: Number, default: 0 },
  commission:  { type: Number, default: 0 },
  collectionAmount: { type: Number, default: 0 },
  mrNo:        String,
  cheque:      String,
  returnGoods: { type: Number, default: 0 },
  totalDues:   { type: Number, default: 0 },
}, { timestamps: true });

SalesDuesReportSchema.index({ year: 1, month: 1, zone: 1, partyName: 1 }, { unique: true });

export default mongoose.models.SalesDuesReport || mongoose.model<ISalesDuesReport>('SalesDuesReport', SalesDuesReportSchema);
