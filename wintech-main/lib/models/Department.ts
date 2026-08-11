import mongoose, { Schema, Document } from 'mongoose';

export interface IDepartment extends Document {
  legacyId?: number;
  name: string;
  head?: string;
  description?: string;
  budget?: number;
  status: string;
  branchId?: number;
  addBy?: string;
}

const DepartmentSchema = new Schema<IDepartment>({
  legacyId: { type: Number, index: true },
  name: { type: String, required: true, trim: true },
  head: String,
  description: String,
  budget: { type: Number, default: 0 },
  status: { type: String, default: 'a' },
  branchId: Number,
  addBy: String,
}, { timestamps: true });

export default mongoose.models.Department || mongoose.model<IDepartment>('Department', DepartmentSchema);
