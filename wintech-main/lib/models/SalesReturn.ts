import mongoose, { Schema, Document } from 'mongoose';

export interface ISalesReturn extends Document {
  returnNo: string;
  invoiceNo?: string;
  partyName: string;
  returnDate: Date;
  reason?: string;
  items: { productName: string; quantity: number; rate: number; totalAmount: number }[];
  totalAmount: number;
  status: 'pending' | 'approved' | 'refunded';
  notes?: string;
}

const SalesReturnSchema = new Schema<ISalesReturn>({
  returnNo: { type: String, required: true, unique: true },
  invoiceNo: String,
  partyName: { type: String, required: true },
  returnDate: { type: Date, default: Date.now },
  reason: String,
  items: [{
    productName: { type: String, required: true },
    quantity: { type: Number, required: true, min: 0 },
    rate: { type: Number, required: true, min: 0 },
    totalAmount: { type: Number, required: true, min: 0 },
  }],
  totalAmount: { type: Number, default: 0 },
  status: { type: String, enum: ['pending', 'approved', 'refunded'], default: 'pending' },
  notes: String,
}, { timestamps: true });

export default mongoose.models.SalesReturn || mongoose.model<ISalesReturn>('SalesReturn', SalesReturnSchema);
