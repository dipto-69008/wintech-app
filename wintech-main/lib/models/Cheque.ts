import mongoose, { Schema, Document } from 'mongoose';

export interface ICheque extends Document {
  chequeNo: string;
  bankName: string;
  bankBranch?: string;
  accountNo?: string;
  amount: number;
  chequeDate: Date;
  issueDate: Date;
  partyName: string;
  partyType: 'party' | 'supplier' | 'other';
  chequeType: 'receive' | 'issue';
  status: 'pending' | 'approved' | 'dishonoured' | 'reminder';
  reminderDate?: Date;
  description?: string;
  approvedBy?: string;
  approvedAt?: Date;
  addBy?: string;
  addTime?: Date;
}

const ChequeSchema = new Schema<ICheque>({
  chequeNo: { type: String, required: true, trim: true },
  bankName: { type: String, required: true },
  bankBranch: String,
  accountNo: String,
  amount: { type: Number, required: true, default: 0 },
  chequeDate: { type: Date, required: true },
  issueDate: { type: Date, required: true },
  partyName: { type: String, required: true },
  partyType: { type: String, enum: ['party', 'supplier', 'other'], default: 'party' },
  chequeType: { type: String, enum: ['receive', 'issue'], default: 'receive' },
  status: { type: String, enum: ['pending', 'approved', 'dishonoured', 'reminder'], default: 'pending' },
  reminderDate: Date,
  description: String,
  approvedBy: String,
  approvedAt: Date,
  addBy: String,
  addTime: Date,
}, { timestamps: true });

ChequeSchema.index({ chequeNo: 1 });
ChequeSchema.index({ chequeDate: -1 });
ChequeSchema.index({ status: 1 });

export default mongoose.models.Cheque || mongoose.model<ICheque>('Cheque', ChequeSchema);
