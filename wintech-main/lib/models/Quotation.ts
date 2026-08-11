import mongoose, { Schema, Document } from 'mongoose';

export interface IQuotation extends Document {
  quotationNo: string;
  partyName: string;
  partyEmail?: string;
  quotationDate: Date;
  validUntil?: Date;
  items: { productName: string; quantity: number; rate: number; totalAmount: number }[];
  totalAmount: number;
  discountAmount: number;
  taxAmount: number;
  subTotal: number;
  notes?: string;
  status: 'draft' | 'sent' | 'accepted' | 'rejected';
}

const QuotationSchema = new Schema<IQuotation>({
  quotationNo: { type: String, required: true, unique: true },
  partyName: { type: String, required: true },
  partyEmail: String,
  quotationDate: { type: Date, default: Date.now },
  validUntil: Date,
  items: [{
    productName: { type: String, required: true },
    quantity: { type: Number, required: true, min: 0 },
    rate: { type: Number, required: true, min: 0 },
    totalAmount: { type: Number, required: true, min: 0 },
  }],
  totalAmount: { type: Number, default: 0 },
  discountAmount: { type: Number, default: 0 },
  taxAmount: { type: Number, default: 0 },
  subTotal: { type: Number, default: 0 },
  notes: String,
  status: { type: String, enum: ['draft', 'sent', 'accepted', 'rejected'], default: 'draft' },
}, { timestamps: true });

export default mongoose.models.Quotation || mongoose.model<IQuotation>('Quotation', QuotationSchema);
