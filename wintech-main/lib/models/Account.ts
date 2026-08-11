import mongoose, { Schema, Document } from 'mongoose';

export interface IAccount extends Document {
  legacyId?: number;
  branchId?: number;
  code: string;
  transactionType?: string;
  name: string;
  type?: string;
  description?: string;
  status: string;
  addBy?: string;
  addTime?: Date;
}

const AccountSchema = new Schema<IAccount>({
  legacyId: { type: Number, index: true },
  branchId: Number,
  code: { type: String, required: true, trim: true },
  transactionType: String,
  name: { type: String, required: true, trim: true },
  type: String,
  description: String,
  status: { type: String, default: 'a' },
  addBy: String,
  addTime: Date,
}, { timestamps: true });

AccountSchema.index({ code: 1 });
AccountSchema.index({ name: 'text' });

export default mongoose.models.Account || mongoose.model<IAccount>('Account', AccountSchema);
