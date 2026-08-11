import mongoose, { Schema, Document } from 'mongoose';

export interface ICategory extends Document {
  legacyId?: number;
  groupId?: number;
  name: string;
  description?: string;
  status: string;
  branchId?: number;
  addBy?: string;
}

const CategorySchema = new Schema<ICategory>({
  legacyId: { type: Number, index: true },
  groupId: Number,
  name: { type: String, required: true, trim: true },
  description: String,
  status: { type: String, default: 'a' },
  branchId: Number,
  addBy: String,
}, { timestamps: true });

CategorySchema.index({ name: 1 });

export default mongoose.models.Category || mongoose.model<ICategory>('Category', CategorySchema);
