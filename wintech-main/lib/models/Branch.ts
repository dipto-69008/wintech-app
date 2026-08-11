import mongoose, { Schema, Document } from 'mongoose';

export interface IBranch extends Document {
  legacyId?: number;
  name: string;
  nickname?: string;
  zoneCode?: string;
  address?: string;
  phone?: string;
  manager?: string;
  status: string;
  addBy?: string;
}

const BranchSchema = new Schema<IBranch>({
  legacyId: { type: Number, index: true },
  name: { type: String, required: true, trim: true },
  nickname: { type: String, trim: true },
  zoneCode: { type: String, trim: true },
  address: String,
  phone: String,
  manager: String,
  status: { type: String, default: 'a' },
  addBy: String,
}, { timestamps: true });

BranchSchema.index({ name: 1 }, { unique: true });

export default mongoose.models.Branch || mongoose.model<IBranch>('Branch', BranchSchema);
