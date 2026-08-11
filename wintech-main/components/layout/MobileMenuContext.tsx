'use client';
import { createContext, useContext } from 'react';

export const MobileMenuContext = createContext<() => void>(() => {});
export const useMobileMenu = () => useContext(MobileMenuContext);
