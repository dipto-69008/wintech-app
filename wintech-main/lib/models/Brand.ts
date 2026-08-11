import mongoose, { Schema, Document } from 'mongoose';

export interface IBrand extends Document {
  legacyId?: number;
  name: string;
  status: string;
  branchId?: number;
  addBy?: string;
}

const BrandSchema = new Schema<IBrand>({
  legacyId: { type: Number, index: true },
  name: { type: String, required: true, trim: true },
  status: { type: String, default: 'a' },
  branchId: Number,
  addBy: String,
}, { timestamps: true });

export default mongoose.models.Brand || mongoose.model<IBrand>('Brand', BrandSchema);
