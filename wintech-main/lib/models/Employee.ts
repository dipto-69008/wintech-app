import mongoose, { Schema, Document } from 'mongoose';

export interface IEmployee extends Document {
  legacyId?: number;
  designationId?: number;
  departmentId?: number;
  employeeCode: string;
  name: string;
  joinDate?: Date;
  gender?: string;
  birthDate?: Date;
  nid?: string;
  contactNo?: string;
  email?: string;
  maritalStatus?: string;
  fatherName?: string;
  motherName?: string;
  presentAddress?: string;
  permanentAddress?: string;
  salary?: number;
  bankAccountNo?: string;
  bankName?: string;
  status: string;
  branchId?: number;
  designation?: string;
  department?: string;
  areaName?: string;
  password?: string;
  role?: string;
  addBy?: string;
  addTime?: Date;
}

const EmployeeSchema = new Schema<IEmployee>({
  legacyId: { type: Number, index: true },
  designationId: Number,
  departmentId: Number,
  employeeCode: { type: String, required: true, trim: true },
  name: { type: String, required: true, trim: true },
  joinDate: Date,
  gender: String,
  birthDate: Date,
  nid: String,
  contactNo: String,
  email: String,
  maritalStatus: String,
  fatherName: String,
  motherName: String,
  presentAddress: String,
  permanentAddress: String,
  salary: { type: Number, default: 0 },
  bankAccountNo: String,
  bankName: String,
  status: { type: String, default: 'a' },
  branchId: Number,
  designation: String,
  department: String,
  areaName: String,
  password: String,
  role: { type: String, default: 'employee' },
  addBy: String,
  addTime: Date,
}, { timestamps: true });

EmployeeSchema.index({ employeeCode: 1 });
EmployeeSchema.index({ name: 'text' });

export default mongoose.models.Employee || mongoose.model<IEmployee>('Employee', EmployeeSchema);
