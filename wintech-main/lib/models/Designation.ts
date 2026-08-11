import mongoose, { Schema, Document } from 'mongoose';

export interface IDesignation extends Document {
  legacyId?: number;
  name: string;
  department?: string;
  level?: string;
  description?: string;
  status: string;
  branchId?: number;
  addBy?: string;
}

const DesignationSchema = new Schema<IDesignation>({
  legacyId: { type: Number, index: true },
  name: { type: String, required: true, trim: true },
  department: String,
  level: String,
  description: String,
  status: { type: String, default: 'a' },
  branchId: Number,
  addBy: String,
}, { timestamps: true });

export default mongoose.models.Designation || mongoose.model<IDesignation>('Designation', DesignationSchema);
